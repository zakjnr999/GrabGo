/**
 * Seed Script — Quest & Milestone Definitions
 *
 * Populates the QuestDefinition and MilestoneDefinition tables with
 * production-ready records. Uses upsert to be idempotent (safe to re-run).
 *
 * Usage:
 *   node scripts/seed_incentive_definitions.js
 */

const prisma = require('../config/prisma');

// ────────────────────────────────────────────────────────────────────
// Quest Definitions
// ────────────────────────────────────────────────────────────────────
// period: 'daily' | 'weekly'
// minLevel: 'L1'–'L5' (minimum partner level to unlock)
// rewardAmount: base GHS (multiplied by partner level multiplier at payout)

const QUESTS = [
  // ── Daily Quests ──
  {
    name: 'Quick Starter',
    description: 'Complete 3 deliveries today',
    period: 'daily',
    targetCount: 3,
    rewardAmount: 2.0,
    minLevel: 'L1',
    sortOrder: 1,
  },
  {
    name: 'Daily Grinder',
    description: 'Complete 5 deliveries today',
    period: 'daily',
    targetCount: 5,
    rewardAmount: 4.0,
    minLevel: 'L1',
    sortOrder: 2,
  },
  {
    name: 'Power Hour',
    description: 'Complete 8 deliveries today',
    period: 'daily',
    targetCount: 8,
    rewardAmount: 7.0,
    minLevel: 'L2',
    sortOrder: 3,
  },
  {
    name: 'Daily Champion',
    description: 'Complete 12 deliveries today',
    period: 'daily',
    targetCount: 12,
    rewardAmount: 12.0,
    minLevel: 'L3',
    sortOrder: 4,
  },
  {
    name: 'Marathon Runner',
    description: 'Complete 15 deliveries today',
    period: 'daily',
    targetCount: 15,
    rewardAmount: 18.0,
    minLevel: 'L4',
    sortOrder: 5,
  },

  // ── Weekly Quests ──
  {
    name: 'Weekday Warrior',
    description: 'Complete 20 deliveries this week',
    period: 'weekly',
    targetCount: 20,
    rewardAmount: 15.0,
    minLevel: 'L1',
    sortOrder: 10,
  },
  {
    name: 'Consistent Performer',
    description: 'Complete 35 deliveries this week',
    period: 'weekly',
    targetCount: 35,
    rewardAmount: 25.0,
    minLevel: 'L1',
    sortOrder: 11,
  },
  {
    name: 'Silver Hustle',
    description: 'Complete 50 deliveries this week',
    period: 'weekly',
    targetCount: 50,
    rewardAmount: 40.0,
    minLevel: 'L2',
    sortOrder: 12,
  },
  {
    name: 'Gold Rush',
    description: 'Complete 70 deliveries this week',
    period: 'weekly',
    targetCount: 70,
    rewardAmount: 60.0,
    minLevel: 'L3',
    sortOrder: 13,
  },
  {
    name: 'Diamond Drive',
    description: 'Complete 100 deliveries this week',
    period: 'weekly',
    targetCount: 100,
    rewardAmount: 100.0,
    minLevel: 'L4',
    sortOrder: 14,
  },
  {
    name: 'Weekend Warrior',
    description: 'Complete 15 deliveries on Saturday & Sunday combined',
    period: 'weekly',
    targetCount: 15,
    rewardAmount: 20.0,
    minLevel: 'L1',
    sortOrder: 15,
  },
];

// ────────────────────────────────────────────────────────────────────
// Milestone Definitions
// ────────────────────────────────────────────────────────────────────
// Lifetime delivery milestones — each is a one-time badge + reward.
// targetCount: cumulative lifetime deliveries required

const MILESTONES = [
  {
    name: 'First Steps',
    description: 'Complete your first 10 deliveries',
    targetCount: 10,
    rewardAmount: 5.0,
    badgeIcon: 'badge_first_steps',
    sortOrder: 1,
  },
  {
    name: 'Getting Started',
    description: 'Complete 25 lifetime deliveries',
    targetCount: 25,
    rewardAmount: 10.0,
    badgeIcon: 'badge_getting_started',
    sortOrder: 2,
  },
  {
    name: 'Half Century',
    description: 'Complete 50 lifetime deliveries',
    targetCount: 50,
    rewardAmount: 15.0,
    badgeIcon: 'badge_half_century',
    sortOrder: 3,
  },
  {
    name: 'Century Rider',
    description: 'Complete 100 lifetime deliveries',
    targetCount: 100,
    rewardAmount: 25.0,
    badgeIcon: 'badge_century',
    sortOrder: 4,
  },
  {
    name: 'Road Veteran',
    description: 'Complete 250 lifetime deliveries',
    targetCount: 250,
    rewardAmount: 50.0,
    badgeIcon: 'badge_veteran',
    sortOrder: 5,
  },
  {
    name: 'Half K Hero',
    description: 'Complete 500 lifetime deliveries',
    targetCount: 500,
    rewardAmount: 80.0,
    badgeIcon: 'badge_half_k',
    sortOrder: 6,
  },
  {
    name: 'Thousand Club',
    description: 'Complete 1,000 lifetime deliveries',
    targetCount: 1000,
    rewardAmount: 150.0,
    badgeIcon: 'badge_thousand',
    sortOrder: 7,
  },
  {
    name: 'Elite Rider',
    description: 'Complete 2,500 lifetime deliveries',
    targetCount: 2500,
    rewardAmount: 300.0,
    badgeIcon: 'badge_elite',
    sortOrder: 8,
  },
  {
    name: 'Legend of the Road',
    description: 'Complete 5,000 lifetime deliveries',
    targetCount: 5000,
    rewardAmount: 500.0,
    badgeIcon: 'badge_legend',
    sortOrder: 9,
  },
  {
    name: 'GrabGo Immortal',
    description: 'Complete 10,000 lifetime deliveries',
    targetCount: 10000,
    rewardAmount: 1000.0,
    badgeIcon: 'badge_immortal',
    sortOrder: 10,
  },
];

// ────────────────────────────────────────────────────────────────────
// Seed runner
// ────────────────────────────────────────────────────────────────────

const seed = async () => {
  console.log('\n🌱 Seeding Quest & Milestone definitions...\n');

  // ── Quests ──
  let questCreated = 0;
  let questUpdated = 0;

  for (const q of QUESTS) {
    // Use name + period as the natural key for upsert
    const existing = await prisma.questDefinition.findFirst({
      where: { name: q.name, period: q.period },
    });

    if (existing) {
      await prisma.questDefinition.update({
        where: { id: existing.id },
        data: {
          description: q.description,
          targetCount: q.targetCount,
          rewardAmount: q.rewardAmount,
          minLevel: q.minLevel,
          sortOrder: q.sortOrder,
          isActive: true,
        },
      });
      questUpdated++;
      console.log(`  ↻ Quest updated: "${q.name}" (${q.period})`);
    } else {
      await prisma.questDefinition.create({ data: q });
      questCreated++;
      console.log(`  ✚ Quest created: "${q.name}" (${q.period}, ${q.targetCount} target, GHS ${q.rewardAmount})`);
    }
  }

  // ── Milestones ──
  let msCreated = 0;
  let msUpdated = 0;

  for (const m of MILESTONES) {
    const existing = await prisma.milestoneDefinition.findFirst({
      where: { name: m.name },
    });

    if (existing) {
      await prisma.milestoneDefinition.update({
        where: { id: existing.id },
        data: {
          description: m.description,
          targetCount: m.targetCount,
          rewardAmount: m.rewardAmount,
          badgeIcon: m.badgeIcon,
          sortOrder: m.sortOrder,
          isActive: true,
        },
      });
      msUpdated++;
      console.log(`  ↻ Milestone updated: "${m.name}" (${m.targetCount} deliveries)`);
    } else {
      await prisma.milestoneDefinition.create({ data: m });
      msCreated++;
      console.log(`  ✚ Milestone created: "${m.name}" (${m.targetCount} deliveries, GHS ${m.rewardAmount})`);
    }
  }

  console.log('\n── Summary ──');
  console.log(`  Quests:     ${questCreated} created, ${questUpdated} updated (${QUESTS.length} total)`);
  console.log(`  Milestones: ${msCreated} created, ${msUpdated} updated (${MILESTONES.length} total)`);
  console.log('\n✅ Seed complete!\n');
};

seed()
  .catch((err) => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
