const express = require('express');
const { body, query, validationResult } = require('express-validator');
const prisma = require('../config/prisma');
const { protect, authorize } = require('../middleware/auth');
const { fraudCaseService } = require('../services/fraud');

const router = express.Router();
const hasFraudSignalDelegate = () => Boolean(prisma?.fraudSignal && typeof prisma.fraudSignal.create === 'function');

router.use(protect, authorize('admin'));

const validationErrorResponse = (req, res) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) return null;
  return res.status(400).json({ success: false, message: 'Validation failed', errors: errors.array() });
};

router.get(
  '/cases',
  [
    query('status').optional().isString(),
    query('severity').optional().isString(),
    query('actorType').optional().isString(),
    query('from').optional().isISO8601(),
    query('to').optional().isISO8601(),
    query('limit').optional().isInt({ min: 1, max: 200 }),
    query('offset').optional().isInt({ min: 0 }),
  ],
  async (req, res) => {
    const error = validationErrorResponse(req, res);
    if (error) return error;

    const cases = await fraudCaseService.listCases({
      status: req.query.status,
      severity: req.query.severity,
      actorType: req.query.actorType,
      from: req.query.from,
      to: req.query.to,
      take: Number(req.query.limit || 50),
      skip: Number(req.query.offset || 0),
    });

    return res.json({ success: true, data: cases });
  }
);

router.get('/cases/:id', async (req, res) => {
  const item = await fraudCaseService.getCaseById(req.params.id);
  if (!item) {
    return res.status(404).json({ success: false, message: 'Fraud case not found' });
  }
  return res.json({ success: true, data: item });
});

router.post(
  '/cases/:id/assign',
  [body('assignee').notEmpty().withMessage('assignee is required')],
  async (req, res) => {
    const error = validationErrorResponse(req, res);
    if (error) return error;

    const item = await fraudCaseService.assignCase({
      id: req.params.id,
      assignee: req.body.assignee,
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'Fraud case not found' });
    }

    return res.json({ success: true, data: item, message: 'Fraud case assigned' });
  }
);

router.post(
  '/cases/:id/resolve',
  [
    body('resolutionStatus')
      .isIn(['resolved_true_positive', 'resolved_false_positive', 'resolved_benign'])
      .withMessage('resolutionStatus is invalid'),
    body('resolutionNote').optional().isString(),
  ],
  async (req, res) => {
    const error = validationErrorResponse(req, res);
    if (error) return error;

    const item = await fraudCaseService.resolveCase({
      id: req.params.id,
      resolutionStatus: req.body.resolutionStatus,
      resolutionNote: req.body.resolutionNote,
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'Fraud case not found' });
    }

    return res.json({ success: true, data: item, message: 'Fraud case resolved' });
  }
);

router.post(
  '/allowlist',
  [
    body('actorType').notEmpty().withMessage('actorType is required'),
    body('actorId').notEmpty().withMessage('actorId is required'),
    body('expiresAt').optional().isISO8601(),
    body('reason').optional().isString(),
  ],
  async (req, res) => {
    const error = validationErrorResponse(req, res);
    if (error) return error;
    if (!hasFraudSignalDelegate()) {
      return res.status(503).json({ success: false, message: 'Fraud signal storage is unavailable' });
    }

    const signal = await prisma.fraudSignal.create({
      data: {
        actorType: req.body.actorType,
        actorId: req.body.actorId,
        signalType: 'allowlist',
        signalValue: {
          reason: req.body.reason || null,
          setBy: req.user.id,
        },
        weight: -100,
        observedAt: new Date(),
        expiresAt: req.body.expiresAt ? new Date(req.body.expiresAt) : null,
      },
    }).catch(() => null);

    if (!signal) {
      return res.status(500).json({ success: false, message: 'Failed to create allowlist signal' });
    }

    return res.status(201).json({ success: true, data: signal, message: 'Allowlist signal created' });
  }
);

router.post(
  '/denylist',
  [
    body('actorType').notEmpty().withMessage('actorType is required'),
    body('actorId').notEmpty().withMessage('actorId is required'),
    body('expiresAt').optional().isISO8601(),
    body('reason').optional().isString(),
  ],
  async (req, res) => {
    const error = validationErrorResponse(req, res);
    if (error) return error;
    if (!hasFraudSignalDelegate()) {
      return res.status(503).json({ success: false, message: 'Fraud signal storage is unavailable' });
    }

    const signal = await prisma.fraudSignal.create({
      data: {
        actorType: req.body.actorType,
        actorId: req.body.actorId,
        signalType: 'denylist',
        signalValue: {
          reason: req.body.reason || null,
          setBy: req.user.id,
        },
        weight: 100,
        observedAt: new Date(),
        expiresAt: req.body.expiresAt ? new Date(req.body.expiresAt) : null,
      },
    }).catch(() => null);

    if (!signal) {
      return res.status(500).json({ success: false, message: 'Failed to create denylist signal' });
    }

    return res.status(201).json({ success: true, data: signal, message: 'Denylist signal created' });
  }
);

module.exports = router;
