const express = require('express');
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const featureFlags = require('../config/feature_flags');
const paystackService = require('../services/paystack_service');
const {
  ACTION_TYPES,
  DECISIONS,
  buildFraudContextFromRequest,
  fraudDecisionService,
  applyFraudDecision,
} = require('../services/fraud');

const router = express.Router();
const hasPaymentWebhookDelegate = () =>
  Boolean(prisma?.paymentWebhookEvent && typeof prisma.paymentWebhookEvent.create === 'function');

const ALLOWED_PAYMENT_TRANSITIONS = {
  pending: new Set(['processing', 'paid', 'successful', 'failed', 'cancelled', 'expired']),
  processing: new Set(['paid', 'successful', 'failed', 'cancelled', 'expired']),
  paid: new Set(['successful', 'refunded']),
  successful: new Set(['refunded']),
  failed: new Set(),
  cancelled: new Set(),
  expired: new Set(),
  refunded: new Set(),
};

const isValidPaymentTransition = (currentStatus, nextStatus) => {
  if (!currentStatus || currentStatus === nextStatus) return true;
  const allowed = ALLOWED_PAYMENT_TRANSITIONS[currentStatus];
  return Boolean(allowed && allowed.has(nextStatus));
};

const parseWebhookPayload = (req) => {
  if (Buffer.isBuffer(req.body)) {
    const raw = req.body.toString('utf8');
    return { rawBody: req.body, payload: JSON.parse(raw) };
  }
  const payload = req.body || {};
  const rawBody = Buffer.from(JSON.stringify(payload));
  return { rawBody, payload };
};

router.post('/webhooks/paystack', async (req, res) => {
  const signature = req.headers['x-paystack-signature'] || req.headers['X-Paystack-Signature'];

  let rawBody;
  let payload;
  try {
    ({ rawBody, payload } = parseWebhookPayload(req));
  } catch (error) {
    return res.status(400).json({ success: false, message: 'Invalid JSON payload' });
  }

  const providerEventId = paystackService.extractWebhookEventId(payload);
  const reference = paystackService.extractWebhookReference(payload);
  const eventType = payload?.event || 'unknown';
  const canPersistWebhookEvent = hasPaymentWebhookDelegate();

  const signatureValid = paystackService.verifyWebhookSignature(rawBody, signature);

  const fraudContext = buildFraudContextFromRequest({
    req,
    actionType: ACTION_TYPES.PAYMENT_WEBHOOK_EVENT,
    actorType: 'system',
    actorId: 'paystack',
    extras: {
      providerEventId,
      paymentRef: reference,
      signature: signature ? String(signature) : null,
      amount: Number(payload?.data?.amount || 0) / 100 || null,
      currency: payload?.data?.currency || 'GHS',
      metadata: {
        webhookSignatureValid: signatureValid,
        eventType,
      },
    },
  });

  const fraudDecision = await fraudDecisionService.evaluate({
    actionType: ACTION_TYPES.PAYMENT_WEBHOOK_EVENT,
    actorType: 'system',
    actorId: 'paystack',
    context: fraudContext,
  }).catch(() => null);

  if (fraudDecision?.decision === DECISIONS.BLOCK) {
    const enforced = applyFraudDecision({
      req,
      res,
      decision: fraudDecision,
      actionType: ACTION_TYPES.PAYMENT_WEBHOOK_EVENT,
    });
    if (enforced.blocked) return;
  } else if (fraudDecision?.decision === DECISIONS.STEP_UP) {
    // Webhook actors cannot complete customer challenges, so treat step-up as monitor-only.
    console.warn('[Fraud] STEP_UP decision ignored for payment webhook event');
  }

  if (!signatureValid) {
    if (canPersistWebhookEvent) {
      await prisma.paymentWebhookEvent.create({
        data: {
          provider: 'paystack',
          providerEventId,
          reference,
          signature: signature ? String(signature) : null,
          payload,
          status: 'signature_invalid',
          errorMessage: 'Invalid webhook signature',
        },
      }).catch(() => null);
    }

    return res.status(401).json({
      success: false,
      message: 'Invalid webhook signature',
      reasonCode: 'PAYMENT_WEBHOOK_SIGNATURE_INVALID',
    });
  }

  const webhookRow = canPersistWebhookEvent
    ? await prisma.paymentWebhookEvent.create({
        data: {
          provider: 'paystack',
          providerEventId,
          reference,
          signature: String(signature || ''),
          payload,
          status: 'received',
        },
      }).catch((error) => {
        const isDuplicate =
          error?.code === 'P2002' ||
          String(error?.message || '').includes('Unique constraint');
        if (isDuplicate) return 'duplicate';
        return null;
      })
    : null;

  if (webhookRow === 'duplicate') {
    return res.status(200).json({
      success: true,
      message: 'Webhook already processed',
      data: { duplicate: true },
    });
  }

  const orders = reference
    ? await prisma.order.findMany({
        where: { paymentReferenceId: reference },
        select: {
          id: true,
          orderNumber: true,
          customerId: true,
          checkoutSessionId: true,
          paymentMethod: true,
          paymentStatus: true,
          paymentProvider: true,
          totalAmount: true,
          status: true,
          fulfillmentMode: true,
          riderId: true,
          isScheduledOrder: true,
          scheduledReleasedAt: true,
        },
      })
    : [];

  if (!orders.length) {
    if (webhookRow?.id) {
      await prisma.paymentWebhookEvent.update({
        where: { id: webhookRow.id },
        data: {
          status: 'ignored',
          processedAt: new Date(),
          errorMessage: 'Order not found for reference',
        },
      }).catch(() => null);
    }

    return res.status(200).json({
      success: true,
      message: 'Webhook acknowledged',
      data: { processed: false, reason: 'order_not_found' },
    });
  }

  const incomingStatus =
    eventType === 'charge.success'
      ? 'paid'
      : eventType === 'charge.failed'
      ? 'failed'
      : null;

  if (!incomingStatus) {
    if (webhookRow?.id) {
      await prisma.paymentWebhookEvent.update({
        where: { id: webhookRow.id },
        data: {
          status: 'ignored',
          processedAt: new Date(),
          errorMessage: `Unsupported event type: ${eventType}`,
        },
      }).catch(() => null);
    }

    return res.status(200).json({
      success: true,
      message: 'Webhook acknowledged',
      data: { processed: false, reason: 'unsupported_event' },
    });
  }

  const amountMajor = Number(payload?.data?.amount || 0) / 100;
  const providerStatus = payload?.data?.status || null;
  const metadata = payload?.data?.metadata || {};
  const hasMultipleOrders = orders.length > 1;

  for (const order of orders) {
    if (!isValidPaymentTransition(order.paymentStatus, incomingStatus)) {
      if (webhookRow?.id) {
        await prisma.paymentWebhookEvent.update({
          where: { id: webhookRow.id },
          data: {
            status: 'rejected',
            processedAt: new Date(),
            errorMessage: `Invalid payment transition on order ${order.id}: ${order.paymentStatus} -> ${incomingStatus}`,
          },
        }).catch(() => null);
      }

      return res.status(200).json({
        success: true,
        message: 'Webhook acknowledged',
        data: { processed: false, reason: 'invalid_state_transition', orderId: order.id },
      });
    }
  }

  await prisma.$transaction(async (tx) => {
    const touchedSessionIds = new Set();

    for (const order of orders) {
      if (order.checkoutSessionId) {
        touchedSessionIds.add(order.checkoutSessionId);
      }

      const existingPayment = await tx.payment.findFirst({
        where: {
          OR: [
            { referenceId: reference },
            { externalReferenceId: reference, orderId: order.id },
          ],
        },
      });

      if (existingPayment) {
        await tx.payment.update({
          where: { id: existingPayment.id },
          data: {
            status: incomingStatus,
            provider: 'paystack',
            amount: Number.isFinite(amountMajor) && amountMajor > 0
              ? (hasMultipleOrders ? Number(order.totalAmount || 0) : amountMajor)
              : existingPayment.amount,
            externalReferenceId: reference,
            metadata: {
              ...(existingPayment.metadata || {}),
              webhookEventId: providerEventId,
              webhookEventType: eventType,
              providerStatus,
              metadata,
            },
            ...(incomingStatus === 'paid' ? { completedAt: new Date() } : {}),
          },
        });
      } else {
        await tx.payment.create({
          data: {
            orderId: order.id,
            customerId: order.customerId,
            paymentMethod: order.paymentMethod,
            provider: 'paystack',
            amount: Number.isFinite(amountMajor) && amountMajor > 0
              ? (hasMultipleOrders ? Number(order.totalAmount || 0) : amountMajor)
              : Number(order.totalAmount || 0),
            status: incomingStatus,
            referenceId: hasMultipleOrders ? `${reference}-${order.id}` : reference,
            externalReferenceId: hasMultipleOrders ? reference : null,
            metadata: {
              webhookEventId: providerEventId,
              webhookEventType: eventType,
              providerStatus,
              metadata,
            },
            ...(incomingStatus === 'paid' ? { completedAt: new Date() } : {}),
          },
        });
      }

      const shouldConfirmOrder =
        incomingStatus === 'paid' &&
        order.status === 'pending' &&
        order.fulfillmentMode === 'delivery' &&
        (!order.isScheduledOrder || Boolean(order.scheduledReleasedAt));

      await tx.order.update({
        where: { id: order.id },
        data: {
          paymentStatus: incomingStatus,
          paymentProvider: 'paystack',
          ...(shouldConfirmOrder ? { status: 'confirmed' } : {}),
        },
      });
    }

    for (const sessionId of touchedSessionIds) {
      const sessionOrders = await tx.order.findMany({
        where: { checkoutSessionId: sessionId },
        select: { paymentStatus: true },
      });

      const allPaid = sessionOrders.length > 0 &&
        sessionOrders.every((item) => ['paid', 'successful'].includes(item.paymentStatus));
      const anyFailed = sessionOrders.some((item) =>
        ['failed', 'cancelled', 'expired'].includes(item.paymentStatus)
      );

      const nextSessionPaymentStatus = allPaid ? 'paid' : anyFailed ? 'failed' : 'processing';
      const nextSessionStatus = allPaid ? 'paid' : anyFailed ? 'failed' : 'processing';

      await tx.checkoutSession.update({
        where: { id: sessionId },
        data: {
          paymentStatus: nextSessionPaymentStatus,
          status: nextSessionStatus,
          paymentProvider: 'paystack',
          paymentReferenceId: reference || null,
          ...(allPaid ? { paidAt: new Date() } : {}),
          ...(anyFailed ? { paidAt: null } : {}),
        },
      });
    }

    if (webhookRow?.id) {
      await tx.paymentWebhookEvent.update({
        where: { id: webhookRow.id },
        data: {
          status: 'processed',
          processedAt: new Date(),
          errorMessage: null,
        },
      });
    }
  });

  return res.status(200).json({
    success: true,
    message: 'Webhook processed',
    data: {
      reference,
      eventType,
      paymentStatus: incomingStatus,
      orderCount: orders.length,
      sourceOfTruth: featureFlags.isPaymentWebhookSourceOfTruthEnabled,
    },
  });
});

/**
 * Get all payments for a user
 */
router.get('/my-payments', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const payments = await prisma.payment.findMany({
      where: { customerId: req.user.id },
      include: {
        order: { select: { orderNumber: true, totalAmount: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    });

    const total = await prisma.payment.count({
      where: { customerId: req.user.id },
    });

    res.json({
      success: true,
      message: 'Payments retrieved successfully',
      data: payments,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: limit,
      },
    });
  } catch (error) {
    console.error('Get payments error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

/**
 * Cancel a pending payment
 */
router.put('/:paymentId/cancel', protect, async (req, res) => {
  try {
    const { paymentId } = req.params;

    const payment = await prisma.payment.findUnique({
      where: { id: paymentId },
    });

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Payment not found',
      });
    }

    if (payment.customerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to cancel this payment',
      });
    }

    if (!['pending', 'processing'].includes(payment.status)) {
      return res.status(400).json({
        success: false,
        message: 'Payment cannot be cancelled in its current status',
      });
    }

    const updatedPayment = await prisma.payment.update({
      where: { id: paymentId },
      data: { status: 'cancelled' },
    });

    res.json({
      success: true,
      message: 'Payment cancelled successfully',
      data: {
        paymentId: updatedPayment.id,
        status: updatedPayment.status,
      },
    });
  } catch (error) {
    console.error('Cancel payment error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

module.exports = router;
