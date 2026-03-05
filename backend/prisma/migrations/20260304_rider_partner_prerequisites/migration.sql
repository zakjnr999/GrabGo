-- Phase 1: Rider Partner System Prerequisites
-- Adds fields to Rider and RiderWallet for metrics sync and withdrawal safety

-- Add performance metrics to Rider
ALTER TABLE "riders" ADD COLUMN IF NOT EXISTS "rating" DOUBLE PRECISION NOT NULL DEFAULT 5.0;
ALTER TABLE "riders" ADD COLUMN IF NOT EXISTS "ratingCount" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "riders" ADD COLUMN IF NOT EXISTS "totalDeliveries" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "riders" ADD COLUMN IF NOT EXISTS "activeDays" INTEGER NOT NULL DEFAULT 0;

-- Add withdrawal guard fields to RiderWallet
ALTER TABLE "rider_wallets" ADD COLUMN IF NOT EXISTS "pendingEarnings" DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE "rider_wallets" ADD COLUMN IF NOT EXISTS "lastWithdrawalAt" TIMESTAMP(3);
