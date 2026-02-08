-- Remove mobile_money and mtn_momo from enums
-- 1) Normalize existing data
UPDATE "orders" SET "paymentMethod" = 'card' WHERE "paymentMethod" IN ('mobile_money', 'mtn_momo');
UPDATE "payments" SET "paymentMethod" = 'card' WHERE "paymentMethod" IN ('mobile_money', 'mtn_momo');
UPDATE "orders" SET "paymentProvider" = 'paystack' WHERE "paymentProvider" = 'mtn_momo';
UPDATE "payments" SET "provider" = 'paystack' WHERE "provider" = 'mtn_momo';

-- 2) Recreate PaymentMethod without mobile_money/mtn_momo
CREATE TYPE "PaymentMethod_new" AS ENUM ('cash', 'card', 'online');
ALTER TABLE "orders"
  ALTER COLUMN "paymentMethod"
  TYPE "PaymentMethod_new"
  USING ("paymentMethod"::text::"PaymentMethod_new");
ALTER TABLE "payments"
  ALTER COLUMN "paymentMethod"
  TYPE "PaymentMethod_new"
  USING ("paymentMethod"::text::"PaymentMethod_new");
DROP TYPE "PaymentMethod";
ALTER TYPE "PaymentMethod_new" RENAME TO "PaymentMethod";

-- 3) Recreate PaymentProvider without mtn_momo
CREATE TYPE "PaymentProvider_new" AS ENUM ('vodafone_cash', 'airtel_money', 'tigo_cash', 'stripe', 'paystack');
ALTER TABLE "orders"
  ALTER COLUMN "paymentProvider"
  TYPE "PaymentProvider_new"
  USING ("paymentProvider"::text::"PaymentProvider_new");
ALTER TABLE "payments"
  ALTER COLUMN "provider"
  TYPE "PaymentProvider_new"
  USING ("provider"::text::"PaymentProvider_new");
DROP TYPE "PaymentProvider";
ALTER TYPE "PaymentProvider_new" RENAME TO "PaymentProvider";
