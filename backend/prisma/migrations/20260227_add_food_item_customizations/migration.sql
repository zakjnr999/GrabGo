ALTER TABLE "foods"
  ADD COLUMN IF NOT EXISTS "portionOptions" JSONB,
  ADD COLUMN IF NOT EXISTS "preferenceGroups" JSONB;

ALTER TABLE "cart_items"
  ADD COLUMN IF NOT EXISTS "selectedPortion" JSONB,
  ADD COLUMN IF NOT EXISTS "selectedPreferences" JSONB,
  ADD COLUMN IF NOT EXISTS "itemNote" TEXT,
  ADD COLUMN IF NOT EXISTS "customizationKey" TEXT;

ALTER TABLE "order_items"
  ADD COLUMN IF NOT EXISTS "selectedPortion" JSONB,
  ADD COLUMN IF NOT EXISTS "selectedPreferences" JSONB,
  ADD COLUMN IF NOT EXISTS "itemNote" TEXT,
  ADD COLUMN IF NOT EXISTS "customizationKey" TEXT;

CREATE INDEX IF NOT EXISTS "cart_items_cartId_customizationKey_idx"
  ON "cart_items"("cartId", "customizationKey");
