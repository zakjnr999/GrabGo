const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const parcelConfig = require('../config/parcel_config');
const paystackService = require('./paystack_service');
const {
  ParcelValidationError,
  normalizeParcelInput,
  buildScheduleWindow,
  buildLiabilitySnapshot,
} = require('./parcel_validation_service');
const {
  calculateParcelQuote,
  calculateReturnFinancials,
} = require('./parcel_pricing_service');
const {
  generateDeliveryCode,
  hashDeliveryCode,
  encryptDeliveryCode,
  getResendAvailability,
  sendDeliveryCodeSms,
  DeliveryVerificationError,
} = require('./delivery_verification_service');
const { calculateDistance } = require('../utils/distance');

const PAYMENT_PENDING_STATUSES = new Set(['pending', 'processing']);
const CANCELLABLE_STATUSES = new Set([
  'pending_payment',
  'payment_processing',
  'paid',
  'awaiting_dispatch',
]);

const randomDigits = (length = 4) => {
  let output = '';
  while (output.length < length) {
    output += Math.floor(Math.random() * 10).toString();
  }
  return output.slice(0, length);
};

const generateParcelNumber = () => {
  const now = new Date();
  const date = `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, '0')}${String(now.getUTCDate()).padStart(2, '0')}`;
  return `PRC-${date}-${randomDigits(6)}`;
};

const isParcelNumberConflict = (error) => {
  const target = error?.meta?.target;
  const targetString = Array.isArray(target) ? target.join(',') : String(target || '');
  return error?.code === 'P2002' && targetString.includes('parcelNumber');
};

const buildQuotePayload = (normalizedInput) => calculateParcelQuote({
  pickup: normalizedInput.pickup,
  dropoff: normalizedInput.dropoff,
  sizeTier: normalizedInput.sizeTier,
  weightKg: normalizedInput.weightKg,
});

const ensureParcelFeatureEnabled = () => {
  if (!featureFlags.isParcelEnabled) {
    throw new ParcelValidationError('Parcel service is currently unavailable', 403, 'PARCEL_DISABLED');
  }
};

const createParcelEvent = async ({
  parcelOrderId,
  actorId = null,
  actorRole = 'system',
  eventType,
  reason = null,
  metadata = null,
}) => {
  if (!parcelOrderId || !eventType) return null;
  return prisma.parcelEvent.create({
    data: {
      parcelOrderId,
      actorId,
      actorRole,
      eventType,
      reason,
      metadata: metadata || undefined,
    },
  });
};

const getParcelWhereForUser = (user, parcelId) => {
  if (!user?.id) {
    throw new ParcelValidationError('User context is required', 401, 'UNAUTHORIZED');
  }

  if (user.role === 'admin') {
    return { id: parcelId };
  }
  if (user.role === 'rider') {
    return { id: parcelId, riderId: user.id };
  }
  return { id: parcelId, customerId: user.id };
};

const ensureValidPaymentMethod = (method) => {
  const normalized = String(method || '').toLowerCase();
  if (normalized !== 'card' && normalized !== 'online') {
    throw new ParcelValidationError(
      'Parcel supports prepaid card/online payment only',
      400,
      'PARCEL_PREPAID_ONLY'
    );
  }
  return normalized === 'online' ? 'online' : 'card';
};

const ensureSupportedPaymentProvider = (provider) => {
  const normalized = String(provider || 'paystack').trim().toLowerCase();
  if (normalized !== 'paystack') {
    throw new ParcelValidationError(
      'Unsupported payment provider for parcel flow',
      400,
      'UNSUPPORTED_PAYMENT_PROVIDER'
    );
  }
  return 'paystack';
};

const getParcelConfig = () => ({
  enabled: featureFlags.isParcelEnabled,
  scheduledEnabled: featureFlags.isParcelScheduledEnabled,
  returnToSenderEnabled: featureFlags.isParcelReturnToSenderEnabled,
  insuranceEnabled: false,
  noInsuranceEnabled: parcelConfig.noInsuranceEnabled,
  maxDeclaredValueGhs: parcelConfig.maxDeclaredValueGhs,
  liabilityCapGhs: parcelConfig.liabilityCapGhs,
  liabilityFormula: parcelConfig.liabilityFormula,
  termsVersion: parcelConfig.termsVersion,
  scheduleToleranceMinutes: parcelConfig.scheduleToleranceMinutes,
});

const createQuote = (payload) => {
  ensureParcelFeatureEnabled();

  const normalized = normalizeParcelInput(payload, {
    requireTermsAcceptance: false,
    allowScheduled: featureFlags.isParcelScheduledEnabled,
    requireProhibitedItemsAcceptance: false,
  });

  const quote = buildQuotePayload(normalized);

  return {
    ...quote,
    policy: {
      maxDeclaredValueGhs: parcelConfig.maxDeclaredValueGhs,
      liabilityCapGhs: Math.min(parcelConfig.liabilityCapGhs, normalized.declaredValueGhs),
      liabilityFormula: parcelConfig.liabilityFormula,
      insuranceEnabled: false,
      noInsuranceEnabled: parcelConfig.noInsuranceEnabled,
      termsVersion: parcelConfig.termsVersion,
    },
  };
};

const createParcelOrder = async ({ user, payload }) => {
  ensureParcelFeatureEnabled();

  const normalized = normalizeParcelInput(payload, {
    requireTermsAcceptance: true,
    allowScheduled: featureFlags.isParcelScheduledEnabled,
  });

  const paymentMethod = ensureValidPaymentMethod(normalized.paymentMethod);
  const quote = buildQuotePayload(normalized);
  const scheduleWindow = buildScheduleWindow({
    scheduleType: normalized.scheduleType,
    scheduledPickupAt: normalized.scheduledPickupAt,
  });
  const liability = buildLiabilitySnapshot({ declaredValueGhs: normalized.declaredValueGhs });
  const now = new Date();
  const isReleased = scheduleWindow.dispatchReleaseAt && scheduleWindow.dispatchReleaseAt <= now;
  const createData = {
    customerId: user.id,
    status: 'pending_payment',
    scheduleType: normalized.scheduleType,
    scheduledPickupAt: scheduleWindow.scheduledPickupAt,
    pickupWindowStartAt: scheduleWindow.pickupWindowStartAt,
    pickupWindowEndAt: scheduleWindow.pickupWindowEndAt,
    dispatchReleaseAt: scheduleWindow.dispatchReleaseAt,
    dispatchReleasedAt: isReleased ? now : null,

    pickupAddressLine1: normalized.pickup.addressLine1,
    pickupAddressLine2: normalized.pickup.addressLine2 || null,
    pickupCity: normalized.pickup.city,
    pickupState: normalized.pickup.state || null,
    pickupPostalCode: normalized.pickup.postalCode || null,
    pickupLatitude: normalized.pickup.latitude,
    pickupLongitude: normalized.pickup.longitude,
    senderName: normalized.pickup.contactName,
    senderPhone: normalized.pickup.contactPhone,

    dropoffAddressLine1: normalized.dropoff.addressLine1,
    dropoffAddressLine2: normalized.dropoff.addressLine2 || null,
    dropoffCity: normalized.dropoff.city,
    dropoffState: normalized.dropoff.state || null,
    dropoffPostalCode: normalized.dropoff.postalCode || null,
    dropoffLatitude: normalized.dropoff.latitude,
    dropoffLongitude: normalized.dropoff.longitude,
    recipientName: normalized.dropoff.contactName,
    recipientPhone: normalized.dropoff.contactPhone,

    packageCategory: normalized.packageCategory,
    packageDescription: normalized.packageDescription || null,
    sizeTier: normalized.sizeTier,
    weightKg: normalized.weightKg,
    lengthCm: normalized.lengthCm,
    widthCm: normalized.widthCm,
    heightCm: normalized.heightCm,
    declaredValueGhs: normalized.declaredValueGhs,
    isFragile: normalized.isFragile,
    containsLiquid: normalized.containsLiquid,
    isPerishable: normalized.isPerishable,
    containsHazardous: normalized.containsHazardous,
    prohibitedItemsAccepted: normalized.prohibitedItemsAccepted,
    termsAcceptedAt: now,
    termsVersionAccepted: normalized.termsVersion,
    noInsuranceAcknowledgedAt: now,
    liabilityCapGhs: liability.liabilityCapGhs,
    liabilityFormula: liability.liabilityFormula,

    paymentMethod,
    paymentStatus: 'pending',
    originalTripFee: quote.quote.subtotal,
    returnTripFee: quote.returnPolicy.customerChargeEnabled ? quote.returnPolicy.returnTripFeeEstimate : 0,
    serviceFee: quote.quote.serviceFee,
    tax: quote.quote.tax,
    totalAmount: quote.quote.total,
    currency: 'GHS',
    returnChargeStatus: 'not_applicable',
    returnChargeAmount: quote.returnPolicy.customerChargeEnabled ? quote.returnPolicy.returnTripFeeEstimate : 0,
    originalTripEarning: quote.riderEarnings.originalTripEarning,
    returnTripEarning: 0,
    totalRiderEarning: quote.riderEarnings.originalTripEarning,
    notes: normalized.notes || null,
  };

  let created = null;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const parcelNumber = generateParcelNumber();
    try {
      created = await prisma.parcelOrder.create({
        data: {
          parcelNumber,
          ...createData,
        },
      });
      break;
    } catch (error) {
      if (!isParcelNumberConflict(error) || attempt === 4) {
        throw error;
      }
    }
  }

  if (!created) {
    throw new ParcelValidationError(
      'Unable to generate a unique parcel number at the moment',
      503,
      'PARCEL_NUMBER_GENERATION_FAILED'
    );
  }

  await createParcelEvent({
    parcelOrderId: created.id,
    actorId: user.id,
    actorRole: user.role || 'customer',
    eventType: 'parcel_created',
    metadata: {
      scheduleType: normalized.scheduleType,
      declaredValueGhs: normalized.declaredValueGhs,
      totalAmount: quote.quote.total,
      returnChargeEnabled: quote.returnPolicy.customerChargeEnabled,
      returnChargeEstimate: quote.returnPolicy.returnTripFeeEstimate,
    },
  });

  return created;
};

const listParcelOrdersForUser = async ({ user, limit = 30, cursor = null }) => {
  const normalizedLimit = Math.max(1, Math.min(Number(limit) || 30, 100));
  const baseWhere =
    user.role === 'admin'
      ? {}
      : user.role === 'rider'
        ? { riderId: user.id }
        : { customerId: user.id };

  const orders = await prisma.parcelOrder.findMany({
    where: baseWhere,
    orderBy: { createdAt: 'desc' },
    take: normalizedLimit,
    ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
  });

  return orders;
};

const getParcelByIdForUser = async ({ user, parcelId }) => {
  const where = getParcelWhereForUser(user, parcelId);
  return prisma.parcelOrder.findFirst({
    where,
    include: {
      events: {
        orderBy: { createdAt: 'desc' },
        take: 50,
      },
    },
  });
};

const initializePaystackForParcel = async ({ user, parcelId }) => {
  ensureParcelFeatureEnabled();

  const parcel = await prisma.parcelOrder.findUnique({
    where: { id: parcelId },
    select: {
      id: true,
      customerId: true,
      paymentStatus: true,
      paymentMethod: true,
      paymentReferenceId: true,
      totalAmount: true,
      parcelNumber: true,
    },
  });

  if (!parcel) {
    throw new ParcelValidationError('Parcel order not found', 404, 'PARCEL_NOT_FOUND');
  }
  if (parcel.customerId !== user.id) {
    throw new ParcelValidationError('Not authorized for this parcel order', 403, 'FORBIDDEN');
  }
  if (!PAYMENT_PENDING_STATUSES.has(parcel.paymentStatus)) {
    throw new ParcelValidationError('Parcel payment is already settled', 400, 'PAYMENT_ALREADY_SETTLED');
  }

  ensureValidPaymentMethod(parcel.paymentMethod);

  const customer = await prisma.user.findUnique({
    where: { id: user.id },
    select: { email: true },
  });
  const email = customer?.email || user.email;
  if (!email) {
    throw new ParcelValidationError('User email is required for Paystack', 400, 'EMAIL_REQUIRED');
  }

  const reference = `PARCEL-${parcel.parcelNumber}-${Date.now()}`;
  const amount = Math.round(Number(parcel.totalAmount || 0) * 100);
  if (amount <= 0) {
    throw new ParcelValidationError('Invalid parcel amount for payment', 400, 'INVALID_PAYMENT_AMOUNT');
  }

  const init = await paystackService.initializeTransaction({
    email,
    amount,
    reference,
    metadata: {
      parcelOrderId: parcel.id,
      paymentScope: 'parcel_order_payment',
    },
  });

  await prisma.parcelOrder.update({
    where: { id: parcel.id },
    data: {
      paymentProvider: 'paystack',
      paymentReferenceId: init.reference || reference,
      paymentStatus: 'processing',
      status: 'payment_processing',
    },
  });

  await createParcelEvent({
    parcelOrderId: parcel.id,
    actorId: user.id,
    actorRole: user.role || 'customer',
    eventType: 'payment_initialized',
    metadata: {
      reference: init.reference || reference,
      amount: Number(parcel.totalAmount || 0),
      provider: 'paystack',
    },
  });

  return {
    authorizationUrl: init.authorization_url,
    reference: init.reference || reference,
    accessCode: init.access_code,
    paymentAmount: Number(parcel.totalAmount || 0),
  };
};

const confirmParcelPayment = async ({ user, parcelId, reference, provider = 'paystack' }) => {
  ensureParcelFeatureEnabled();
  const paymentProvider = ensureSupportedPaymentProvider(provider);

  const parcel = await prisma.parcelOrder.findUnique({
    where: { id: parcelId },
  });

  if (!parcel) {
    throw new ParcelValidationError('Parcel order not found', 404, 'PARCEL_NOT_FOUND');
  }
  if (parcel.customerId !== user.id) {
    throw new ParcelValidationError('Not authorized for this parcel order', 403, 'FORBIDDEN');
  }
  if (['paid', 'successful'].includes(parcel.paymentStatus)) {
    return {
      alreadyPaid: true,
      parcelId: parcel.id,
      status: parcel.status,
      paymentStatus: parcel.paymentStatus,
    };
  }

  const requestedReference = String(reference || '').trim();
  const storedReference = String(parcel.paymentReferenceId || '').trim();
  const paymentReference = requestedReference || storedReference;
  if (!paymentReference) {
    throw new ParcelValidationError('Payment reference is required', 400, 'REFERENCE_REQUIRED');
  }

  const verification = await paystackService.verifyTransaction(paymentReference);
  const verificationStatus = String(verification?.status || '').toLowerCase();
  if (verificationStatus !== 'success') {
    throw new ParcelValidationError('Payment not verified', 400, 'PAYMENT_NOT_VERIFIED');
  }

  const verifiedReference = String(verification?.reference || '').trim();
  if (!verifiedReference) {
    throw new ParcelValidationError(
      'Unable to verify payment reference from provider',
      502,
      'PAYMENT_VERIFICATION_INVALID'
    );
  }
  if (requestedReference && verifiedReference && verifiedReference !== requestedReference) {
    throw new ParcelValidationError(
      'Verified reference does not match provided payment reference',
      409,
      'PAYMENT_REFERENCE_MISMATCH'
    );
  }

  const metadata = verification?.metadata || {};
  const metadataParcelOrderId = String(
    metadata?.parcelOrderId || metadata?.parcel_order_id || ''
  ).trim();
  if (metadataParcelOrderId && metadataParcelOrderId !== parcel.id) {
    throw new ParcelValidationError(
      'Verified payment metadata does not match parcel order',
      409,
      'PAYMENT_METADATA_MISMATCH'
    );
  }
  if (!metadataParcelOrderId && (!storedReference || verifiedReference !== storedReference)) {
    throw new ParcelValidationError(
      'Unable to bind payment transaction to parcel order',
      409,
      'PAYMENT_METADATA_MISSING'
    );
  }

  const expectedAmount = Math.round(Number(parcel.totalAmount || 0) * 100);
  const verifiedAmount = Number(verification?.amount ?? Number.NaN);
  if (!Number.isFinite(verifiedAmount)) {
    throw new ParcelValidationError(
      'Unable to verify payment amount from provider',
      502,
      'PAYMENT_VERIFICATION_INVALID'
    );
  }
  if (expectedAmount > 0 && verifiedAmount !== expectedAmount) {
    throw new ParcelValidationError(
      'Verified payment amount does not match parcel total',
      409,
      'PAYMENT_AMOUNT_MISMATCH'
    );
  }
  const verifiedCurrency = String(verification?.currency || '').trim().toUpperCase();
  if (verifiedCurrency && verifiedCurrency !== 'GHS') {
    throw new ParcelValidationError(
      'Verified payment currency does not match parcel currency',
      409,
      'PAYMENT_CURRENCY_MISMATCH'
    );
  }

  const finalReference = verifiedReference || paymentReference;

  const now = new Date();
  const isScheduledAndWaiting =
    parcel.scheduleType === 'scheduled' &&
    parcel.dispatchReleaseAt &&
    new Date(parcel.dispatchReleaseAt).getTime() > now.getTime();

  const updated = await prisma.parcelOrder.update({
    where: { id: parcel.id },
    data: {
      paymentStatus: 'paid',
      paymentProvider,
      paymentReferenceId: finalReference,
      status: isScheduledAndWaiting ? 'paid' : 'awaiting_dispatch',
      dispatchReleasedAt: isScheduledAndWaiting ? null : now,
    },
  });

  await createParcelEvent({
    parcelOrderId: parcel.id,
    actorId: user.id,
    actorRole: user.role || 'customer',
    eventType: 'payment_confirmed',
    metadata: {
      reference: finalReference,
      provider: paymentProvider,
      amount: Number(parcel.totalAmount || 0),
      statusAfterPayment: updated.status,
    },
  });

  return {
    alreadyPaid: false,
    parcelId: updated.id,
    status: updated.status,
    paymentStatus: updated.paymentStatus,
  };
};

const cancelParcelOrder = async ({ user, parcelId, reason = null }) => {
  const parcel = await prisma.parcelOrder.findUnique({
    where: { id: parcelId },
    select: {
      id: true,
      customerId: true,
      status: true,
      paymentStatus: true,
    },
  });

  if (!parcel) {
    throw new ParcelValidationError('Parcel order not found', 404, 'PARCEL_NOT_FOUND');
  }
  if (parcel.customerId !== user.id) {
    throw new ParcelValidationError('Not authorized for this parcel order', 403, 'FORBIDDEN');
  }
  if (!CANCELLABLE_STATUSES.has(parcel.status)) {
    throw new ParcelValidationError(
      `Parcel order cannot be cancelled from status "${parcel.status}"`,
      409,
      'INVALID_CANCELLATION_STATE'
    );
  }

  const cancelled = await prisma.parcelOrder.update({
    where: { id: parcel.id },
    data: {
      status: 'cancelled',
      cancelledAt: new Date(),
      cancelReason: reason ? String(reason).trim().slice(0, 500) : null,
    },
  });

  await createParcelEvent({
    parcelOrderId: cancelled.id,
    actorId: user.id,
    actorRole: user.role || 'customer',
    eventType: 'parcel_cancelled',
    reason: cancelled.cancelReason,
  });

  return cancelled;
};

const resendParcelDeliveryCode = async ({ user, parcelId }) => {
  const parcel = await prisma.parcelOrder.findUnique({
    where: { id: parcelId },
  });

  if (!parcel) {
    throw new ParcelValidationError('Parcel order not found', 404, 'PARCEL_NOT_FOUND');
  }

  const isOwner = user.role === 'admin' || parcel.customerId === user.id || parcel.riderId === user.id;
  if (!isOwner) {
    throw new ParcelValidationError('Not authorized for this parcel order', 403, 'FORBIDDEN');
  }

  const resendAvailability = getResendAvailability(parcel);
  if (!resendAvailability.allowed) {
    throw new DeliveryVerificationError(
      resendAvailability.message,
      resendAvailability.status,
      resendAvailability.code,
      resendAvailability.retryAfterSeconds
        ? { retryAfterSeconds: resendAvailability.retryAfterSeconds }
        : {}
    );
  }

  const deliveryCode = generateDeliveryCode();
  const hashed = hashDeliveryCode(parcel.id, deliveryCode);
  const encrypted = encryptDeliveryCode(deliveryCode);

  const smsResult = await sendDeliveryCodeSms({
    phoneNumber: parcel.recipientPhone,
    orderNumber: parcel.parcelNumber,
    code: deliveryCode,
    audience: 'recipient',
    recipientName: parcel.recipientName,
  });

  if (!smsResult.success) {
    throw new ParcelValidationError(
      smsResult.message || 'Failed to send delivery code SMS',
      502,
      'DELIVERY_CODE_SMS_FAILED'
    );
  }

  const updated = await prisma.parcelOrder.update({
    where: { id: parcel.id },
    data: {
      deliveryCodeHash: hashed,
      deliveryCodeEncrypted: encrypted,
      deliveryCodeResendCount: { increment: 1 },
      deliveryCodeLastSentAt: new Date(),
      deliveryCodeFailedAttempts: 0,
      deliveryCodeLockedUntil: null,
      deliveryVerificationMethod: null,
      deliveryCodeVerifiedAt: null,
      deliveryCodeVerifiedByRiderId: null,
      deliveryVerificationRequired: true,
    },
    select: {
      id: true,
      parcelNumber: true,
      deliveryCodeResendCount: true,
      deliveryCodeLastSentAt: true,
    },
  });

  await createParcelEvent({
    parcelOrderId: updated.id,
    actorId: user.id,
    actorRole: user.role,
    eventType: 'delivery_code_resent',
    metadata: {
      resendCount: updated.deliveryCodeResendCount,
      audience: 'recipient',
    },
  });

  return {
    parcelId: updated.id,
    parcelNumber: updated.parcelNumber,
    resentAt: updated.deliveryCodeLastSentAt,
    resendCount: updated.deliveryCodeResendCount,
  };
};

const initiateReturnToSender = async ({ riderId, parcelId, reason = null }) => {
  if (!featureFlags.isParcelReturnToSenderEnabled) {
    throw new ParcelValidationError(
      'Return-to-sender flow is disabled',
      403,
      'PARCEL_RETURN_DISABLED'
    );
  }

  const parcel = await prisma.parcelOrder.findFirst({
    where: { id: parcelId, riderId },
  });

  if (!parcel) {
    throw new ParcelValidationError('Parcel order not found for rider', 404, 'PARCEL_NOT_FOUND');
  }

  if (!['in_transit', 'delivery_attempt_failed'].includes(parcel.status)) {
    throw new ParcelValidationError(
      `Cannot initiate return-to-sender from status "${parcel.status}"`,
      409,
      'INVALID_RETURN_STATE'
    );
  }

  const returnDistanceKm = calculateDistance(
    parcel.dropoffLatitude,
    parcel.dropoffLongitude,
    parcel.pickupLatitude,
    parcel.pickupLongitude
  );
  const returnFinancials = calculateReturnFinancials({ distanceKm: returnDistanceKm });
  const customerReturnCharge = parcelConfig.returnToSender.customerChargeEnabled
    ? returnFinancials.returnTripFee
    : 0;

  const updated = await prisma.parcelOrder.update({
    where: { id: parcel.id },
    data: {
      status: 'returning_to_sender',
      deliveryAttemptFailedAt: parcel.deliveryAttemptFailedAt || new Date(),
      returnChargeAmount: customerReturnCharge,
      returnChargeStatus: parcelConfig.returnToSender.customerChargeEnabled ? 'pending' : 'waived',
      returnChargeReason: reason ? String(reason).trim().slice(0, 500) : null,
      returnTripFee: customerReturnCharge,
      returnTripEarning: returnFinancials.returnTripEarning,
      totalRiderEarning: Number(parcel.originalTripEarning || 0) + Number(returnFinancials.returnTripEarning || 0),
    },
  });

  await createParcelEvent({
    parcelOrderId: updated.id,
    actorId: riderId,
    actorRole: 'rider',
    eventType: 'return_to_sender_initiated',
    reason: updated.returnChargeReason,
    metadata: {
      returnDistanceKm: Math.round(returnDistanceKm * 100) / 100,
      customerReturnCharge,
      returnTripEarning: returnFinancials.returnTripEarning,
      originalTripEarning: updated.originalTripEarning,
      totalRiderEarning: updated.totalRiderEarning,
    },
  });

  return updated;
};

const confirmReturnToSender = async ({ riderId, parcelId, notes = null }) => {
  if (!featureFlags.isParcelReturnToSenderEnabled) {
    throw new ParcelValidationError(
      'Return-to-sender flow is disabled',
      403,
      'PARCEL_RETURN_DISABLED'
    );
  }

  const parcel = await prisma.parcelOrder.findFirst({
    where: { id: parcelId, riderId },
  });

  if (!parcel) {
    throw new ParcelValidationError('Parcel order not found for rider', 404, 'PARCEL_NOT_FOUND');
  }
  if (parcel.status !== 'returning_to_sender') {
    throw new ParcelValidationError(
      `Cannot confirm return from status "${parcel.status}"`,
      409,
      'INVALID_RETURN_CONFIRM_STATE'
    );
  }

  const updated = await prisma.parcelOrder.update({
    where: { id: parcel.id },
    data: {
      status: 'returned_to_sender',
      returnedToSenderAt: new Date(),
      notes: notes ? String(notes).trim().slice(0, 500) : parcel.notes,
    },
  });

  await createParcelEvent({
    parcelOrderId: updated.id,
    actorId: riderId,
    actorRole: 'rider',
    eventType: 'return_to_sender_completed',
    metadata: {
      returnChargeStatus: updated.returnChargeStatus,
      returnChargeAmount: updated.returnChargeAmount,
      totalRiderEarning: updated.totalRiderEarning,
    },
  });

  return updated;
};

module.exports = {
  ParcelValidationError,
  DeliveryVerificationError,
  getParcelConfig,
  createQuote,
  createParcelOrder,
  listParcelOrdersForUser,
  getParcelByIdForUser,
  initializePaystackForParcel,
  confirmParcelPayment,
  cancelParcelOrder,
  resendParcelDeliveryCode,
  initiateReturnToSender,
  confirmReturnToSender,
};
