ALTER TABLE "public"."pharmacy_items"
ADD COLUMN "thumbnailImage" TEXT;

UPDATE "public"."pharmacy_items"
SET "thumbnailImage" = "image"
WHERE "thumbnailImage" IS NULL
   OR LENGTH(TRIM(COALESCE("thumbnailImage", ''))) = 0;
