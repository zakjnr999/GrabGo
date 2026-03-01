DO $$
BEGIN
  CREATE TYPE "ParcelOrderStatus" AS ENUM (
    'pending_payment',
    'payment_processing',
    'paid',
    'awaiting_dispatch',
    'dispatching',
    'rider_assigned',
    'picked_up',
    'in_transit',
    'delivery_attempt_failed',
    'returning_to_sender',
    'returned_to_sender',
    'delivered',
    'cancelled'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "ParcelScheduleType" AS ENUM ('on_demand', 'scheduled');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "ReturnChargeStatus" AS ENUM ('not_applicable', 'pending', 'paid', 'waived', 'failed');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "riders"
  ADD COLUMN IF NOT EXISTS "parcelOptIn" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS "parcel_orders" (
  "id" TEXT NOT NULL,
  "parcelNumber" TEXT NOT NULL,
  "customerId" TEXT NOT NULL,
  "riderId" TEXT,
  "status" "ParcelOrderStatus" NOT NULL DEFAULT 'pending_payment',
  "scheduleType" "ParcelScheduleType" NOT NULL DEFAULT 'on_demand',
  "scheduledPickupAt" TIMESTAMP(3),
  "pickupWindowStartAt" TIMESTAMP(3),
  "pickupWindowEndAt" TIMESTAMP(3),
  "dispatchReleaseAt" TIMESTAMP(3),
  "dispatchReleasedAt" TIMESTAMP(3),
  "pickupAddressLine1" TEXT NOT NULL,
  "pickupAddressLine2" TEXT,
  "pickupCity" TEXT NOT NULL,
  "pickupState" TEXT,
  "pickupPostalCode" TEXT,
  "pickupLatitude" DOUBLE PRECISION NOT NULL,
  "pickupLongitude" DOUBLE PRECISION NOT NULL,
  "senderName" TEXT NOT NULL,
  "senderPhone" TEXT NOT NULL,
  "dropoffAddressLine1" TEXT NOT NULL,
  "dropoffAddressLine2" TEXT,
  "dropoffCity" TEXT NOT NULL,
  "dropoffState" TEXT,
  "dropoffPostalCode" TEXT,
  "dropoffLatitude" DOUBLE PRECISION NOT NULL,
  "dropoffLongitude" DOUBLE PRECISION NOT NULL,
  "recipientName" TEXT NOT NULL,
  "recipientPhone" TEXT NOT NULL,
  "packageCategory" TEXT NOT NULL,
  "packageDescription" TEXT,
  "sizeTier" TEXT NOT NULL,
  "weightKg" DOUBLE PRECISION NOT NULL,
  "lengthCm" DOUBLE PRECISION,
  "widthCm" DOUBLE PRECISION,
  "heightCm" DOUBLE PRECISION,
  "declaredValueGhs" DOUBLE PRECISION NOT NULL,
  "isFragile" BOOLEAN NOT NULL DEFAULT false,
  "containsLiquid" BOOLEAN NOT NULL DEFAULT false,
  "isPerishable" BOOLEAN NOT NULL DEFAULT false,
  "containsHazardous" BOOLEAN NOT NULL DEFAULT false,
  "prohibitedItemsAccepted" BOOLEAN NOT NULL DEFAULT false,
  "termsAcceptedAt" TIMESTAMP(3) NOT NULL,
  "termsVersionAccepted" TEXT NOT NULL,
  "liabilityCapGhs" DOUBLE PRECISION NOT NULL,
  "liabilityFormula" TEXT NOT NULL,
  "noInsuranceAcknowledgedAt" TIMESTAMP(3),
  "paymentMethod" "PaymentMethod" NOT NULL,
  "paymentProvider" "PaymentProvider",
  "paymentReferenceId" TEXT,
  "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'pending',
  "originalTripFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "returnTripFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "serviceFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "tax" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "currency" "Currency" NOT NULL DEFAULT 'GHS',
  "returnChargeStatus" "ReturnChargeStatus" NOT NULL DEFAULT 'not_applicable',
  "returnChargeAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "returnChargeReason" TEXT,
  "cancelledAt" TIMESTAMP(3),
  "pickedUpAt" TIMESTAMP(3),
  "inTransitAt" TIMESTAMP(3),
  "deliveryAttemptFailedAt" TIMESTAMP(3),
  "returnedToSenderAt" TIMESTAMP(3),
  "deliveredAt" TIMESTAMP(3),
  "cancelReason" TEXT,
  "deliveryVerificationRequired" BOOLEAN NOT NULL DEFAULT true,
  "deliveryCodeHash" TEXT,
  "deliveryCodeEncrypted" TEXT,
  "deliveryCodeFailedAttempts" INTEGER NOT NULL DEFAULT 0,
  "deliveryCodeLockedUntil" TIMESTAMP(3),
  "deliveryCodeVerifiedAt" TIMESTAMP(3),
  "deliveryCodeVerifiedByRiderId" TEXT,
  "deliveryVerificationMethod" "DeliveryVerificationMethod",
  "deliveryProofPhotoUrl" TEXT,
  "deliveryProofReason" TEXT,
  "deliveryProofCapturedAt" TIMESTAMP(3),
  "deliveryVerificationLat" DOUBLE PRECISION,
  "deliveryVerificationLng" DOUBLE PRECISION,
  "deliveryCodeResendCount" INTEGER NOT NULL DEFAULT 0,
  "deliveryCodeLastSentAt" TIMESTAMP(3),
  "originalTripEarning" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "returnTripEarning" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "totalRiderEarning" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "notes" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "parcel_orders_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "parcel_events" (
  "id" TEXT NOT NULL,
  "parcelOrderId" TEXT NOT NULL,
  "actorId" TEXT,
  "actorRole" TEXT,
  "eventType" TEXT NOT NULL,
  "reason" TEXT,
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "parcel_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "parcel_orders_parcelNumber_key"
  ON "parcel_orders"("parcelNumber");

CREATE INDEX IF NOT EXISTS "parcel_orders_customerId_idx"
  ON "parcel_orders"("customerId");
CREATE INDEX IF NOT EXISTS "parcel_orders_riderId_idx"
  ON "parcel_orders"("riderId");
CREATE INDEX IF NOT EXISTS "parcel_orders_status_idx"
  ON "parcel_orders"("status");
CREATE INDEX IF NOT EXISTS "parcel_orders_paymentStatus_idx"
  ON "parcel_orders"("paymentStatus");
CREATE INDEX IF NOT EXISTS "parcel_orders_status_paymentStatus_idx"
  ON "parcel_orders"("status", "paymentStatus");
CREATE INDEX IF NOT EXISTS "parcel_orders_dispatchReleaseAt_status_idx"
  ON "parcel_orders"("dispatchReleaseAt", "status");
CREATE INDEX IF NOT EXISTS "parcel_orders_createdAt_idx"
  ON "parcel_orders"("createdAt");

CREATE INDEX IF NOT EXISTS "parcel_events_parcelOrderId_idx"
  ON "parcel_events"("parcelOrderId");
CREATE INDEX IF NOT EXISTS "parcel_events_actorId_idx"
  ON "parcel_events"("actorId");
CREATE INDEX IF NOT EXISTS "parcel_events_eventType_idx"
  ON "parcel_events"("eventType");

DO $$
BEGIN
  ALTER TABLE "parcel_orders"
    ADD CONSTRAINT "parcel_orders_customerId_fkey"
    FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE "parcel_orders"
    ADD CONSTRAINT "parcel_orders_riderId_fkey"
    FOREIGN KEY ("riderId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE "parcel_events"
    ADD CONSTRAINT "parcel_events_parcelOrderId_fkey"
    FOREIGN KEY ("parcelOrderId") REFERENCES "parcel_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
