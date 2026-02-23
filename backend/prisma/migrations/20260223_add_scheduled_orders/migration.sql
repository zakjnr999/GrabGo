ALTER TABLE "orders"
  ADD COLUMN IF NOT EXISTS "isScheduledOrder" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "scheduledForAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "scheduledWindowStartAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "scheduledWindowEndAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "scheduledReleaseAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "scheduledReleasedAt" TIMESTAMP(3);

CREATE INDEX IF NOT EXISTS "orders_isScheduledOrder_status_paymentStatus_scheduledReleasedAt_scheduledReleaseAt_idx"
  ON "orders"("isScheduledOrder", "status", "paymentStatus", "scheduledReleasedAt", "scheduledReleaseAt");
