-- Fraud foundation schema
-- NOTE: This migration is additive and safe to run repeatedly in environments
-- that might already have some objects provisioned.

DO $$
BEGIN
  CREATE TYPE "FraudDecisionAction" AS ENUM ('allow', 'step_up', 'block', 'allow_degraded');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "FraudCaseSeverity" AS ENUM ('p1', 'p2', 'p3');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "FraudCaseStatus" AS ENUM ('open', 'investigating', 'resolved_true_positive', 'resolved_false_positive', 'resolved_benign');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "FraudChallengeType" AS ENUM ('otp', 'payment_reauth', 'support_assist');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "FraudChallengeStatus" AS ENUM ('pending', 'verified', 'failed', 'expired', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "fraud_decisions" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "actionType" TEXT NOT NULL,
  "score" INTEGER NOT NULL DEFAULT 0,
  "decision" "FraudDecisionAction" NOT NULL DEFAULT 'allow',
  "reasonCodes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "reasonDetails" JSONB,
  "challengeType" "FraudChallengeType",
  "policyVersion" INTEGER NOT NULL DEFAULT 1,
  "policyChecksum" TEXT NOT NULL,
  "contextVersion" INTEGER NOT NULL DEFAULT 1,
  "contextHash" TEXT NOT NULL,
  "requestId" TEXT,
  "shadowMode" BOOLEAN NOT NULL DEFAULT TRUE,
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_signals" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "signalType" TEXT NOT NULL,
  "signalValue" JSONB,
  "weight" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "observedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expiresAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_subject_profiles" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "riskLevel" TEXT NOT NULL DEFAULT 'low',
  "riskScore" INTEGER NOT NULL DEFAULT 0,
  "featureSnapshot" JSONB,
  "graphSnapshot" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_feature_definitions" (
  "id" TEXT PRIMARY KEY,
  "featureName" TEXT NOT NULL,
  "featureVersion" INTEGER NOT NULL DEFAULT 1,
  "description" TEXT,
  "windowSeconds" INTEGER,
  "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_feature_snapshots" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "featureName" TEXT NOT NULL,
  "featureVersion" INTEGER NOT NULL,
  "value" JSONB NOT NULL,
  "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expiresAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_graph_edges" (
  "id" TEXT PRIMARY KEY,
  "fromActorType" TEXT NOT NULL,
  "fromActorId" TEXT NOT NULL,
  "edgeType" TEXT NOT NULL,
  "toEntityType" TEXT NOT NULL,
  "toEntityId" TEXT NOT NULL,
  "weight" DOUBLE PRECISION NOT NULL DEFAULT 1,
  "metadata" JSONB,
  "firstSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_graph_metrics" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "metricName" TEXT NOT NULL,
  "metricWindow" TEXT NOT NULL,
  "metricValue" DOUBLE PRECISION NOT NULL,
  "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_cases" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "severity" "FraudCaseSeverity" NOT NULL DEFAULT 'p3',
  "status" "FraudCaseStatus" NOT NULL DEFAULT 'open',
  "queue" TEXT NOT NULL DEFAULT 'default',
  "openedReason" TEXT NOT NULL,
  "reasonCodes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "evidence" JSONB,
  "assignedTo" TEXT,
  "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "acknowledgedAt" TIMESTAMP(3),
  "closedAt" TIMESTAMP(3),
  "resolutionNote" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_event_outbox" (
  "id" TEXT PRIMARY KEY,
  "eventId" TEXT NOT NULL UNIQUE,
  "eventType" TEXT NOT NULL,
  "aggregateType" TEXT NOT NULL,
  "aggregateId" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "idempotencyKey" TEXT NOT NULL UNIQUE,
  "retryCount" INTEGER NOT NULL DEFAULT 0,
  "nextAttemptAt" TIMESTAMP(3),
  "lastError" TEXT,
  "publishedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_challenges" (
  "id" TEXT PRIMARY KEY,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "challengeType" "FraudChallengeType" NOT NULL,
  "actionType" TEXT,
  "status" "FraudChallengeStatus" NOT NULL DEFAULT 'pending',
  "challengeCodeHash" TEXT,
  "metadata" JSONB,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "verifiedAt" TIMESTAMP(3),
  "failedAttempts" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "fraud_policies" (
  "id" TEXT PRIMARY KEY,
  "version" INTEGER NOT NULL UNIQUE,
  "checksum" TEXT NOT NULL UNIQUE,
  "thresholds" JSONB NOT NULL,
  "ruleWeights" JSONB NOT NULL,
  "challengeCaps" JSONB NOT NULL,
  "ruleToggles" JSONB NOT NULL,
  "effectiveAt" TIMESTAMP(3) NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT FALSE,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "payment_webhook_events" (
  "id" TEXT PRIMARY KEY,
  "provider" TEXT NOT NULL,
  "providerEventId" TEXT NOT NULL,
  "reference" TEXT,
  "signature" TEXT,
  "payload" JSONB NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'received',
  "processedAt" TIMESTAMP(3),
  "errorMessage" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "payment_webhook_events_provider_providerEventId_key" UNIQUE ("provider", "providerEventId")
);

CREATE UNIQUE INDEX IF NOT EXISTS "fraud_subject_profiles_actorType_actorId_key"
  ON "fraud_subject_profiles" ("actorType", "actorId");
CREATE UNIQUE INDEX IF NOT EXISTS "fraud_feature_definitions_featureName_featureVersion_key"
  ON "fraud_feature_definitions" ("featureName", "featureVersion");
CREATE UNIQUE INDEX IF NOT EXISTS "fraud_graph_edges_dedupe_key"
  ON "fraud_graph_edges" ("fromActorType", "fromActorId", "edgeType", "toEntityType", "toEntityId");

CREATE INDEX IF NOT EXISTS "fraud_decisions_actor_lookup_idx"
  ON "fraud_decisions" ("actorType", "actorId", "createdAt");
CREATE INDEX IF NOT EXISTS "fraud_decisions_action_idx"
  ON "fraud_decisions" ("actionType", "createdAt");
CREATE INDEX IF NOT EXISTS "fraud_decisions_decision_idx"
  ON "fraud_decisions" ("decision", "createdAt");
CREATE INDEX IF NOT EXISTS "fraud_decisions_context_hash_idx"
  ON "fraud_decisions" ("contextHash");

CREATE INDEX IF NOT EXISTS "fraud_signals_actor_lookup_idx"
  ON "fraud_signals" ("actorType", "actorId", "createdAt");
CREATE INDEX IF NOT EXISTS "fraud_signals_signal_type_idx"
  ON "fraud_signals" ("signalType", "createdAt");
CREATE INDEX IF NOT EXISTS "fraud_signals_expires_at_idx"
  ON "fraud_signals" ("expiresAt");

CREATE INDEX IF NOT EXISTS "fraud_feature_snapshots_actor_idx"
  ON "fraud_feature_snapshots" ("actorType", "actorId", "computedAt");
CREATE INDEX IF NOT EXISTS "fraud_feature_snapshots_feature_idx"
  ON "fraud_feature_snapshots" ("featureName", "featureVersion", "computedAt");
CREATE INDEX IF NOT EXISTS "fraud_feature_snapshots_expiry_idx"
  ON "fraud_feature_snapshots" ("expiresAt");

CREATE INDEX IF NOT EXISTS "fraud_graph_edges_actor_idx"
  ON "fraud_graph_edges" ("fromActorType", "fromActorId", "lastSeenAt");
CREATE INDEX IF NOT EXISTS "fraud_graph_edges_entity_idx"
  ON "fraud_graph_edges" ("edgeType", "toEntityType", "toEntityId", "lastSeenAt");

CREATE INDEX IF NOT EXISTS "fraud_graph_metrics_actor_idx"
  ON "fraud_graph_metrics" ("actorType", "actorId", "metricName", "computedAt");
CREATE INDEX IF NOT EXISTS "fraud_graph_metrics_metric_idx"
  ON "fraud_graph_metrics" ("metricName", "metricWindow", "computedAt");

CREATE INDEX IF NOT EXISTS "fraud_cases_status_severity_idx"
  ON "fraud_cases" ("status", "severity", "openedAt");
CREATE INDEX IF NOT EXISTS "fraud_cases_queue_status_idx"
  ON "fraud_cases" ("queue", "status", "openedAt");
CREATE INDEX IF NOT EXISTS "fraud_cases_actor_idx"
  ON "fraud_cases" ("actorType", "actorId", "openedAt");

CREATE INDEX IF NOT EXISTS "fraud_event_outbox_publish_idx"
  ON "fraud_event_outbox" ("publishedAt", "createdAt");
CREATE INDEX IF NOT EXISTS "fraud_event_outbox_retry_idx"
  ON "fraud_event_outbox" ("nextAttemptAt", "retryCount");

CREATE INDEX IF NOT EXISTS "fraud_challenges_actor_status_idx"
  ON "fraud_challenges" ("actorType", "actorId", "status", "expiresAt");
CREATE INDEX IF NOT EXISTS "fraud_challenges_type_status_idx"
  ON "fraud_challenges" ("challengeType", "status", "createdAt");

CREATE INDEX IF NOT EXISTS "fraud_policies_active_effective_idx"
  ON "fraud_policies" ("isActive", "effectiveAt");

CREATE INDEX IF NOT EXISTS "payment_webhook_events_reference_idx"
  ON "payment_webhook_events" ("reference");
CREATE INDEX IF NOT EXISTS "payment_webhook_events_status_idx"
  ON "payment_webhook_events" ("status", "createdAt");
