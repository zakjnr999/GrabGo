-- Add creditsApplied to orders
ALTER TABLE "orders" ADD COLUMN "creditsApplied" DOUBLE PRECISION NOT NULL DEFAULT 0;
