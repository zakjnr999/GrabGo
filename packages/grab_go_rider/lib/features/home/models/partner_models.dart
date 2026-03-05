enum PartnerLevel { L1, L2, L3, L4, L5 }

PartnerLevel parsePartnerLevel(String? value) {
  switch (value) {
    case 'L2':
      return PartnerLevel.L2;
    case 'L3':
      return PartnerLevel.L3;
    case 'L4':
      return PartnerLevel.L4;
    case 'L5':
      return PartnerLevel.L5;
    default:
      return PartnerLevel.L1;
  }
}

String partnerLevelLabel(PartnerLevel level) {
  switch (level) {
    case PartnerLevel.L1:
      return 'Bronze';
    case PartnerLevel.L2:
      return 'Silver';
    case PartnerLevel.L3:
      return 'Gold';
    case PartnerLevel.L4:
      return 'Platinum';
    case PartnerLevel.L5:
      return 'Diamond';
  }
}

enum QuestPeriod { daily, weekly }

QuestPeriod parseQuestPeriod(String? value) {
  switch (value?.toLowerCase()) {
    case 'weekly':
      return QuestPeriod.weekly;
    default:
      return QuestPeriod.daily;
  }
}

enum QuestStatus { active, completed, expired }

QuestStatus parseQuestStatus(String? value) {
  switch (value?.toLowerCase()) {
    case 'completed':
      return QuestStatus.completed;
    case 'expired':
      return QuestStatus.expired;
    default:
      return QuestStatus.active;
  }
}

enum IncentiveSourceType { quest, streak, milestone, peakHour }

IncentiveSourceType parseIncentiveSourceType(String? value) {
  switch (value?.toLowerCase()) {
    case 'streak':
      return IncentiveSourceType.streak;
    case 'milestone':
      return IncentiveSourceType.milestone;
    case 'peak_hour':
      return IncentiveSourceType.peakHour;
    default:
      return IncentiveSourceType.quest;
  }
}

String incentiveSourceLabel(IncentiveSourceType type) {
  switch (type) {
    case IncentiveSourceType.quest:
      return 'Quest';
    case IncentiveSourceType.streak:
      return 'Streak';
    case IncentiveSourceType.milestone:
      return 'Milestone';
    case IncentiveSourceType.peakHour:
      return 'Peak Hour';
  }
}

enum LedgerStatus { pendingBudget, available, paidOut }

LedgerStatus parseLedgerStatus(String? value) {
  switch (value?.toLowerCase()) {
    case 'available':
      return LedgerStatus.available;
    case 'paid_out':
      return LedgerStatus.paidOut;
    default:
      return LedgerStatus.pendingBudget;
  }
}

String ledgerStatusLabel(LedgerStatus status) {
  switch (status) {
    case LedgerStatus.pendingBudget:
      return 'Pending';
    case LedgerStatus.available:
      return 'Available';
    case LedgerStatus.paidOut:
      return 'Paid Out';
  }
}

enum PayoutType { instant, weeklyAuto }

PayoutType parsePayoutType(String? value) {
  switch (value?.toLowerCase()) {
    case 'weekly_auto':
      return PayoutType.weeklyAuto;
    default:
      return PayoutType.instant;
  }
}

enum PayoutStatus { pending, completed, failed }

PayoutStatus parsePayoutStatus(String? value) {
  switch (value?.toLowerCase()) {
    case 'completed':
      return PayoutStatus.completed;
    case 'failed':
      return PayoutStatus.failed;
    default:
      return PayoutStatus.pending;
  }
}

enum PayoutMethod { bankAccount, mtnMobileMoney, vodafoneCash }

PayoutMethod? parsePayoutMethod(String? value) {
  switch (value?.toLowerCase()) {
    case 'bank_account':
      return PayoutMethod.bankAccount;
    case 'mtn_mobile_money':
      return PayoutMethod.mtnMobileMoney;
    case 'vodafone_cash':
      return PayoutMethod.vodafoneCash;
    default:
      return null;
  }
}

enum LevelChangeReason { scoreUpgrade, scoreDowngrade, initialPlacement, manualAdjustment }

LevelChangeReason parseLevelChangeReason(String? value) {
  switch (value?.toLowerCase()) {
    case 'score_downgrade':
      return LevelChangeReason.scoreDowngrade;
    case 'initial_placement':
      return LevelChangeReason.initialPlacement;
    case 'manual_adjustment':
      return LevelChangeReason.manualAdjustment;
    default:
      return LevelChangeReason.scoreUpgrade;
  }
}

class PartnerDashboard {
  final PartnerProfile profile;
  final LevelInfo level;
  final PartnerMetrics metrics;
  final LiveScore? liveScore;
  final NextLevelTarget? nextLevel;
  final LevelRequirements? currentLevelRequirements;
  final List<LevelHistoryEntry> recentHistory;

  const PartnerDashboard({
    required this.profile,
    required this.level,
    required this.metrics,
    this.liveScore,
    this.nextLevel,
    this.currentLevelRequirements,
    this.recentHistory = const [],
  });

  factory PartnerDashboard.fromJson(Map<String, dynamic> json) {
    return PartnerDashboard(
      profile: PartnerProfile.fromJson(json['profile'] as Map<String, dynamic>? ?? {}),
      level: LevelInfo.fromJson(json['level'] as Map<String, dynamic>? ?? {}),
      metrics: PartnerMetrics.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      liveScore: json['liveScore'] != null ? LiveScore.fromJson(json['liveScore'] as Map<String, dynamic>) : null,
      nextLevel: json['nextLevel'] != null ? NextLevelTarget.fromJson(json['nextLevel'] as Map<String, dynamic>) : null,
      currentLevelRequirements: json['currentLevelRequirements'] != null
          ? LevelRequirements.fromJson(json['currentLevelRequirements'] as Map<String, dynamic>)
          : null,
      recentHistory:
          (json['recentHistory'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(LevelHistoryEntry.fromJson)
              .toList() ??
          [],
    );
  }
}

class PartnerProfile {
  final String riderId;
  final PartnerLevel partnerLevel;
  final int partnerScore;
  final DateTime? lastEvaluatedAt;
  final DateTime? scoreWindowStart;
  final DateTime? scoreWindowEnd;

  const PartnerProfile({
    required this.riderId,
    required this.partnerLevel,
    required this.partnerScore,
    this.lastEvaluatedAt,
    this.scoreWindowStart,
    this.scoreWindowEnd,
  });

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    return PartnerProfile(
      riderId: json['riderId']?.toString() ?? '',
      partnerLevel: parsePartnerLevel(json['partnerLevel']?.toString()),
      partnerScore: _asInt(json['partnerScore']),
      lastEvaluatedAt: _tryParseDate(json['lastEvaluatedAt']),
      scoreWindowStart: _tryParseDate(json['scoreWindowStart']),
      scoreWindowEnd: _tryParseDate(json['scoreWindowEnd']),
    );
  }
}

class LevelInfo {
  final PartnerLevel current;
  final double multiplier;
  final int dispatchBonus;
  final bool isLocked;
  final int lockDaysRemaining;
  final DateTime? levelLockedUntil;

  const LevelInfo({
    required this.current,
    required this.multiplier,
    required this.dispatchBonus,
    this.isLocked = false,
    this.lockDaysRemaining = 0,
    this.levelLockedUntil,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) {
    return LevelInfo(
      current: parsePartnerLevel(json['current']?.toString()),
      multiplier: _asDouble(json['multiplier']),
      dispatchBonus: _asInt(json['dispatchBonus']),
      isLocked: json['isLocked'] == true,
      lockDaysRemaining: _asInt(json['lockDaysRemaining']),
      levelLockedUntil: _tryParseDate(json['levelLockedUntil']),
    );
  }
}

class PartnerMetrics {
  final double onTimeRate;
  final double completionRate;
  final double customerRating;
  final int deliveryVolume;
  final double acceptanceRate;

  const PartnerMetrics({
    required this.onTimeRate,
    required this.completionRate,
    required this.customerRating,
    required this.deliveryVolume,
    required this.acceptanceRate,
  });

  factory PartnerMetrics.fromJson(Map<String, dynamic> json) {
    return PartnerMetrics(
      onTimeRate: _asDouble(json['onTimeRate']),
      completionRate: _asDouble(json['completionRate']),
      customerRating: _asDouble(json['customerRating']),
      deliveryVolume: _asInt(json['deliveryVolume']),
      acceptanceRate: _asDouble(json['acceptanceRate']),
    );
  }
}

class ScoreComponents {
  final double onTimeRate;
  final double completionRate;
  final double customerRating;
  final double ratingScore;
  final int deliveryVolume;
  final double volumeScore;
  final double acceptanceRate;

  const ScoreComponents({
    required this.onTimeRate,
    required this.completionRate,
    required this.customerRating,
    required this.ratingScore,
    required this.deliveryVolume,
    required this.volumeScore,
    required this.acceptanceRate,
  });

  factory ScoreComponents.fromJson(Map<String, dynamic> json) {
    return ScoreComponents(
      onTimeRate: _asDouble(json['onTimeRate']),
      completionRate: _asDouble(json['completionRate']),
      customerRating: _asDouble(json['customerRating']),
      ratingScore: _asDouble(json['ratingScore']),
      deliveryVolume: _asInt(json['deliveryVolume']),
      volumeScore: _asDouble(json['volumeScore']),
      acceptanceRate: _asDouble(json['acceptanceRate']),
    );
  }
}

class LiveScore {
  final int partnerScore;
  final ScoreComponents components;

  const LiveScore({required this.partnerScore, required this.components});

  factory LiveScore.fromJson(Map<String, dynamic> json) {
    return LiveScore(
      partnerScore: _asInt(json['partnerScore']),
      components: ScoreComponents.fromJson(json['components'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class NextLevelTarget {
  final PartnerLevel nextLevel;
  final int scoreRequired;
  final int scoreGap;
  final LevelRequirements? requirements;
  final double multiplier;
  final int dispatchBonus;

  const NextLevelTarget({
    required this.nextLevel,
    required this.scoreRequired,
    required this.scoreGap,
    this.requirements,
    required this.multiplier,
    required this.dispatchBonus,
  });

  factory NextLevelTarget.fromJson(Map<String, dynamic> json) {
    return NextLevelTarget(
      nextLevel: parsePartnerLevel(json['nextLevel']?.toString()),
      scoreRequired: _asInt(json['scoreRequired']),
      scoreGap: _asInt(json['scoreGap']),
      requirements: json['requirements'] != null
          ? LevelRequirements.fromJson(json['requirements'] as Map<String, dynamic>)
          : null,
      multiplier: _asDouble(json['multiplier']),
      dispatchBonus: _asInt(json['dispatchBonus']),
    );
  }
}

class LevelRequirements {
  final int minDeliveries;
  final double minRating;
  final double minCompletionRate;

  const LevelRequirements({required this.minDeliveries, required this.minRating, required this.minCompletionRate});

  factory LevelRequirements.fromJson(Map<String, dynamic> json) {
    return LevelRequirements(
      minDeliveries: _asInt(json['minDeliveries']),
      minRating: _asDouble(json['minRating']),
      minCompletionRate: _asDouble(json['minCompletionRate']),
    );
  }
}

class LevelHistoryEntry {
  final String? id;
  final String riderId;
  final PartnerLevel fromLevel;
  final PartnerLevel toLevel;
  final int score;
  final LevelChangeReason reason;
  final DateTime changedAt;
  final DateTime? lockUntil;

  const LevelHistoryEntry({
    this.id,
    required this.riderId,
    required this.fromLevel,
    required this.toLevel,
    required this.score,
    required this.reason,
    required this.changedAt,
    this.lockUntil,
  });

  factory LevelHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LevelHistoryEntry(
      id: json['id']?.toString(),
      riderId: json['riderId']?.toString() ?? '',
      fromLevel: parsePartnerLevel(json['from']?.toString() ?? json['fromLevel']?.toString()),
      toLevel: parsePartnerLevel(json['to']?.toString() ?? json['toLevel']?.toString()),
      score: _asInt(json['score']),
      reason: parseLevelChangeReason(json['reason']?.toString()),
      changedAt: _tryParseDate(json['changedAt']) ?? DateTime.now(),
      lockUntil: _tryParseDate(json['lockUntil']),
    );
  }
}

class ScoreBreakdown {
  final String riderId;
  final DateTime windowStart;
  final DateTime windowEnd;
  final int windowDays;
  final int partnerScore;
  final PartnerLevel rawLevel;
  final ScoreComponents components;

  const ScoreBreakdown({
    required this.riderId,
    required this.windowStart,
    required this.windowEnd,
    required this.windowDays,
    required this.partnerScore,
    required this.rawLevel,
    required this.components,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      riderId: json['riderId']?.toString() ?? '',
      windowStart: _tryParseDate(json['windowStart']) ?? DateTime.now(),
      windowEnd: _tryParseDate(json['windowEnd']) ?? DateTime.now(),
      windowDays: _asInt(json['windowDays']),
      partnerScore: _asInt(json['partnerScore']),
      rawLevel: parsePartnerLevel(json['rawLevel']?.toString()),
      components: ScoreComponents.fromJson(json['components'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class QuestProgress {
  final String questId;
  final String name;
  final String description;
  final QuestPeriod period;
  final String windowKey;
  final int currentCount;
  final int targetCount;
  final int percentComplete;
  final QuestStatus status;
  final DateTime? completedAt;
  final double baseReward;
  final double multiplier;
  final double finalReward;
  final PartnerLevel minLevel;

  const QuestProgress({
    required this.questId,
    required this.name,
    required this.description,
    required this.period,
    required this.windowKey,
    required this.currentCount,
    required this.targetCount,
    required this.percentComplete,
    required this.status,
    this.completedAt,
    required this.baseReward,
    required this.multiplier,
    required this.finalReward,
    required this.minLevel,
  });

  factory QuestProgress.fromJson(Map<String, dynamic> json) {
    return QuestProgress(
      questId: json['questId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      period: parseQuestPeriod(json['period']?.toString()),
      windowKey: json['windowKey']?.toString() ?? '',
      currentCount: _asInt(json['currentCount']),
      targetCount: _asInt(json['targetCount']),
      percentComplete: _asInt(json['percentComplete']),
      status: parseQuestStatus(json['status']?.toString()),
      completedAt: _tryParseDate(json['completedAt']),
      baseReward: _asDouble(json['baseReward']),
      multiplier: _asDouble(json['multiplier']),
      finalReward: _asDouble(json['finalReward']),
      minLevel: parsePartnerLevel(json['minLevel']?.toString()),
    );
  }
}

class StreakDashboard {
  final int currentStreak;
  final int longestStreak;
  final DateTime? streakStartDate;
  final DateTime? lastDeliveryDate;
  final NextStreakReward? nextReward;
  final List<StreakThreshold> allThresholds;
  final List<StreakRewardEntry> recentRewards;

  const StreakDashboard({
    required this.currentStreak,
    required this.longestStreak,
    this.streakStartDate,
    this.lastDeliveryDate,
    this.nextReward,
    this.allThresholds = const [],
    this.recentRewards = const [],
  });

  factory StreakDashboard.fromJson(Map<String, dynamic> json) {
    return StreakDashboard(
      currentStreak: _asInt(json['currentStreak']),
      longestStreak: _asInt(json['longestStreak']),
      streakStartDate: _tryParseDate(json['streakStartDate']),
      lastDeliveryDate: _tryParseDate(json['lastDeliveryDate']),
      nextReward: json['nextReward'] != null
          ? NextStreakReward.fromJson(json['nextReward'] as Map<String, dynamic>)
          : null,
      allThresholds:
          (json['allThresholds'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(StreakThreshold.fromJson)
              .toList() ??
          [],
      recentRewards:
          (json['recentRewards'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(StreakRewardEntry.fromJson)
              .toList() ??
          [],
    );
  }
}

class NextStreakReward {
  final int daysNeeded;
  final int threshold;
  final String label;
  final double baseReward;
  final double finalReward;

  const NextStreakReward({
    required this.daysNeeded,
    required this.threshold,
    required this.label,
    required this.baseReward,
    required this.finalReward,
  });

  factory NextStreakReward.fromJson(Map<String, dynamic> json) {
    return NextStreakReward(
      daysNeeded: _asInt(json['daysNeeded']),
      threshold: _asInt(json['threshold']),
      label: json['label']?.toString() ?? '',
      baseReward: _asDouble(json['baseReward']),
      finalReward: _asDouble(json['finalReward']),
    );
  }
}

class StreakThreshold {
  final int days;
  final String label;
  final double baseReward;
  final double finalReward;
  final bool achieved;

  const StreakThreshold({
    required this.days,
    required this.label,
    required this.baseReward,
    required this.finalReward,
    required this.achieved,
  });

  factory StreakThreshold.fromJson(Map<String, dynamic> json) {
    return StreakThreshold(
      days: _asInt(json['days']),
      label: json['label']?.toString() ?? '',
      baseReward: _asDouble(json['baseReward']),
      finalReward: _asDouble(json['finalReward']),
      achieved: json['achieved'] == true,
    );
  }
}

class StreakRewardEntry {
  final int streakCount;
  final double rewardAmount;
  final DateTime awardedAt;

  const StreakRewardEntry({required this.streakCount, required this.rewardAmount, required this.awardedAt});

  factory StreakRewardEntry.fromJson(Map<String, dynamic> json) {
    return StreakRewardEntry(
      streakCount: _asInt(json['streakCount']),
      rewardAmount: _asDouble(json['rewardAmount']),
      awardedAt: _tryParseDate(json['awardedAt']) ?? DateTime.now(),
    );
  }
}

class MilestoneDashboard {
  final int totalCompleted;
  final int totalAvailable;
  final MilestoneProgress? nextMilestone;
  final List<MilestoneProgress> milestones;
  final List<MilestoneRewardEntry> recentRewards;

  const MilestoneDashboard({
    required this.totalCompleted,
    required this.totalAvailable,
    this.nextMilestone,
    this.milestones = const [],
    this.recentRewards = const [],
  });

  factory MilestoneDashboard.fromJson(Map<String, dynamic> json) {
    return MilestoneDashboard(
      totalCompleted: _asInt(json['totalCompleted']),
      totalAvailable: _asInt(json['totalAvailable']),
      nextMilestone: json['nextMilestone'] != null
          ? MilestoneProgress.fromJson(json['nextMilestone'] as Map<String, dynamic>)
          : null,
      milestones:
          (json['milestones'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MilestoneProgress.fromJson)
              .toList() ??
          [],
      recentRewards:
          (json['recentRewards'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MilestoneRewardEntry.fromJson)
              .toList() ??
          [],
    );
  }
}

class MilestoneProgress {
  final String milestoneId;
  final String name;
  final String description;
  final String badgeIcon;
  final int currentCount;
  final int targetCount;
  final int percentComplete;
  final bool isCompleted;
  final DateTime? completedAt;
  final double baseReward;
  final double finalReward;

  const MilestoneProgress({
    required this.milestoneId,
    required this.name,
    required this.description,
    required this.badgeIcon,
    required this.currentCount,
    required this.targetCount,
    required this.percentComplete,
    required this.isCompleted,
    this.completedAt,
    required this.baseReward,
    required this.finalReward,
  });

  factory MilestoneProgress.fromJson(Map<String, dynamic> json) {
    return MilestoneProgress(
      milestoneId: json['milestoneId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      badgeIcon: json['badgeIcon']?.toString() ?? '🏅',
      currentCount: _asInt(json['currentCount']),
      targetCount: _asInt(json['targetCount']),
      percentComplete: _asInt(json['percentComplete']),
      isCompleted: json['isCompleted'] == true,
      completedAt: _tryParseDate(json['completedAt']),
      baseReward: _asDouble(json['baseReward']),
      finalReward: _asDouble(json['finalReward']),
    );
  }
}

class MilestoneRewardEntry {
  final String milestoneName;
  final String badgeIcon;
  final double rewardAmount;
  final DateTime awardedAt;

  const MilestoneRewardEntry({
    required this.milestoneName,
    required this.badgeIcon,
    required this.rewardAmount,
    required this.awardedAt,
  });

  factory MilestoneRewardEntry.fromJson(Map<String, dynamic> json) {
    return MilestoneRewardEntry(
      milestoneName: json['milestoneName']?.toString() ?? '',
      badgeIcon: json['badgeIcon']?.toString() ?? '🏅',
      rewardAmount: _asDouble(json['rewardAmount']),
      awardedAt: _tryParseDate(json['awardedAt']) ?? DateTime.now(),
    );
  }
}

class PeakHourStatus {
  final bool isPeakHour;
  final List<ActivePeakWindow> activeWindows;
  final NextPeakWindow? nextWindow;

  const PeakHourStatus({required this.isPeakHour, this.activeWindows = const [], this.nextWindow});

  factory PeakHourStatus.fromJson(Map<String, dynamic> json) {
    return PeakHourStatus(
      isPeakHour: json['isPeakHour'] == true,
      activeWindows:
          (json['activeWindows'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ActivePeakWindow.fromJson)
              .toList() ??
          [],
      nextWindow: json['nextWindow'] != null
          ? NextPeakWindow.fromJson(json['nextWindow'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ActivePeakWindow {
  final String id;
  final String label;
  final String start;
  final String end;
  final double bonusRate;
  final int bonusPercent;

  const ActivePeakWindow({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.bonusRate,
    required this.bonusPercent,
  });

  factory ActivePeakWindow.fromJson(Map<String, dynamic> json) {
    return ActivePeakWindow(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      bonusRate: _asDouble(json['bonusRate']),
      bonusPercent: _asInt(json['bonusPercent']),
    );
  }
}

class NextPeakWindow {
  final String id;
  final String label;
  final String start;
  final String end;
  final double bonusRate;
  final int bonusPercent;
  final int startsInMinutes;

  const NextPeakWindow({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.bonusRate,
    required this.bonusPercent,
    required this.startsInMinutes,
  });

  factory NextPeakWindow.fromJson(Map<String, dynamic> json) {
    return NextPeakWindow(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      bonusRate: _asDouble(json['bonusRate']),
      bonusPercent: _asInt(json['bonusPercent']),
      startsInMinutes: _asInt(json['startsInMinutes']),
    );
  }
}

class PeakWindowSchedule {
  final String id;
  final String label;
  final String start;
  final String end;
  final double bonusRate;
  final int bonusPercent;
  final List<String> days;
  final List<int> daysOfWeek;

  const PeakWindowSchedule({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.bonusRate,
    required this.bonusPercent,
    this.days = const [],
    this.daysOfWeek = const [],
  });

  factory PeakWindowSchedule.fromJson(Map<String, dynamic> json) {
    return PeakWindowSchedule(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      bonusRate: _asDouble(json['bonusRate']),
      bonusPercent: _asInt(json['bonusPercent']),
      days: (json['days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.map((e) => _asInt(e)).toList() ?? [],
    );
  }
}

class IncentiveSummary {
  final String windowKey;
  final int totalEntries;
  final double totalPending;
  final double totalAvailable;
  final double totalPaidOut;
  final Map<IncentiveSourceType, SourceBreakdown> bySource;
  final List<IncentiveLedgerEntry> entries;

  const IncentiveSummary({
    required this.windowKey,
    required this.totalEntries,
    required this.totalPending,
    required this.totalAvailable,
    required this.totalPaidOut,
    this.bySource = const {},
    this.entries = const [],
  });

  double get totalEarned => totalPending + totalAvailable + totalPaidOut;

  factory IncentiveSummary.fromJson(Map<String, dynamic> json) {
    final rawBySource = json['bySource'] as Map<String, dynamic>? ?? {};
    final bySource = <IncentiveSourceType, SourceBreakdown>{};
    rawBySource.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        bySource[parseIncentiveSourceType(key)] = SourceBreakdown.fromJson(value);
      }
    });

    return IncentiveSummary(
      windowKey: json['windowKey']?.toString() ?? '',
      totalEntries: _asInt(json['totalEntries']),
      totalPending: _asDouble(json['totalPending']),
      totalAvailable: _asDouble(json['totalAvailable']),
      totalPaidOut: _asDouble(json['totalPaidOut']),
      bySource: bySource,
      entries:
          (json['entries'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(IncentiveLedgerEntry.fromJson)
              .toList() ??
          [],
    );
  }
}

class SourceBreakdown {
  final int count;
  final double total;

  const SourceBreakdown({required this.count, required this.total});

  factory SourceBreakdown.fromJson(Map<String, dynamic> json) {
    return SourceBreakdown(count: _asInt(json['count']), total: _asDouble(json['total']));
  }
}

class IncentiveLedgerEntry {
  final String id;
  final IncentiveSourceType sourceType;
  final double baseAmount;
  final double multiplier;
  final double finalAmount;
  final LedgerStatus status;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const IncentiveLedgerEntry({
    required this.id,
    required this.sourceType,
    required this.baseAmount,
    required this.multiplier,
    required this.finalAmount,
    required this.status,
    this.metadata = const {},
    required this.createdAt,
  });

  factory IncentiveLedgerEntry.fromJson(Map<String, dynamic> json) {
    return IncentiveLedgerEntry(
      id: json['id']?.toString() ?? '',
      sourceType: parseIncentiveSourceType(json['sourceType']?.toString()),
      baseAmount: _asDouble(json['baseAmount']),
      multiplier: _asDouble(json['multiplier']),
      finalAmount: _asDouble(json['finalAmount']),
      status: parseLedgerStatus(json['status']?.toString()),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: _tryParseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class WithdrawalPolicy {
  final PartnerLevel partnerLevel;
  final double minWithdrawalAmount;
  final InstantWithdrawalInfo instantWithdrawal;
  final bool weeklyAutoEnabled;
  final List<LevelPolicy> allLevelPolicies;

  const WithdrawalPolicy({
    required this.partnerLevel,
    required this.minWithdrawalAmount,
    required this.instantWithdrawal,
    required this.weeklyAutoEnabled,
    this.allLevelPolicies = const [],
  });

  factory WithdrawalPolicy.fromJson(Map<String, dynamic> json) {
    final weeklyAuto = json['weeklyAuto'] as Map<String, dynamic>? ?? {};
    return WithdrawalPolicy(
      partnerLevel: parsePartnerLevel(json['partnerLevel']?.toString()),
      minWithdrawalAmount: _asDouble(json['minWithdrawalAmount']),
      instantWithdrawal: InstantWithdrawalInfo.fromJson(json['instantWithdrawal'] as Map<String, dynamic>? ?? {}),
      weeklyAutoEnabled: weeklyAuto['enabled'] == true,
      allLevelPolicies:
          (json['allLevelPolicies'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(LevelPolicy.fromJson)
              .toList() ??
          [],
    );
  }
}

class InstantWithdrawalInfo {
  final double fee;
  final bool isFree;
  final int freeRemaining;
  final int freeUsed;
  final int totalQuota;
  final double standardFee;

  const InstantWithdrawalInfo({
    required this.fee,
    required this.isFree,
    required this.freeRemaining,
    required this.freeUsed,
    required this.totalQuota,
    required this.standardFee,
  });

  factory InstantWithdrawalInfo.fromJson(Map<String, dynamic> json) {
    return InstantWithdrawalInfo(
      fee: _asDouble(json['fee']),
      isFree: json['isFree'] == true,
      freeRemaining: _asInt(json['freeRemaining']),
      freeUsed: _asInt(json['freeUsed']),
      totalQuota: _asInt(json['totalQuota']),
      standardFee: _asDouble(json['standardFee']),
    );
  }
}

class LevelPolicy {
  final PartnerLevel level;
  final int freeInstantQuota;
  final double instantFee;
  final bool weeklyAutoEnabled;

  const LevelPolicy({
    required this.level,
    required this.freeInstantQuota,
    required this.instantFee,
    required this.weeklyAutoEnabled,
  });

  factory LevelPolicy.fromJson(Map<String, dynamic> json) {
    return LevelPolicy(
      level: parsePartnerLevel(json['level']?.toString()),
      freeInstantQuota: _asInt(json['freeInstantQuota']),
      instantFee: _asDouble(json['instantFee']),
      weeklyAutoEnabled: json['weeklyAutoEnabled'] == true,
    );
  }
}

class PayoutRequest {
  final String id;
  final String riderId;
  final double amount;
  final double fee;
  final double netAmount;
  final PayoutType payoutType;
  final PayoutStatus status;
  final PayoutMethod? method;
  final DateTime? processedAt;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayoutRequest({
    required this.id,
    required this.riderId,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.payoutType,
    required this.status,
    this.method,
    this.processedAt,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    return PayoutRequest(
      id: json['id']?.toString() ?? '',
      riderId: json['riderId']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      fee: _asDouble(json['fee']),
      netAmount: _asDouble(json['netAmount']),
      payoutType: parsePayoutType(json['payoutType']?.toString()),
      status: parsePayoutStatus(json['status']?.toString()),
      method: parsePayoutMethod(json['method']?.toString()),
      processedAt: _tryParseDate(json['processedAt']),
      failureReason: json['failureReason']?.toString(),
      createdAt: _tryParseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _tryParseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class IncentiveBalance {
  final double pendingBudgetApproval;
  final double availableForPayout;

  const IncentiveBalance({required this.pendingBudgetApproval, required this.availableForPayout});

  double get total => pendingBudgetApproval + availableForPayout;

  factory IncentiveBalance.fromJson(Map<String, dynamic> json) {
    return IncentiveBalance(
      pendingBudgetApproval: _asDouble(json['pendingBudgetApproval']),
      availableForPayout: _asDouble(json['availableForPayout']),
    );
  }
}

double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _tryParseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
