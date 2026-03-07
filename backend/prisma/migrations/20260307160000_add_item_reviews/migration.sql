ALTER TABLE "foods"
  ADD COLUMN "ratingSum" DOUBLE PRECISION NOT NULL DEFAULT 0,
  ALTER COLUMN "rating" SET DEFAULT 4.0;

ALTER TABLE "grocery_items"
  ADD COLUMN "ratingSum" DOUBLE PRECISION NOT NULL DEFAULT 0,
  ALTER COLUMN "rating" SET DEFAULT 4.0;

ALTER TABLE "pharmacy_items"
  ADD COLUMN "ratingSum" DOUBLE PRECISION NOT NULL DEFAULT 0,
  ALTER COLUMN "rating" SET DEFAULT 4.0;

ALTER TABLE "grabmart_items"
  ADD COLUMN "ratingSum" DOUBLE PRECISION NOT NULL DEFAULT 0,
  ALTER COLUMN "rating" SET DEFAULT 4.0;

UPDATE "foods"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "totalReviews" = 0
  AND "ratingSum" = 0;

UPDATE "grocery_items"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "reviewCount" = 0
  AND "ratingSum" = 0;

UPDATE "pharmacy_items"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "reviewCount" = 0
  AND "ratingSum" = 0;

UPDATE "grabmart_items"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "reviewCount" = 0
  AND "ratingSum" = 0;

CREATE TABLE "item_reviews" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "orderItemId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "itemType" TEXT NOT NULL,
    "foodId" TEXT,
    "groceryItemId" TEXT,
    "pharmacyItemId" TEXT,
    "grabMartItemId" TEXT,
    "rating" INTEGER NOT NULL,
    "feedbackTags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "item_reviews_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "item_reviews_rating_check" CHECK ("rating" >= 1 AND "rating" <= 5),
    CONSTRAINT "item_reviews_single_item_check" CHECK (
        (CASE WHEN "foodId" IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN "groceryItemId" IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN "pharmacyItemId" IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN "grabMartItemId" IS NOT NULL THEN 1 ELSE 0 END) = 1
    )
);

CREATE UNIQUE INDEX "item_reviews_orderItemId_key" ON "item_reviews"("orderItemId");
CREATE INDEX "item_reviews_orderId_idx" ON "item_reviews"("orderId");
CREATE INDEX "item_reviews_customerId_idx" ON "item_reviews"("customerId");
CREATE INDEX "item_reviews_itemType_idx" ON "item_reviews"("itemType");
CREATE INDEX "item_reviews_foodId_idx" ON "item_reviews"("foodId");
CREATE INDEX "item_reviews_groceryItemId_idx" ON "item_reviews"("groceryItemId");
CREATE INDEX "item_reviews_pharmacyItemId_idx" ON "item_reviews"("pharmacyItemId");
CREATE INDEX "item_reviews_grabMartItemId_idx" ON "item_reviews"("grabMartItemId");

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_orderId_fkey"
    FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_orderItemId_fkey"
    FOREIGN KEY ("orderItemId") REFERENCES "order_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_customerId_fkey"
    FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_foodId_fkey"
    FOREIGN KEY ("foodId") REFERENCES "foods"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_groceryItemId_fkey"
    FOREIGN KEY ("groceryItemId") REFERENCES "grocery_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_pharmacyItemId_fkey"
    FOREIGN KEY ("pharmacyItemId") REFERENCES "pharmacy_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_reviews"
    ADD CONSTRAINT "item_reviews_grabMartItemId_fkey"
    FOREIGN KEY ("grabMartItemId") REFERENCES "grabmart_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;
