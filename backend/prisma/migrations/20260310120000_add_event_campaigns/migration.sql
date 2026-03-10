CREATE TYPE "EventParticipationStatus" AS ENUM ('pending', 'approved', 'rejected', 'withdrawn');

ALTER TABLE "foods"
  ADD COLUMN "eventCampaignId" TEXT,
  ADD COLUMN "isEventItem" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "isEventBundle" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "event_campaigns" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "slug" TEXT NOT NULL,
  "eventType" TEXT NOT NULL,
  "description" TEXT,
  "startsAt" TIMESTAMP(3) NOT NULL,
  "endsAt" TIMESTAMP(3) NOT NULL,
  "eventDate" TIMESTAMP(3) NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "heroTitle" TEXT,
  "heroSubtitle" TEXT,
  "heroImageUrl" TEXT,
  "bannerImageUrl" TEXT,
  "bannerBackgroundColor" TEXT NOT NULL DEFAULT '#FFFFFF',
  "ctaLabel" TEXT NOT NULL DEFAULT 'View event',
  "preEventNotifyDays" INTEGER NOT NULL DEFAULT 3,
  "preEventNotifyHour" INTEGER NOT NULL DEFAULT 18,
  "sameDayNotifyHour" INTEGER NOT NULL DEFAULT 12,
  "lastCallNotifyHour" INTEGER NOT NULL DEFAULT 17,
  "recentOrderLookbackDays" INTEGER NOT NULL DEFAULT 30,
  "orderWindowStartHour" INTEGER,
  "orderWindowEndHour" INTEGER,
  "promotionalBannerId" TEXT,
  "createdById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "event_campaigns_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "restaurant_event_participations" (
  "id" TEXT NOT NULL,
  "eventCampaignId" TEXT NOT NULL,
  "restaurantId" TEXT NOT NULL,
  "status" "EventParticipationStatus" NOT NULL DEFAULT 'pending',
  "supportsPreorder" BOOLEAN NOT NULL DEFAULT false,
  "isApproved" BOOLEAN NOT NULL DEFAULT false,
  "isFeatured" BOOLEAN NOT NULL DEFAULT false,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "optedInAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "approvedAt" TIMESTAMP(3),
  "rejectedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "restaurant_event_participations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "event_campaign_notification_dispatches" (
  "id" TEXT NOT NULL,
  "eventCampaignId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "phase" TEXT NOT NULL,
  "scheduledNotificationId" TEXT,
  "scheduledFor" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "event_campaign_notification_dispatches_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "event_campaigns_slug_key" ON "event_campaigns"("slug");
CREATE UNIQUE INDEX "event_campaigns_promotionalBannerId_key" ON "event_campaigns"("promotionalBannerId");
CREATE INDEX "event_campaigns_isActive_startsAt_endsAt_idx" ON "event_campaigns"("isActive", "startsAt", "endsAt");
CREATE INDEX "event_campaigns_eventDate_idx" ON "event_campaigns"("eventDate");

CREATE UNIQUE INDEX "restaurant_event_participations_eventCampaignId_restaurantId_key"
  ON "restaurant_event_participations"("eventCampaignId", "restaurantId");
CREATE INDEX "restaurant_event_participations_restaurantId_status_idx"
  ON "restaurant_event_participations"("restaurantId", "status");
CREATE INDEX "restaurant_event_participations_eventCampaignId_isApproved_isFeatured_idx"
  ON "restaurant_event_participations"("eventCampaignId", "isApproved", "isFeatured");

CREATE UNIQUE INDEX "event_campaign_notification_dispatches_scheduledNotificationId_key"
  ON "event_campaign_notification_dispatches"("scheduledNotificationId");
CREATE UNIQUE INDEX "event_campaign_notification_dispatches_eventCampaignId_userId_phase_key"
  ON "event_campaign_notification_dispatches"("eventCampaignId", "userId", "phase");
CREATE INDEX "event_campaign_notification_dispatches_eventCampaignId_phase_idx"
  ON "event_campaign_notification_dispatches"("eventCampaignId", "phase");
CREATE INDEX "event_campaign_notification_dispatches_userId_scheduledFor_idx"
  ON "event_campaign_notification_dispatches"("userId", "scheduledFor");

CREATE INDEX "foods_eventCampaignId_isEventItem_isEventBundle_idx"
  ON "foods"("eventCampaignId", "isEventItem", "isEventBundle");

ALTER TABLE "foods"
  ADD CONSTRAINT "foods_eventCampaignId_fkey"
  FOREIGN KEY ("eventCampaignId") REFERENCES "event_campaigns"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "event_campaigns"
  ADD CONSTRAINT "event_campaigns_promotionalBannerId_fkey"
  FOREIGN KEY ("promotionalBannerId") REFERENCES "promotional_banners"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "event_campaigns"
  ADD CONSTRAINT "event_campaigns_createdById_fkey"
  FOREIGN KEY ("createdById") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "restaurant_event_participations"
  ADD CONSTRAINT "restaurant_event_participations_eventCampaignId_fkey"
  FOREIGN KEY ("eventCampaignId") REFERENCES "event_campaigns"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "restaurant_event_participations"
  ADD CONSTRAINT "restaurant_event_participations_restaurantId_fkey"
  FOREIGN KEY ("restaurantId") REFERENCES "restaurants"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_campaign_notification_dispatches"
  ADD CONSTRAINT "event_campaign_notification_dispatches_eventCampaignId_fkey"
  FOREIGN KEY ("eventCampaignId") REFERENCES "event_campaigns"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_campaign_notification_dispatches"
  ADD CONSTRAINT "event_campaign_notification_dispatches_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_campaign_notification_dispatches"
  ADD CONSTRAINT "event_campaign_notification_dispatches_scheduledNotificationId_fkey"
  FOREIGN KEY ("scheduledNotificationId") REFERENCES "scheduled_notifications"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
