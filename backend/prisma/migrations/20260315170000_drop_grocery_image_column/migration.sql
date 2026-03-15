UPDATE "grocery_items"
SET "thumbnailImage" = "image"
WHERE COALESCE(NULLIF("thumbnailImage", ''), '') = '';

ALTER TABLE "grocery_items"
  ALTER COLUMN "thumbnailImage" SET NOT NULL;

ALTER TABLE "grocery_items"
  DROP COLUMN "image";
