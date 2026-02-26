ALTER TABLE "carts"
  ADD COLUMN IF NOT EXISTS "providerScopeKey" TEXT;

CREATE INDEX IF NOT EXISTS "carts_userId_fulfillmentMode_providerScopeKey_isActive_idx"
  ON "carts"("userId", "fulfillmentMode", "providerScopeKey", "isActive");

DO $$
BEGIN
  CREATE TYPE "CheckoutSessionStatus" AS ENUM ('pending', 'processing', 'paid', 'failed', 'cancelled', 'expired');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "checkout_sessions" (
  "id" TEXT NOT NULL,
  "groupOrderNumber" TEXT NOT NULL,
  "customerId" TEXT NOT NULL,
  "fulfillmentMode" "FulfillmentMode" NOT NULL DEFAULT 'delivery',
  "paymentMethod" "PaymentMethod" NOT NULL,
  "paymentProvider" "PaymentProvider",
  "paymentReferenceId" TEXT,
  "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'pending',
  "status" "CheckoutSessionStatus" NOT NULL DEFAULT 'pending',
  "subtotal" DOUBLE PRECISION NOT NULL,
  "deliveryFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "serviceFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "tax" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "rainFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "totalAmount" DOUBLE PRECISION NOT NULL,
  "creditsApplied" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "vendorCount" INTEGER NOT NULL DEFAULT 1,
  "currency" "Currency" NOT NULL DEFAULT 'GHS',
  "notes" TEXT,
  "restrictions" JSONB,
  "deliveryStreet" TEXT,
  "deliveryCity" TEXT,
  "deliveryState" TEXT,
  "deliveryZipCode" TEXT,
  "deliveryLatitude" DOUBLE PRECISION,
  "deliveryLongitude" DOUBLE PRECISION,
  "expiresAt" TIMESTAMP(3),
  "paidAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "checkout_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "checkout_sessions_groupOrderNumber_key"
  ON "checkout_sessions"("groupOrderNumber");
CREATE INDEX IF NOT EXISTS "checkout_sessions_customerId_idx"
  ON "checkout_sessions"("customerId");
CREATE INDEX IF NOT EXISTS "checkout_sessions_status_idx"
  ON "checkout_sessions"("status");
CREATE INDEX IF NOT EXISTS "checkout_sessions_paymentStatus_idx"
  ON "checkout_sessions"("paymentStatus");
CREATE INDEX IF NOT EXISTS "checkout_sessions_createdAt_idx"
  ON "checkout_sessions"("createdAt");

DO $$
BEGIN
  IF to_regclass('"users"') IS NOT NULL THEN
    ALTER TABLE "checkout_sessions"
      ADD CONSTRAINT "checkout_sessions_customerId_fkey"
      FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  ELSIF to_regclass('"User"') IS NOT NULL THEN
    ALTER TABLE "checkout_sessions"
      ADD CONSTRAINT "checkout_sessions_customerId_fkey"
      FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "orders"
  ADD COLUMN IF NOT EXISTS "checkoutSessionId" TEXT,
  ADD COLUMN IF NOT EXISTS "groupId" TEXT,
  ADD COLUMN IF NOT EXISTS "groupOrderNumber" TEXT,
  ADD COLUMN IF NOT EXISTS "isGroupedOrder" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS "orders_checkoutSessionId_idx"
  ON "orders"("checkoutSessionId");
CREATE INDEX IF NOT EXISTS "orders_groupId_idx"
  ON "orders"("groupId");
CREATE INDEX IF NOT EXISTS "orders_groupOrderNumber_idx"
  ON "orders"("groupOrderNumber");

DO $$
BEGIN
  IF to_regclass('"checkout_sessions"') IS NOT NULL THEN
    ALTER TABLE "orders"
      ADD CONSTRAINT "orders_checkoutSessionId_fkey"
      FOREIGN KEY ("checkoutSessionId") REFERENCES "checkout_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
