# GrabGo Rider Partner & Incentive System

> Complete technical reference for the rider partner level, incentive engines, budget management, and payout system.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture & Data Flow](#2-architecture--data-flow)
3. [Partner Score Engine](#3-partner-score-engine)
4. [Partner Levels & Perks](#4-partner-levels--perks)
5. [Incentive Engines](#5-incentive-engines)
   - [Quest Engine](#51-quest-engine)
   - [Streak Engine](#52-streak-engine)
   - [Milestone Engine](#53-milestone-engine)
   - [Peak-Hour Bonus Engine](#54-peak-hour-bonus-engine)
6. [Incentive Orchestrator](#6-incentive-orchestrator)
7. [Budget Window System](#7-budget-window-system)
8. [Wallet, Withdrawal & Payout](#8-wallet-withdrawal--payout)
9. [Notifications](#9-notifications)
10. [Feature Flags](#10-feature-flags)
11. [Scheduled Jobs](#11-scheduled-jobs)
12. [API Endpoints](#12-api-endpoints)
13. [Database Schema](#13-database-schema)
14. [File Map](#14-file-map)
15. [Going Live Checklist](#15-going-live-checklist)

---

## 1. System Overview

The Rider Partner & Incentive System rewards delivery riders based on performance quality and delivery volume. It is designed to:

- **Retain top riders** by offering tiered perks (higher earnings multiplier, priority dispatch, lower withdrawal fees)
- **Motivate consistency** through daily/weekly quests, delivery streaks, and lifetime milestones
- **Drive supply during peak hours** with time-based bonus rates
- **Control costs** through a 3-tier budget cap system (daily/weekly/monthly)
- **Be fair** — no pay cuts, only additive bonuses on top of base delivery earnings

### Key Design Principles

| Principle             | Implementation                                                         |
| --------------------- | ---------------------------------------------------------------------- |
| **No pay reduction**  | Levels only add bonuses — L1 riders earn the same base rate as before  |
| **Hysteresis**        | 14-day upgrade lock + 7 consecutive days below threshold for downgrade |
| **Bayesian fairness** | New riders aren't penalized for few ratings — smoothed toward 4.0      |
| **Budget safety**     | All incentives sit in `pending_budget` until approved within caps      |
| **Idempotent**        | Ledger entries use unique `sourceRef` — safe to re-process deliveries  |
| **Feature-flagged**   | Entire system behind flags — zero risk to existing flows               |

### Currency & Timezone

- **Currency**: GHS (Ghana Cedis)
- **Timezone**: Africa/Accra (UTC+0, no DST)
- All window keys, streak resets, and cron schedules use UTC

---

## 2. Architecture & Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                     Delivery Completed                          │
│              (delivery_settlement_service.js)                   │
└──────────┬───────────────────────────────────────────────────────┘
           │ non-blocking side-effect
           ▼
┌──────────────────────────────────────────────────────────────────┐
│              INCENTIVE ORCHESTRATOR                              │
│           (rider_incentive_orchestrator.js)                      │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────────┐   │
│  │  Quest   │  │  Streak  │  │ Milestone │  │  Peak-Hour   │   │
│  │  Engine  │  │  Engine  │  │  Engine   │  │   Engine     │   │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘  └──────┬───────┘   │
│       │              │              │               │            │
│       └──────────────┴──────────────┴───────────────┘            │
│                              │                                   │
│                    writeLedgerEntry()                             │
│              status = "pending_budget"                            │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│              BUDGET APPROVAL JOB (every 5 min)                   │
│           (incentive_budget_approval.js)                          │
│                                                                  │
│  Checks daily/weekly/monthly caps → moves to "available"         │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│              WEEKLY PAYOUT JOB (Monday 06:00 UTC)                │
│           (rider_weekly_payout.js)                                │
│                                                                  │
│  Settles "available" entries → credits Wallet → "paid_out"       │
└──────────────────────────────────────────────────────────────────┘
```

### Data Stores

| Store                   | Models                                                                                                                                                                                                                        | Purpose                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **PostgreSQL (Prisma)** | RiderPartnerProfile, RiderLevelHistory, QuestDefinition, QuestProgress, RiderStreak, MilestoneDefinition, MilestoneProgress, RiderIncentiveLedger, IncentiveBudgetWindow, RiderPayoutRequest, User, Wallet, WalletTransaction | Core partner data, incentive ledger, budget               |
| **MongoDB (Mongoose)**  | DeliveryAnalytics, OrderReservation, Notification, RiderStatus                                                                                                                                                                | Performance metrics, dispatch reservations, notifications |
| **Redis**               | Distributed locks                                                                                                                                                                                                             | Cron job locking for multi-instance safety                |

---

## 3. Partner Score Engine

**File**: `services/rider_score_engine.js`

### Score Formula

The partner score is a **weighted composite** of 5 performance metrics, computed over a **28-day rolling window**:

| Metric              | Weight | Data Source                 | Scoring                                              |
| ------------------- | ------ | --------------------------- | ---------------------------------------------------- |
| **On-Time Rate**    | 35%    | DeliveryAnalytics (MongoDB) | Raw percentage (0-100)                               |
| **Completion Rate** | 25%    | DeliveryAnalytics (MongoDB) | Raw percentage (0-100)                               |
| **Customer Rating** | 20%    | Rider table (Prisma)        | Bayesian-smoothed, mapped 1-5 → 0-100                |
| **Delivery Volume** | 15%    | DeliveryAnalytics (MongoDB) | Normalized: `deliveries / 150 × 100` (capped at 100) |
| **Acceptance Rate** | 5%     | OrderReservation (MongoDB)  | `accepted / (accepted + declined + expired) × 100`   |

```
partnerScore = round(
  onTimeRate × 0.35 +
  completionRate × 0.25 +
  ratingScore × 0.20 +
  volumeScore × 0.15 +
  acceptanceRate × 0.05
)
```

### Bayesian Rating Smoothing

New riders with few ratings aren't penalized. The system assumes a global prior of **4.0 stars** with a confidence weight of **10 ratings**:

```
smoothedRating = (4.0 × 10 + actualAvg × ratingCount) / (10 + ratingCount)
```

- A rider with 0 ratings gets 4.0 (neutral)
- A rider with 3 ratings of 5.0 gets ~4.15 (pulled down slightly)
- A rider with 100 ratings converges to their actual average

### Acceptance Rate

Computed from `OrderReservation` outcomes (both order and parcel types):

- **Low-sample fallback**: If fewer than 5 reservations in the window, returns a neutral 100%
- **Excludes cancelled** reservations (not the rider's action)
- Formula: `accepted / (accepted + declined + expired) × 100`

### Volume Normalization

A benchmark of **150 deliveries** in 28 days (≈5.3/day) scores 100. Beyond that is capped at 100. Below scores proportionally.

---

## 4. Partner Levels & Perks

### Level Thresholds

| Level  | Name        | Score Range | Multiplier | Dispatch Bonus |
| ------ | ----------- | ----------- | ---------- | -------------- |
| **L1** | New Partner | 0 – 39      | 1.0×       | +0             |
| **L2** | Bronze      | 40 – 59     | 1.1×       | +3             |
| **L3** | Silver      | 60 – 74     | 1.2×       | +6             |
| **L4** | Gold        | 75 – 89     | 1.4×       | +9             |
| **L5** | Platinum    | 90 – 100    | 1.6×       | +12            |

### Minimum Requirements

Beyond the score, riders must meet these thresholds to qualify for higher levels:

| Level | Min Deliveries | Min Rating | Min Completion Rate |
| ----- | -------------- | ---------- | ------------------- |
| L2    | 20             | 3.5 ★      | 70%                 |
| L3    | 50             | 4.0 ★      | 80%                 |
| L4    | 100            | 4.3 ★      | 85%                 |
| L5    | 200            | 4.5 ★      | 90%                 |

L1 has no requirements — every rider starts here.

### Hysteresis (Anti-Yo-Yo Protection)

To prevent constant level changes:

- **Upgrade lock**: After a level-up, the rider's level is locked for **14 days** — no downgrades during this period
- **Downgrade protection**: A rider must score below their current level threshold for **7 consecutive daily evaluations** before being downgraded
- **Single step**: Downgrades happen one level at a time (L4 → L3, never L4 → L1)

### Level Multiplier

The multiplier amplifies all incentive rewards:

- Quest base reward of GHS 5 → L3 rider gets `5 × 1.2 = GHS 6`
- Streak reward of GHS 12 → L5 rider gets `12 × 1.6 = GHS 19.2`

### Dispatch Priority Bonus

Higher-level riders receive a soft priority boost in the dispatch scoring algorithm. This is added to the rider's dispatch score (which also factors distance, availability, etc.):

```
dispatchScore = baseScore + DISPATCH_PRIORITY_BONUS[partnerLevel]
```

The bonus is moderate (max +12) relative to the distance-based scoring, so it's a tiebreaker, not an override.

---

## 5. Incentive Engines

### 5.1 Quest Engine

**File**: `services/rider_quest_engine.js`

Quests are repeating delivery challenges with daily or weekly windows.

#### How It Works

1. **Quest Definitions** are stored in `QuestDefinition` (Prisma) — seeded by `scripts/seed_incentive_definitions.js`
2. When a delivery completes, the orchestrator calls `incrementQuestProgress(riderId, { partnerLevel })`
3. The engine finds all active quests where the rider meets the `minLevel` requirement
4. For each quest, it gets or creates a `QuestProgress` record for the current window
5. Progress count is incremented. If `currentCount >= targetCount`, the quest is marked completed
6. Completed quests return their reward (base × partner level multiplier)

#### Window Keys

| Period | Key Format   | Example      | Resets           |
| ------ | ------------ | ------------ | ---------------- |
| Daily  | `YYYY-MM-DD` | `2026-03-05` | Midnight UTC     |
| Weekly | `YYYY-Www`   | `2026-W10`   | Monday 00:00 UTC |

#### Seeded Quests (11 total)

**Daily Quests:**

| Quest           | Target        | Base Reward | Min Level |
| --------------- | ------------- | ----------- | --------- |
| Quick Starter   | 3 deliveries  | GHS 2       | L1        |
| Daily Grinder   | 5 deliveries  | GHS 5       | L1        |
| Power Hour      | 8 deliveries  | GHS 10      | L2        |
| Daily Champion  | 12 deliveries | GHS 18      | L3        |
| Marathon Runner | 15 deliveries | GHS 25      | L4        |

**Weekly Quests:**

| Quest                | Target        | Base Reward | Min Level |
| -------------------- | ------------- | ----------- | --------- |
| Weekday Warrior      | 20 deliveries | GHS 15      | L1        |
| Consistent Performer | 30 deliveries | GHS 25      | L1        |
| Silver Hustle        | 40 deliveries | GHS 40      | L2        |
| Gold Rush            | 50 deliveries | GHS 60      | L3        |
| Diamond Drive        | 70 deliveries | GHS 100     | L4        |
| Weekend Warrior      | 15 deliveries | GHS 20      | L1        |

All rewards are multiplied by the rider's level multiplier (e.g., L3 rider completing "Daily Grinder" gets `5 × 1.2 = GHS 6`).

### 5.2 Streak Engine

**File**: `services/rider_streak_engine.js`

Tracks consecutive calendar days with at least 1 delivery.

#### How It Works

1. After a delivery, `processDeliveryForStreak(riderId, { partnerLevel })` is called
2. The engine loads the rider's `RiderStreak` record
3. Compares the current date against `lastActiveDate`:
   - **Same day**: No change (already counted today)
   - **Consecutive**: Increment `currentStreak` by 1
   - **Broken** (gap > 1 day): Reset `currentStreak` to 1
4. Checks if the new streak count crosses any reward thresholds
5. Awards any newly-reached rewards (each threshold is awarded only once per streak)

#### Reward Thresholds

| Consecutive Days | Base Reward | Final (L1) | Final (L5) |
| ---------------- | ----------- | ---------- | ---------- |
| 5                | GHS 5.00    | GHS 5.00   | GHS 8.00   |
| 10               | GHS 12.00   | GHS 12.00  | GHS 19.20  |
| 15               | GHS 25.00   | GHS 25.00  | GHS 40.00  |
| 20               | GHS 40.00   | GHS 40.00  | GHS 64.00  |
| 30               | GHS 75.00   | GHS 75.00  | GHS 120.00 |

#### Streak Continuity Logic

```
Yesterday's date → Today's date = "consecutive" → streak++
Same date twice  → "same_day"    → no change
2+ day gap       → "broken"      → streak = 1
```

Uses UTC dates for calendar day comparison. Handles month/year/leap-year boundaries correctly.

### 5.3 Milestone Engine

**File**: `services/rider_milestone_engine.js`

Lifetime delivery milestone badges with one-time rewards.

#### How It Works

1. After a delivery, `incrementMilestoneProgress(riderId, { partnerLevel })` is called
2. The engine loads all `MilestoneDefinition` records
3. For each milestone, gets or creates a `MilestoneProgress` record
4. Increments the `currentCount` and checks if `currentCount >= targetCount`
5. Newly completed milestones return their reward (base × multiplier)

#### Seeded Milestones (10 total)

| Milestone          | Deliveries | Base Reward | Badge |
| ------------------ | ---------- | ----------- | ----- |
| First Steps        | 10         | GHS 5       | 🚀    |
| Getting Started    | 25         | GHS 10      | 🌟    |
| Half Century       | 50         | GHS 20      | ⭐    |
| Century Rider      | 100        | GHS 40      | 💯    |
| Road Veteran       | 250        | GHS 75      | 🏆    |
| Half K Hero        | 500        | GHS 125     | 🦸    |
| Thousand Club      | 1,000      | GHS 200     | 🎖️    |
| Elite Rider        | 2,500      | GHS 350     | 👑    |
| Legend of the Road | 5,000      | GHS 500     | 🏅    |
| GrabGo Immortal    | 10,000     | GHS 1,000   | 🌍    |

Milestones are **one-time awards** — once a rider reaches 100 deliveries, the Century Rider badge is permanent. A rider doing their 10,000th delivery earns GHS 1,000 × their level multiplier.

### 5.4 Peak-Hour Bonus Engine

**File**: `services/rider_peak_hour_service.js`

Time-based bonus on delivery earnings during high-demand periods.

#### How It Works

1. After a delivery, `processPeakHourBonus({ riderId, orderId, deliveryEarnings, partnerLevel })` is called
2. The engine checks if the current time falls within any active peak window
3. If yes, calculates the bonus: `deliveryEarnings × bonusRate × levelMultiplier`
4. Writes the bonus to the incentive ledger
5. Minimum qualifying earnings: GHS 1.00 (prevents micro-bonuses)

#### Peak Windows (Ghana Market Defaults)

| Window               | Time          | Days      | Bonus |
| -------------------- | ------------- | --------- | ----- |
| 🌅 Morning Rush      | 06:30 – 09:00 | Mon–Fri   | +15%  |
| 🍽️ Lunch Rush        | 11:30 – 14:00 | Every day | +20%  |
| 🌙 Dinner Rush       | 18:00 – 21:00 | Every day | +25%  |
| ☀️ Weekend Afternoon | 14:00 – 17:00 | Sat–Sun   | +10%  |

#### Configuration

Peak windows can be overridden via the `PEAK_HOUR_CONFIG` environment variable (JSON string). Invalid JSON falls back to defaults gracefully.

#### Example Calculation

A rider earns GHS 15 base for a delivery at 12:30 (Lunch Rush, +20%):

- L1: `15 × 0.20 × 1.0 = GHS 3.00` bonus
- L3: `15 × 0.20 × 1.2 = GHS 3.60` bonus
- L5: `15 × 0.20 × 1.6 = GHS 4.80` bonus

---

## 6. Incentive Orchestrator

**File**: `services/rider_incentive_orchestrator.js`

The orchestrator is the **single entry-point** for all incentive processing. It's called as a non-blocking side-effect from `delivery_settlement_service.js` after every delivery completion.

### Flow

```
processDeliveryIncentives({ riderId, orderId, deliveryEarnings })
  │
  ├── 1. Get rider's partnerLevel
  │
  ├── 2. Quest Engine → incrementQuestProgress()
  │      → completed quests → writeLedgerEntry(sourceType='quest')
  │
  ├── 3. Streak Engine → processDeliveryForStreak()
  │      → streak rewards → writeLedgerEntry(sourceType='streak')
  │
  ├── 4. Milestone Engine → incrementMilestoneProgress()
  │      → completed milestones → writeLedgerEntry(sourceType='milestone')
  │
  ├── 5. Peak-Hour Engine → processPeakHourBonus()
  │      → peak bonus → writeLedgerEntry(sourceType='peak_hour')
  │
  ├── 6. Send notifications (non-blocking)
  │
  └── Return summary { quests, streakRewards, milestones, peakBonuses, totalEarned }
```

### Idempotency

Each ledger entry has a unique `sourceRef` built from:

```
sourceType:entityId:windowKey
```

Examples:

- `quest:quest_daily_5:2026-03-05`
- `streak:streak-10:2026-W10`
- `milestone:ms_100:2026-03-05`
- `peak_hour:lunch_rush:order_abc123:2026-03-05`

If the same delivery triggers the same incentive twice (e.g., retry), the unique constraint on `(sourceType, sourceRef)` prevents duplicate entries (Prisma error P2002 is silently caught).

### Error Isolation

Each engine is wrapped in try/catch. If the streak engine fails, quests and milestones still process. Errors are logged but never block the delivery settlement flow.

---

## 7. Budget Window System

**File**: `services/rider_budget_service.js`

### Purpose

Prevents runaway incentive costs by enforcing caps at three time granularities.

### Default Caps

| Window      | Default Cap | Env Override         |
| ----------- | ----------- | -------------------- |
| **Daily**   | GHS 5,000   | `BUDGET_CAP_DAILY`   |
| **Weekly**  | GHS 25,000  | `BUDGET_CAP_WEEKLY`  |
| **Monthly** | GHS 80,000  | `BUDGET_CAP_MONTHLY` |

### How It Works

1. **All incentive entries** are created with status `pending_budget`
2. The **Budget Approval Job** runs every 5 minutes
3. For each pending entry, it checks the current daily, weekly, and monthly caps
4. If all three budgets have room, the entry is moved to `available` status
5. If any budget is exhausted, the entry stays `pending_budget` until the next window
6. Entries can also be manually expired if windows close

### Lifecycle of an Incentive Entry

```
pending_budget  →  available  →  paid_out
                      ↓
                   expired (if window closes before approval)
```

### Admin Controls

Admins can:

- **View** the budget utilization dashboard (spend vs cap per window)
- **Update** cap amounts for any window
- **Trigger** manual approval cycles

---

## 8. Wallet, Withdrawal & Payout

**File**: `services/rider_payout_service.js`

### Withdrawal Fee Policy by Level

| Level  | Free Instant Withdrawals/Week | Fee (After Free) | Weekly Auto-Payout |
| ------ | ----------------------------- | ---------------- | ------------------ |
| **L1** | 0                             | GHS 2.00         | ❌                 |
| **L2** | 1                             | GHS 2.00         | ✅                 |
| **L3** | 3                             | GHS 1.50         | ✅                 |
| **L4** | 5                             | GHS 1.00         | ✅                 |
| **L5** | Unlimited                     | Free             | ✅                 |

**Minimum withdrawal**: GHS 5.00

### How Withdrawals Work

1. Rider calls `POST /api/riders/withdraw` with amount, method, and account details
2. The withdrawal guard middleware checks basic eligibility
3. If `RIDER_INCENTIVES_ENABLED`:
   - System looks up the rider's partner level
   - Counts how many free instant withdrawals they've used this week
   - Calculates the fee (GHS 0 if free quota remains, otherwise the level's instant fee)
   - Creates a `RiderPayoutRequest` record
4. Fee is deducted from the withdrawal amount
5. Wallet balance is updated, transaction is created

### Weekly Auto-Payout

**Job**: `jobs/rider_weekly_payout.js` — runs **Monday 06:00 UTC**

For riders at L2+ (weekly auto enabled):

1. Finds all `available` incentive ledger entries not yet paid out
2. Sums the amounts per rider
3. Credits each rider's wallet
4. Updates entries to `paid_out` status
5. Creates wallet transactions with type `incentive_payout`

---

## 9. Notifications

**File**: `services/rider_incentive_notifications.js`

Six notification types are sent via the existing `createNotification` + Socket.IO pattern:

| Event             | Type                   | Example Message                                                |
| ----------------- | ---------------------- | -------------------------------------------------------------- |
| Level change      | `partner_level_change` | "🥇 Congrats! You've been promoted to Gold (L3)!"              |
| Quest completed   | `quest_completed`      | "🎯 Quest Complete: Daily Grinder — you earned GHS 6.00!"      |
| Streak reward     | `streak_reward`        | "🔥 10-day streak! You earned GHS 14.40!"                      |
| Milestone reached | `delivery_milestone`   | "🏆 Road Veteran: 250 deliveries! Badge unlocked + GHS 90.00!" |
| Peak-hour bonus   | `peak_hour_bonus`      | "⚡ Peak bonus: Lunch Rush +20% — GHS 3.60 earned!"            |
| Incentive payout  | `incentive_payout`     | "💰 GHS 45.00 incentive payout added to your wallet!"          |

All notifications are **non-blocking** — they are fired as fire-and-forget calls within the incentive engines. A notification failure never blocks the incentive logic.

### Level Labels in Notifications

| Level | Label    | Emoji |
| ----- | -------- | ----- |
| L1    | Bronze   | 🥉    |
| L2    | Silver   | 🥈    |
| L3    | Gold     | 🥇    |
| L4    | Platinum | 💎    |
| L5    | Diamond  | 👑    |

---

## 10. Feature Flags

**File**: `config/feature_flags.js`

| Flag                              | Env Variable                       | Default | Purpose                                                                |
| --------------------------------- | ---------------------------------- | ------- | ---------------------------------------------------------------------- |
| `isRiderPartnerSystemEnabled`     | `RIDER_PARTNER_SYSTEM_ENABLED`     | `false` | Gates all partner profile endpoints                                    |
| `isRiderPartnerShadowMode`        | `RIDER_PARTNER_SHADOW_MODE`        | `true`  | When true, partner endpoints work even if main flag is off (read-only) |
| `isRiderIncentivesEnabled`        | `RIDER_INCENTIVES_ENABLED`         | `false` | Gates all incentive engines, quests, streaks, milestones, peak hours   |
| `isRiderDeliveryAnalyticsEnabled` | `RIDER_DELIVERY_ANALYTICS_ENABLED` | `true`  | Enables delivery analytics data collection                             |
| `isRiderMetricsSyncEnabled`       | `RIDER_METRICS_SYNC_ENABLED`       | `true`  | Enables metrics sync from MongoDB to Prisma                            |
| `isRiderWithdrawalGuardEnabled`   | `RIDER_WITHDRAWAL_GUARD_ENABLED`   | `true`  | Enables withdrawal validation middleware                               |

### Shadow Mode

Shadow mode allows you to:

1. Turn on `RIDER_PARTNER_SHADOW_MODE=true` (default)
2. Keep `RIDER_PARTNER_SYSTEM_ENABLED=false`
3. The dashboard endpoints will still work — riders can see their score and level
4. But the system won't affect dispatch or trigger level changes in production

This lets you test the partner UI in production without any side-effects.

### Enabling the System

**Step 1 — Shadow mode** (monitoring only):

```env
RIDER_PARTNER_SYSTEM_ENABLED=false
RIDER_PARTNER_SHADOW_MODE=true
RIDER_DELIVERY_ANALYTICS_ENABLED=true
RIDER_METRICS_SYNC_ENABLED=true
```

**Step 2 — Full partner system** (levels affect dispatch):

```env
RIDER_PARTNER_SYSTEM_ENABLED=true
RIDER_PARTNER_SHADOW_MODE=false
```

**Step 3 — Enable incentives** (quests, streaks, milestones, peak bonuses, budget):

```env
RIDER_INCENTIVES_ENABLED=true
```

---

## 11. Scheduled Jobs

All jobs use distributed Redis locks for multi-instance safety. If a lock can't be acquired, the job skips that cycle.

| Job                    | File                                | Schedule                        | What It Does                                                                                                                              |
| ---------------------- | ----------------------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Daily Level Recalc** | `jobs/rider_partner_recalc.js`      | Every day at 02:00 Africa/Accra | Recalculates partner score and level for all riders (batch size 50). Applies hysteresis rules. Logs level changes to `RiderLevelHistory`. |
| **Budget Approval**    | `jobs/incentive_budget_approval.js` | Every 5 minutes                 | Moves `pending_budget` ledger entries to `available` if within daily/weekly/monthly caps. Closes expired windows.                         |
| **Weekly Payout**      | `jobs/rider_weekly_payout.js`       | Monday 06:00 UTC                | For L2+ riders: settles `available` incentive entries into wallet. Creates wallet transactions. Updates entries to `paid_out`.            |

### Registration

All three jobs are registered in `server.js` behind their respective feature flags:

```javascript
// server.js
if (featureFlags.isRiderPartnerSystemEnabled) {
  require("./jobs/rider_partner_recalc");
}
if (featureFlags.isRiderIncentivesEnabled) {
  require("./jobs/incentive_budget_approval");
  require("./jobs/rider_weekly_payout");
}
```

---

## 12. API Endpoints

All endpoints are under `/api/riders/` and require JWT authentication.

### Partner Profile (5 endpoints)

| Method | Path                                  | Role         | Description                                                    |
| ------ | ------------------------------------- | ------------ | -------------------------------------------------------------- |
| GET    | `/partner-profile/dashboard`          | rider        | Full partner dashboard (level, score, metrics, perks, history) |
| GET    | `/partner-profile/score-breakdown`    | rider, admin | Detailed 5-metric score components                             |
| GET    | `/partner-profile/level-history`      | rider, admin | Level change history with timestamps                           |
| POST   | `/partner-profile/recalculate`        | admin        | Force-recalculate a rider's level                              |
| GET    | `/partner-profile/level-distribution` | admin        | Distribution of riders across levels                           |

### Incentives (7 endpoints)

| Method | Path                         | Role  | Description                              |
| ------ | ---------------------------- | ----- | ---------------------------------------- |
| GET    | `/quests`                    | rider | Active daily/weekly quests with progress |
| GET    | `/streaks`                   | rider | Streak count, rewards, thresholds        |
| GET    | `/milestones`                | rider | Milestone badges, progress, completion   |
| GET    | `/incentives`                | rider | Incentive ledger summary for a period    |
| GET    | `/incentives/admin/:riderId` | admin | View any rider's incentive ledger        |
| GET    | `/peak-hours/status`         | rider | Current peak-hour status and bonus rate  |
| GET    | `/peak-hours/schedule`       | rider | Full weekly peak-hour schedule           |

### Budget Admin (3 endpoints)

| Method | Path                      | Role  | Description                       |
| ------ | ------------------------- | ----- | --------------------------------- |
| GET    | `/budget/admin/dashboard` | admin | Budget utilization (spend vs cap) |
| PUT    | `/budget/admin/cap`       | admin | Update a budget window cap        |
| POST   | `/budget/admin/approve`   | admin | Trigger manual approval cycle     |

### Wallet & Payout (4 endpoints)

| Method | Path                        | Role  | Description                                        |
| ------ | --------------------------- | ----- | -------------------------------------------------- |
| GET    | `/wallet/withdrawal-policy` | rider | Withdrawal fee policy for rider's level            |
| GET    | `/wallet/payout-history`    | rider | Recent payout requests                             |
| GET    | `/wallet/incentive-balance` | rider | Pending + available incentive balance              |
| POST   | `/withdraw`                 | rider | Submit withdrawal (enhanced with level-based fees) |

**Total: 19 endpoints** (18 new + 1 enhanced)

---

## 13. Database Schema

### Prisma Models (PostgreSQL)

| Model                   | Purpose                                                                      |
| ----------------------- | ---------------------------------------------------------------------------- |
| `RiderPartnerProfile`   | Stores current level, score, evaluation timestamps, lock state               |
| `RiderLevelHistory`     | Audit log of all level changes with reason and score                         |
| `QuestDefinition`       | Quest templates (name, period, target, reward, minLevel, active flag)        |
| `QuestProgress`         | Per-rider, per-quest, per-window progress tracking                           |
| `RiderStreak`           | Per-rider streak state (currentStreak, longestStreak, lastActiveDate)        |
| `MilestoneDefinition`   | Milestone templates (name, target, reward, badge)                            |
| `MilestoneProgress`     | Per-rider, per-milestone progress tracking                                   |
| `RiderIncentiveLedger`  | All incentive entries with status lifecycle (pending → available → paid_out) |
| `IncentiveBudgetWindow` | Budget caps and spend tracking per window type/key                           |
| `RiderPayoutRequest`    | Withdrawal/payout request records                                            |

### Prisma Enums

| Enum                  | Values                                                             |
| --------------------- | ------------------------------------------------------------------ |
| `PartnerLevel`        | L1, L2, L3, L4, L5                                                 |
| `LevelChangeReason`   | score_upgrade, score_downgrade, admin_override, initial_assignment |
| `QuestPeriod`         | daily, weekly                                                      |
| `QuestProgressStatus` | active, completed, expired                                         |
| `IncentiveSourceType` | quest, streak, milestone, peak_hour                                |
| `IncentiveStatus`     | pending_budget, available, paid_out, expired                       |
| `BudgetWindowType`    | daily, weekly, monthly                                             |
| `BudgetWindowStatus`  | active, exhausted, closed                                          |
| `PayoutStatus`        | pending, processing, completed, failed                             |

### Mongoose Models (MongoDB)

| Model          | New Fields/Types                                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `Notification` | 6 new types: `partner_level_change`, `quest_completed`, `streak_reward`, `delivery_milestone`, `incentive_payout`, `peak_hour_bonus` |

---

## 14. File Map

```
backend/
├── config/
│   └── feature_flags.js          ← 6 partner/incentive flags
│
├── services/
│   ├── rider_score_engine.js      ← Score formula, levels, Bayesian rating, hysteresis
│   ├── rider_partner_service.js   ← Dashboard, breakdown, recalculation, history
│   ├── rider_quest_engine.js      ← Quest progress tracking, window keys
│   ├── rider_streak_engine.js     ← Consecutive-day streaks, rewards
│   ├── rider_milestone_engine.js  ← Lifetime milestone badges
│   ├── rider_peak_hour_service.js ← Peak-hour bonus calculation
│   ├── rider_incentive_orchestrator.js ← Single entry-point, ledger writes
│   ├── rider_budget_service.js    ← Budget cap management
│   ├── rider_payout_service.js    ← Withdrawal policy, weekly payout
│   ├── rider_incentive_notifications.js ← 6 notification triggers
│   ├── dispatch_service.js        ← Modified: partner-level dispatch bonus
│   └── delivery_settlement_service.js ← Modified: calls orchestrator
│
├── jobs/
│   ├── rider_partner_recalc.js    ← Daily 02:00 level recalculation
│   ├── incentive_budget_approval.js ← Every 5 min budget approval
│   └── rider_weekly_payout.js     ← Monday 06:00 wallet settlement
│
├── routes/
│   └── riders.js                  ← 19 new/enhanced endpoints
│
├── middleware/
│   └── withdrawal_guard.js        ← Modified: respects feature flag
│
├── models/
│   └── Notification.js            ← Modified: 6 new notification types
│
├── prisma/
│   └── schema.prisma              ← 13 models, 9 enums
│
├── scripts/
│   └── seed_incentive_definitions.js ← Seeds 11 quests + 10 milestones
│
├── tests/
│   ├── rider_score_engine.test.js           ← 38 tests
│   ├── rider_quest_engine.test.js           ← 14 tests
│   ├── rider_streak_engine.test.js          ← 15 tests
│   ├── rider_peak_hour_service.test.js      ← 18 tests
│   └── rider_incentive_services.test.js     ← 28 tests (orchestrator, budget, payout, notifications)
│
├── docs/
│   ├── openapi.yaml               ← 19 endpoints documented, 10 schemas
│   └── RIDER_PARTNER_INCENTIVE_SYSTEM.md ← This file
│
└── server.js                      ← Modified: registers 3 cron jobs
```

---

## 15. Going Live Checklist

### Phase 1 — Shadow Mode (Week 1)

- [ ] Deploy all code to production
- [ ] Set `RIDER_PARTNER_SHADOW_MODE=true`
- [ ] Run `node scripts/seed_incentive_definitions.js` in production
- [ ] Run `npx prisma db push` to sync schema
- [ ] Monitor logs for any errors
- [ ] Verify partner dashboard works for a test rider

### Phase 2 — Enable Partner System (Week 2)

- [ ] Set `RIDER_PARTNER_SYSTEM_ENABLED=true`
- [ ] Verify daily recalc job runs at 02:00
- [ ] Check `RiderLevelHistory` records are being created
- [ ] Verify dispatch priority bonus is being applied
- [ ] Monitor level distribution via admin endpoint

### Phase 3 — Enable Incentives (Week 3)

- [ ] Set `RIDER_INCENTIVES_ENABLED=true`
- [ ] Verify quest progress updates after deliveries
- [ ] Verify streak tracking works across days
- [ ] Verify peak-hour bonuses during peak windows
- [ ] Confirm budget approval job is running (every 5 min)
- [ ] Confirm weekly payout job runs on Monday 06:00
- [ ] Monitor budget utilization via admin dashboard
- [ ] Adjust budget caps if needed via `PUT /budget/admin/cap`

### Phase 4 — Monitor & Tune

- [ ] Review level distribution weekly — adjust thresholds if needed
- [ ] Review budget utilization — adjust caps if needed
- [ ] Review quest completion rates — add/modify quests if too easy/hard
- [ ] Review peak-hour participation — adjust windows/rates if needed
- [ ] Gather rider feedback on the partner dashboard

---

## Quick Reference Card

```
Score = 0.35×OnTime + 0.25×Completion + 0.20×Rating + 0.15×Volume + 0.05×Acceptance

Levels: L1(0-39) → L2(40-59) → L3(60-74) → L4(75-89) → L5(90-100)

Multipliers: L1=1.0× | L2=1.1× | L3=1.2× | L4=1.4× | L5=1.6×

Streak rewards at: 5/10/15/20/30 consecutive days

Withdrawal fees: L1=GHS 2 | L2=GHS 2 (1 free) | L3=GHS 1.5 (3 free) | L4=GHS 1 (5 free) | L5=Free

Budget caps: Daily GHS 5K | Weekly GHS 25K | Monthly GHS 80K

Feature flags: RIDER_PARTNER_SYSTEM_ENABLED + RIDER_INCENTIVES_ENABLED
```
