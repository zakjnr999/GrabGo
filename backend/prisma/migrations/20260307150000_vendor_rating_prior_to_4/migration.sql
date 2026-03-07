ALTER TABLE "restaurants"
  ALTER COLUMN "rating" SET DEFAULT 4.0;

ALTER TABLE "grocery_stores"
  ALTER COLUMN "rating" SET DEFAULT 4.0;

ALTER TABLE "pharmacy_stores"
  ALTER COLUMN "rating" SET DEFAULT 4.0;

ALTER TABLE "grabmart_stores"
  ALTER COLUMN "rating" SET DEFAULT 4.0;

UPDATE "restaurants"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "ratingCount" = 0
  AND "totalReviews" = 0
  AND "ratingSum" = 0;

UPDATE "grocery_stores"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "ratingCount" = 0
  AND "totalReviews" = 0
  AND "ratingSum" = 0;

UPDATE "pharmacy_stores"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "ratingCount" = 0
  AND "totalReviews" = 0
  AND "ratingSum" = 0;

UPDATE "grabmart_stores"
SET "rating" = 4.0
WHERE "rating" = 0
  AND "ratingCount" = 0
  AND "totalReviews" = 0
  AND "ratingSum" = 0;
