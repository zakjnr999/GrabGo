import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_rider/features/home/models/partner_models.dart';
import 'package:grab_go_rider/shared/service/memory_cache.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

class RiderPartnerService {
  RiderPartnerService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String get _baseUrl => AppConfig.apiBaseUrl;

  // ───────────── cache keys ─────────────
  static const _kDashboard = 'partner_dashboard';
  static const _kDashboardPage = 'partner_dashboard_page';
  static const _kQuestsStreaks = 'partner_quests_streaks';
  static const _kMilestones = 'partner_milestones';
  static const _kIncentiveBalance = 'partner_balance';
  static const _kPeakStatus = 'partner_peak_status';
  static const _kPeakSchedule = 'partner_peak_schedule';
  static const _kWithdrawalPolicy = 'partner_withdrawal_policy';

  /// Default TTL for partner data.
  static const _ttl = Duration(minutes: 5);

  /// Call after a mutation (e.g. requesting payout) to bust stale data.
  static void invalidateAll() => MemoryCache.invalidatePrefix('partner_');

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await CacheService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _riderUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$_baseUrl/riders/$path').replace(queryParameters: queryParameters);
  }

  Map<String, dynamic> _unwrap(http.Response response, String label) {
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch $label: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }

  List<dynamic> _unwrapList(http.Response response, String label) {
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch $label: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as List<dynamic>? ?? [];
  }

  Future<http.Response?> _safeGet(Uri uri, Map<String, String> headers) async {
    try {
      return await _client.get(uri, headers: headers);
    } catch (e) {
      debugPrint('Failed request: $uri | error: $e');
      return null;
    }
  }

  Future<PartnerDashboard> fetchPartnerDashboard({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<PartnerDashboard>(
      _kDashboard,
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('partner-profile'), headers: headers);
        return PartnerDashboard.fromJson(_unwrap(response, 'partner dashboard'));
      },
    );
  }

  Future<ScoreBreakdown> fetchScoreBreakdown() async {
    return MemoryCache.getOrFetch<ScoreBreakdown>(
      'partner_score_breakdown',
      ttl: _ttl,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('partner-profile/breakdown'), headers: headers);
        return ScoreBreakdown.fromJson(_unwrap(response, 'score breakdown'));
      },
    );
  }

  Future<List<LevelHistoryEntry>> fetchLevelHistory({int limit = 20}) async {
    return MemoryCache.getOrFetch<List<LevelHistoryEntry>>(
      'partner_level_history',
      ttl: _ttl,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(
          _riderUri('partner-profile/history', {'limit': limit.toString()}),
          headers: headers,
        );
        return _unwrapList(
          response,
          'level history',
        ).whereType<Map<String, dynamic>>().map(LevelHistoryEntry.fromJson).toList();
      },
    );
  }

  Future<List<QuestProgress>> fetchQuests({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<List<QuestProgress>>(
      'partner_quests',
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('quests'), headers: headers);
        return _unwrapList(response, 'quests').whereType<Map<String, dynamic>>().map(QuestProgress.fromJson).toList();
      },
    );
  }

  Future<StreakDashboard> fetchStreaks({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<StreakDashboard>(
      'partner_streaks',
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('streaks'), headers: headers);
        return StreakDashboard.fromJson(_unwrap(response, 'streaks'));
      },
    );
  }

  Future<MilestoneDashboard> fetchMilestones({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<MilestoneDashboard>(
      _kMilestones,
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('milestones'), headers: headers);
        return MilestoneDashboard.fromJson(_unwrap(response, 'milestones'));
      },
    );
  }

  Future<IncentiveSummary> fetchIncentives({String? windowKey}) async {
    return MemoryCache.getOrFetch<IncentiveSummary>(
      'partner_incentives_${windowKey ?? 'default'}',
      ttl: _ttl,
      fetch: () async {
        final headers = await _buildHeaders();
        final query = windowKey != null ? {'windowKey': windowKey} : null;
        final response = await _client.get(_riderUri('incentives', query), headers: headers);
        return IncentiveSummary.fromJson(_unwrap(response, 'incentives'));
      },
    );
  }

  Future<PeakHourStatus> fetchPeakHourStatus() async {
    return MemoryCache.getOrFetch<PeakHourStatus>(
      _kPeakStatus,
      ttl: const Duration(minutes: 2), // shorter TTL — time-sensitive
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('peak-hours/status'), headers: headers);
        return PeakHourStatus.fromJson(_unwrap(response, 'peak hour status'));
      },
    );
  }

  Future<List<PeakWindowSchedule>> fetchPeakSchedule() async {
    return MemoryCache.getOrFetch<List<PeakWindowSchedule>>(
      _kPeakSchedule,
      ttl: const Duration(minutes: 15), // schedule rarely changes
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('peak-hours/schedule'), headers: headers);
        return _unwrapList(
          response,
          'peak schedule',
        ).whereType<Map<String, dynamic>>().map(PeakWindowSchedule.fromJson).toList();
      },
    );
  }

  Future<WithdrawalPolicy> fetchWithdrawalPolicy() async {
    return MemoryCache.getOrFetch<WithdrawalPolicy>(
      _kWithdrawalPolicy,
      ttl: const Duration(minutes: 30), // policy rarely changes
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('wallet/withdrawal-policy'), headers: headers);
        return WithdrawalPolicy.fromJson(_unwrap(response, 'withdrawal policy'));
      },
    );
  }

  Future<List<PayoutRequest>> fetchPayoutHistory() async {
    return MemoryCache.getOrFetch<List<PayoutRequest>>(
      'partner_payout_history',
      ttl: _ttl,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('wallet/payout-history'), headers: headers);
        return _unwrapList(
          response,
          'payout history',
        ).whereType<Map<String, dynamic>>().map(PayoutRequest.fromJson).toList();
      },
    );
  }

  Future<IncentiveBalance> fetchIncentiveBalance({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<IncentiveBalance>(
      _kIncentiveBalance,
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();
        final response = await _client.get(_riderUri('wallet/incentive-balance'), headers: headers);
        return IncentiveBalance.fromJson(_unwrap(response, 'incentive balance'));
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  COMPOSITE PAGE LOADERS (cached as a unit)
  // ─────────────────────────────────────────────────────────────

  Future<PartnerDashboardPageData> loadPartnerDashboardPage({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<PartnerDashboardPageData>(
      _kDashboardPage,
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();

        final results = await Future.wait([
          _client.get(_riderUri('partner-profile'), headers: headers),
          _safeGet(_riderUri('wallet/incentive-balance'), headers),
          _safeGet(_riderUri('peak-hours/status'), headers),
        ]);

        final dashboard = PartnerDashboard.fromJson(_unwrap(results[0] as http.Response, 'partner dashboard'));

        // Also store the dashboard individually so the appbar level chip can read it
        MemoryCache.put<PartnerDashboard>(_kDashboard, dashboard, ttl: _ttl);

        IncentiveBalance? balance;
        if (results[1] != null && (results[1] as http.Response).statusCode == 200) {
          balance = IncentiveBalance.fromJson(_unwrap(results[1] as http.Response, 'balance'));
          MemoryCache.put<IncentiveBalance>(_kIncentiveBalance, balance, ttl: _ttl);
        }

        PeakHourStatus? peakStatus;
        if (results[2] != null && (results[2] as http.Response).statusCode == 200) {
          peakStatus = PeakHourStatus.fromJson(_unwrap(results[2] as http.Response, 'peak status'));
          MemoryCache.put<PeakHourStatus>(_kPeakStatus, peakStatus, ttl: _ttl);
        }

        return PartnerDashboardPageData(dashboard: dashboard, incentiveBalance: balance, peakHourStatus: peakStatus);
      },
    );
  }

  Future<QuestsStreaksPageData> loadQuestsStreaksPage({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<QuestsStreaksPageData>(
      _kQuestsStreaks,
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();

        final results = await Future.wait([
          _client.get(_riderUri('quests'), headers: headers),
          _client.get(_riderUri('streaks'), headers: headers),
          _safeGet(_riderUri('incentives'), headers),
        ]);

        final quests = _unwrapList(
          results[0]!,
          'quests',
        ).whereType<Map<String, dynamic>>().map(QuestProgress.fromJson).toList();

        final streaks = StreakDashboard.fromJson(_unwrap(results[1]!, 'streaks'));

        IncentiveSummary? incentives;
        if (results[2] != null && (results[2] as http.Response).statusCode == 200) {
          incentives = IncentiveSummary.fromJson(_unwrap(results[2] as http.Response, 'incentives'));
        }

        return QuestsStreaksPageData(quests: quests, streaks: streaks, incentives: incentives);
      },
    );
  }

  Future<MilestonesPageData> loadMilestonesPage({bool forceRefresh = false}) async {
    return MemoryCache.getOrFetch<MilestonesPageData>(
      _kMilestones,
      ttl: _ttl,
      forceRefresh: forceRefresh,
      fetch: () async {
        final headers = await _buildHeaders();

        final results = await Future.wait([
          _client.get(_riderUri('milestones'), headers: headers),
          _safeGet(_riderUri('peak-hours/schedule'), headers),
        ]);

        final milestones = MilestoneDashboard.fromJson(_unwrap(results[0]!, 'milestones'));

        List<PeakWindowSchedule>? schedule;
        if (results[1] != null && (results[1] as http.Response).statusCode == 200) {
          schedule = _unwrapList(
            results[1] as http.Response,
            'peak schedule',
          ).whereType<Map<String, dynamic>>().map(PeakWindowSchedule.fromJson).toList();
          MemoryCache.put<List<PeakWindowSchedule>>(_kPeakSchedule, schedule, ttl: const Duration(minutes: 15));
        }

        return MilestonesPageData(milestones: milestones, peakSchedule: schedule);
      },
    );
  }
}

class PartnerDashboardPageData {
  final PartnerDashboard dashboard;
  final IncentiveBalance? incentiveBalance;
  final PeakHourStatus? peakHourStatus;

  const PartnerDashboardPageData({required this.dashboard, this.incentiveBalance, this.peakHourStatus});
}

class QuestsStreaksPageData {
  final List<QuestProgress> quests;
  final StreakDashboard streaks;
  final IncentiveSummary? incentives;

  const QuestsStreaksPageData({required this.quests, required this.streaks, this.incentives});
}

class MilestonesPageData {
  final MilestoneDashboard milestones;
  final List<PeakWindowSchedule>? peakSchedule;

  const MilestonesPageData({required this.milestones, this.peakSchedule});
}
