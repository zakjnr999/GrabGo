-- Create user_credit_holds table
CREATE TABLE "user_credit_holds" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "amount" DOUBLE PRECISION NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "expiresAt" TIMESTAMP(3),
  "capturedAt" TIMESTAMP(3),
  "releasedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_credit_holds_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "user_credit_holds_orderId_key" ON "user_credit_holds"("orderId");
CREATE INDEX "user_credit_holds_userId_idx" ON "user_credit_holds"("userId");
CREATE INDEX "user_credit_holds_isActive_idx" ON "user_credit_holds"("isActive");

ALTER TABLE "user_credit_holds"
  ADD CONSTRAINT "user_credit_holds_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "user_credit_holds"
  ADD CONSTRAINT "user_credit_holds_orderId_fkey"
  FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
