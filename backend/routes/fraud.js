const express = require('express');
const { body, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const {
  fraudChallengeSendRateLimit,
  fraudChallengeVerifyRateLimit,
  paymentAttemptRateLimit,
} = require('../middleware/fraud_rate_limit');
const prisma = require('../config/prisma');
const { requestPhoneOtp, verifyPhoneOtp, normalizeGhanaPhone } = require('../services/otp_service');
const paystackService = require('../services/paystack_service');
const {
  ACTION_TYPES,
  CHALLENGE_TYPES,
  fraudPolicyService,
  fraudChallengeService,
} = require('../services/fraud');
const { createScopedLogger } = require('../utils/logger');

const router = express.Router();
const console = createScopedLogger('fraud_route');
const hasFraudChallengeDelegate = () =>
  Boolean(prisma?.fraudChallenge && typeof prisma.fraudChallenge.updateMany === 'function');

const parseValidation = (req, res) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) return null;
  return res.status(400).json({
    success: false,
    message: 'Validation failed',
    errors: errors.array(),
  });
};

router.post(
  '/challenge/otp/send',
  protect,
  fraudChallengeSendRateLimit,
  [
    body('actionType').optional().isString().withMessage('actionType must be a string'),
    body('phoneNumber').optional().isString().withMessage('phoneNumber must be a string'),
    body('channel').optional().isIn(['sms', 'whatsapp']).withMessage('channel must be sms or whatsapp'),
  ],
  async (req, res) => {
    const validationResponse = parseValidation(req, res);
    if (validationResponse) return validationResponse;

    const policy = await fraudPolicyService.getActivePolicy();
    const actionType = req.body.actionType || ACTION_TYPES.AUTH_LOGIN;
    const caps = policy.challenge_caps || { perActionPer24h: 1, totalPer24h: 3 };

    const allowed = await fraudChallengeService.checkChallengeCaps({
      actorType: req.user.role || 'customer',
      actorId: req.user.id,
      actionType,
      perActionPer24h: Number(caps.perActionPer24h || 1),
      totalPer24h: Number(caps.totalPer24h || 3),
    });

    if (!allowed.allowed) {
      return res.status(429).json({
        success: false,
        message: 'Challenge cap reached for this account',
        riskCode: 'SYSTEM_CHALLENGE_CAP_REACHED',
        reasonCodes: ['SYSTEM_CHALLENGE_CAP_REACHED'],
        data: {
          currentPerAction: allowed.currentPerAction,
          currentTotal: allowed.currentTotal,
        },
      });
    }

    const rawPhone = req.body.phoneNumber || req.user.phone;
    const normalized = normalizeGhanaPhone(rawPhone);
    if (!normalized) {
      return res.status(400).json({
        success: false,
        message: 'A valid Ghana phone number is required for OTP challenge',
      });
    }

    const otpResult = await requestPhoneOtp({
      phoneNumber: normalized.e164,
      userId: req.user.id,
      channel: req.body.channel || 'sms',
    });

    if (!otpResult.success) {
      return res.status(400).json({
        success: false,
        message: otpResult.message || 'Failed to send OTP challenge',
        error: otpResult.error || null,
      });
    }

    const expiresAt = new Date(Date.now() + Number(process.env.OTP_TTL_SECONDS || 600) * 1000);
    const challenge = await fraudChallengeService.createChallenge({
      actorType: req.user.role || 'customer',
      actorId: req.user.id,
      challengeType: CHALLENGE_TYPES.OTP,
      actionType,
      expiresAt,
      metadata: {
        phoneNumber: normalized.e164,
        channel: otpResult.channel,
      },
    });

    await fraudChallengeService.incrementChallengeCaps({
      actorType: req.user.role || 'customer',
      actorId: req.user.id,
      actionType,
    });

    return res.json({
      success: true,
      message: otpResult.message || 'OTP challenge sent',
      data: {
        challengeId: challenge?.id || null,
        challengeType: CHALLENGE_TYPES.OTP,
        actionType,
        expiresAt,
      },
    });
  }
);

router.post(
  '/challenge/otp/verify',
  protect,
  fraudChallengeVerifyRateLimit,
  [
    body('otp').notEmpty().withMessage('otp is required'),
    body('phoneNumber').optional().isString().withMessage('phoneNumber must be a string'),
    body('challengeId').optional().isString().withMessage('challengeId must be a string'),
  ],
  async (req, res) => {
    const validationResponse = parseValidation(req, res);
    if (validationResponse) return validationResponse;

    const phoneNumber = req.body.phoneNumber || req.user.phone;
    if (!phoneNumber) {
      return res.status(400).json({ success: false, message: 'phoneNumber is required' });
    }

    const result = await verifyPhoneOtp({
      phoneNumber,
      userId: req.user.id,
      otp: req.body.otp,
    });

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message || 'OTP challenge verification failed',
      });
    }

    const challenge = req.body.challengeId
      ? { id: req.body.challengeId }
      : await fraudChallengeService.getLatestPendingChallenge({
          actorType: req.user.role || 'customer',
          actorId: req.user.id,
          challengeType: CHALLENGE_TYPES.OTP,
        });

    if (challenge?.id && hasFraudChallengeDelegate()) {
      const updateResult = await prisma.fraudChallenge.updateMany({
        where: {
          id: challenge.id,
          actorType: req.user.role || 'customer',
          actorId: req.user.id,
          challengeType: CHALLENGE_TYPES.OTP,
        },
        data: {
          status: 'verified',
          verifiedAt: new Date(),
        },
      }).catch(() => null);

      if (req.body.challengeId && updateResult && Number(updateResult.count || 0) === 0) {
        return res.status(404).json({
          success: false,
          message: 'Challenge not found for this account',
        });
      }
    }

    return res.json({
      success: true,
      message: 'OTP challenge verified',
      data: {
        challengeId: challenge?.id || null,
        verified: true,
      },
    });
  }
);

router.post(
  '/challenge/payment-reauth/init',
  protect,
  paymentAttemptRateLimit,
  [
    body('reference').notEmpty().withMessage('reference is required'),
    body('actionType').optional().isString().withMessage('actionType must be a string'),
  ],
  async (req, res) => {
    const validationResponse = parseValidation(req, res);
    if (validationResponse) return validationResponse;

    const policy = await fraudPolicyService.getActivePolicy();
    const actionType = req.body.actionType || ACTION_TYPES.PAYMENT_CLIENT_CONFIRM;
    const caps = policy.challenge_caps || { perActionPer24h: 1, totalPer24h: 3 };

    const allowed = await fraudChallengeService.checkChallengeCaps({
      actorType: req.user.role || 'customer',
      actorId: req.user.id,
      actionType,
      perActionPer24h: Number(caps.perActionPer24h || 1),
      totalPer24h: Number(caps.totalPer24h || 3),
    });

    if (!allowed.allowed) {
      return res.status(429).json({
        success: false,
        message: 'Challenge cap reached for this account',
        riskCode: 'SYSTEM_CHALLENGE_CAP_REACHED',
        reasonCodes: ['SYSTEM_CHALLENGE_CAP_REACHED'],
        data: {
          currentPerAction: allowed.currentPerAction,
          currentTotal: allowed.currentTotal,
        },
      });
    }

    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
    const challenge = await fraudChallengeService.createChallenge({
      actorType: req.user.role || 'customer',
      actorId: req.user.id,
      challengeType: CHALLENGE_TYPES.PAYMENT_REAUTH,
      actionType,
      expiresAt,
      metadata: {
        reference: req.body.reference,
      },
    });

    await fraudChallengeService.incrementChallengeCaps({
      actorType: req.user.role || 'customer',
      actorId: req.user.id,
      actionType,
    });

    return res.json({
      success: true,
      message: 'Payment re-auth challenge initialized',
      data: {
        challengeId: challenge?.id || null,
        challengeType: CHALLENGE_TYPES.PAYMENT_REAUTH,
        expiresAt,
      },
    });
  }
);

router.post(
  '/challenge/payment-reauth/confirm',
  protect,
  paymentAttemptRateLimit,
  [
    body('reference').notEmpty().withMessage('reference is required'),
    body('challengeId').optional().isString().withMessage('challengeId must be a string'),
  ],
  async (req, res) => {
    const validationResponse = parseValidation(req, res);
    if (validationResponse) return validationResponse;

    try {
      const verification = await paystackService.verifyTransaction(req.body.reference);
      if (verification?.status !== 'success') {
        return res.status(400).json({
          success: false,
          message: 'Payment re-auth verification failed',
          data: { status: verification?.status || null },
        });
      }

      let challengeId = req.body.challengeId;
      if (!challengeId) {
        const latest = await fraudChallengeService.getLatestPendingChallenge({
          actorType: req.user.role || 'customer',
          actorId: req.user.id,
          challengeType: CHALLENGE_TYPES.PAYMENT_REAUTH,
          actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
        });
        challengeId = latest?.id || null;
      }

      if (challengeId && hasFraudChallengeDelegate()) {
        const updateResult = await prisma.fraudChallenge.updateMany({
          where: {
            id: challengeId,
            actorType: req.user.role || 'customer',
            actorId: req.user.id,
            challengeType: CHALLENGE_TYPES.PAYMENT_REAUTH,
          },
          data: {
            status: 'verified',
            verifiedAt: new Date(),
            metadata: {
              reference: req.body.reference,
              providerStatus: verification.status,
            },
          },
        }).catch(() => null);

        if (req.body.challengeId && updateResult && Number(updateResult.count || 0) === 0) {
          return res.status(404).json({
            success: false,
            message: 'Challenge not found for this account',
          });
        }
      }

      return res.json({
        success: true,
        message: 'Payment re-auth challenge verified',
        data: {
          challengeId,
          reference: req.body.reference,
          status: verification.status,
        },
      });
    } catch (error) {
      console.error('Payment re-auth verification error:', error);
      return res.status(400).json({
        success: false,
        message: 'Payment re-auth verification failed',
      });
    }
  }
);

module.exports = router;
