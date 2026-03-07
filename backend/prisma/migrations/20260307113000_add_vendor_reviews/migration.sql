CREATE TABLE "vendor_reviews" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "vendorType" TEXT NOT NULL,
    "restaurantId" TEXT,
    "groceryStoreId" TEXT,
    "pharmacyStoreId" TEXT,
    "grabMartStoreId" TEXT,
    "rating" INTEGER NOT NULL,
    "feedbackTags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendor_reviews_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "vendor_reviews_rating_check" CHECK ("rating" >= 1 AND "rating" <= 5),
    CONSTRAINT "vendor_reviews_single_vendor_check" CHECK (
        (CASE WHEN "restaurantId" IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN "groceryStoreId" IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN "pharmacyStoreId" IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN "grabMartStoreId" IS NOT NULL THEN 1 ELSE 0 END) = 1
    )
);

CREATE UNIQUE INDEX "vendor_reviews_orderId_key" ON "vendor_reviews"("orderId");
CREATE INDEX "vendor_reviews_customerId_idx" ON "vendor_reviews"("customerId");
CREATE INDEX "vendor_reviews_vendorType_idx" ON "vendor_reviews"("vendorType");
CREATE INDEX "vendor_reviews_restaurantId_idx" ON "vendor_reviews"("restaurantId");
CREATE INDEX "vendor_reviews_groceryStoreId_idx" ON "vendor_reviews"("groceryStoreId");
CREATE INDEX "vendor_reviews_pharmacyStoreId_idx" ON "vendor_reviews"("pharmacyStoreId");
CREATE INDEX "vendor_reviews_grabMartStoreId_idx" ON "vendor_reviews"("grabMartStoreId");

ALTER TABLE "vendor_reviews"
    ADD CONSTRAINT "vendor_reviews_orderId_fkey"
    FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "vendor_reviews"
    ADD CONSTRAINT "vendor_reviews_customerId_fkey"
    FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "vendor_reviews"
    ADD CONSTRAINT "vendor_reviews_restaurantId_fkey"
    FOREIGN KEY ("restaurantId") REFERENCES "restaurants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "vendor_reviews"
    ADD CONSTRAINT "vendor_reviews_groceryStoreId_fkey"
    FOREIGN KEY ("groceryStoreId") REFERENCES "grocery_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "vendor_reviews"
    ADD CONSTRAINT "vendor_reviews_pharmacyStoreId_fkey"
    FOREIGN KEY ("pharmacyStoreId") REFERENCES "pharmacy_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "vendor_reviews"
    ADD CONSTRAINT "vendor_reviews_grabMartStoreId_fkey"
    FOREIGN KEY ("grabMartStoreId") REFERENCES "grabmart_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;
