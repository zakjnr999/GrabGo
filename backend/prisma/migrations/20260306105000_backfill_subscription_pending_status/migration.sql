UPDATE "subscriptions" s
SET "status" = 'pending'
WHERE s."status" = 'active'
  AND EXISTS (
    SELECT 1
    FROM "subscription_payments" p
    WHERE p."subscriptionId" = s."id"
      AND p."status" = 'pending'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM "subscription_payments" p
    WHERE p."subscriptionId" = s."id"
      AND p."status" = 'success'
  );
