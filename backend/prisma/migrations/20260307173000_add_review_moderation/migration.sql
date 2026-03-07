ALTER TABLE "vendor_reviews"
  ADD COLUMN "isHidden" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "hiddenReason" TEXT,
  ADD COLUMN "hiddenAt" TIMESTAMP(3),
  ADD COLUMN "reportedCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lastReportedAt" TIMESTAMP(3);

ALTER TABLE "item_reviews"
  ADD COLUMN "isHidden" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "hiddenReason" TEXT,
  ADD COLUMN "hiddenAt" TIMESTAMP(3),
  ADD COLUMN "reportedCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lastReportedAt" TIMESTAMP(3);

CREATE TABLE "vendor_review_reports" (
  "id" TEXT NOT NULL,
  "vendorReviewId" TEXT NOT NULL,
  "reporterId" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "details" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "vendor_review_reports_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "item_review_reports" (
  "id" TEXT NOT NULL,
  "itemReviewId" TEXT NOT NULL,
  "reporterId" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "details" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "item_review_reports_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "vendor_review_reports_vendorReviewId_reporterId_key"
  ON "vendor_review_reports"("vendorReviewId", "reporterId");
CREATE INDEX "vendor_review_reports_reporterId_idx"
  ON "vendor_review_reports"("reporterId");
CREATE INDEX "vendor_review_reports_createdAt_idx"
  ON "vendor_review_reports"("createdAt");

CREATE UNIQUE INDEX "item_review_reports_itemReviewId_reporterId_key"
  ON "item_review_reports"("itemReviewId", "reporterId");
CREATE INDEX "item_review_reports_reporterId_idx"
  ON "item_review_reports"("reporterId");
CREATE INDEX "item_review_reports_createdAt_idx"
  ON "item_review_reports"("createdAt");

CREATE INDEX "vendor_reviews_isHidden_createdAt_idx"
  ON "vendor_reviews"("isHidden", "createdAt");
CREATE INDEX "item_reviews_isHidden_createdAt_idx"
  ON "item_reviews"("isHidden", "createdAt");

ALTER TABLE "vendor_review_reports"
  ADD CONSTRAINT "vendor_review_reports_vendorReviewId_fkey"
  FOREIGN KEY ("vendorReviewId") REFERENCES "vendor_reviews"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "vendor_review_reports"
  ADD CONSTRAINT "vendor_review_reports_reporterId_fkey"
  FOREIGN KEY ("reporterId") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_review_reports"
  ADD CONSTRAINT "item_review_reports_itemReviewId_fkey"
  FOREIGN KEY ("itemReviewId") REFERENCES "item_reviews"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "item_review_reports"
  ADD CONSTRAINT "item_review_reports_reporterId_fkey"
  FOREIGN KEY ("reporterId") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
