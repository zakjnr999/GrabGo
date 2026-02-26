-- Expand favorites support to cover all vendor/services domains.
-- Adds:
-- 1) Favorite GrabMart stores
-- 2) Favorite Pharmacy items

CREATE TABLE IF NOT EXISTS "user_favorite_grabmart_stores" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "storeId" TEXT NOT NULL,
  "addedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_favorite_grabmart_stores_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_favorite_grabmart_stores_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "user_favorite_grabmart_stores_storeId_fkey"
    FOREIGN KEY ("storeId") REFERENCES "grabmart_stores"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "user_favorite_grabmart_stores_userId_storeId_key"
  ON "user_favorite_grabmart_stores"("userId", "storeId");

CREATE INDEX IF NOT EXISTS "user_favorite_grabmart_stores_userId_idx"
  ON "user_favorite_grabmart_stores"("userId");

CREATE INDEX IF NOT EXISTS "user_favorite_grabmart_stores_storeId_idx"
  ON "user_favorite_grabmart_stores"("storeId");

CREATE TABLE IF NOT EXISTS "user_favorite_pharmacy_items" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "pharmacyItemId" TEXT NOT NULL,
  "addedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_favorite_pharmacy_items_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_favorite_pharmacy_items_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "user_favorite_pharmacy_items_pharmacyItemId_fkey"
    FOREIGN KEY ("pharmacyItemId") REFERENCES "pharmacy_items"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "user_favorite_pharmacy_items_userId_pharmacyItemId_key"
  ON "user_favorite_pharmacy_items"("userId", "pharmacyItemId");

CREATE INDEX IF NOT EXISTS "user_favorite_pharmacy_items_userId_idx"
  ON "user_favorite_pharmacy_items"("userId");

CREATE INDEX IF NOT EXISTS "user_favorite_pharmacy_items_pharmacyItemId_idx"
  ON "user_favorite_pharmacy_items"("pharmacyItemId");
