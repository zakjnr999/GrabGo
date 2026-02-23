DO $$
BEGIN
  CREATE TYPE "DeliveryVerificationMethod" AS ENUM ('code', 'authorized_photo');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "orders"
  ADD COLUMN IF NOT EXISTS "isGiftOrder" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "giftRecipientName" TEXT,
  ADD COLUMN IF NOT EXISTS "giftRecipientPhone" TEXT,
  ADD COLUMN IF NOT EXISTS "giftNote" TEXT,
  ADD COLUMN IF NOT EXISTS "deliveryVerificationRequired" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "deliveryCodeHash" TEXT,
  ADD COLUMN IF NOT EXISTS "deliveryCodeEncrypted" TEXT,
  ADD COLUMN IF NOT EXISTS "deliveryCodeFailedAttempts" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "deliveryCodeLockedUntil" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "deliveryCodeVerifiedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "deliveryCodeVerifiedByRiderId" TEXT,
  ADD COLUMN IF NOT EXISTS "deliveryVerificationMethod" "DeliveryVerificationMethod",
  ADD COLUMN IF NOT EXISTS "deliveryProofPhotoUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "deliveryProofReason" TEXT,
  ADD COLUMN IF NOT EXISTS "deliveryProofCapturedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "deliveryVerificationLat" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "deliveryVerificationLng" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "deliveryCodeResendCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "deliveryCodeLastSentAt" TIMESTAMP(3);
