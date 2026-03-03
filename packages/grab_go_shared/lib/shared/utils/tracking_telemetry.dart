import 'dart:math';

class TrackingTelemetrySnapshot {
  const TrackingTelemetrySnapshot({
    required this.scope,
    required this.sessionId,
    required this.sessionStartedAt,
    required this.generatedAt,
    required this.locationSamples,
    required this.invalidCoordinateDrops,
    required this.backendSendAttempts,
    required this.backendSendSuccess,
    required this.backendSendFailures,
    required this.fallbackPollAttempts,
    required this.fallbackPollSuccess,
    required this.fallbackPollFailures,
    required this.socketReconnects,
    required this.healthTransitions,
    required this.staleEvents,
    required this.maxPendingQueueDepth,
    required this.avgBackendSendLatencyMs,
    required this.p95BackendSendLatencyMs,
    required this.avgFallbackPollLatencyMs,
    required this.p95FallbackPollLatencyMs,
    required this.avgRealtimeGapMs,
    required this.p95RealtimeGapMs,
    required this.avgScheduledIntervalMs,
    required this.lastScheduledIntervalMs,
    required this.lastRealtimeUpdateAt,
    required this.lastBackendSuccessAt,
    required this.currentHealthState,
    required this.currentRealtimeStalenessMs,
    required this.isRealtimeStale,
  });

  final String scope;
  final String? sessionId;
  final DateTime sessionStartedAt;
  final DateTime generatedAt;
  final int locationSamples;
  final int invalidCoordinateDrops;
  final int backendSendAttempts;
  final int backendSendSuccess;
  final int backendSendFailures;
  final int fallbackPollAttempts;
  final int fallbackPollSuccess;
  final int fallbackPollFailures;
  final int socketReconnects;
  final int healthTransitions;
  final int staleEvents;
  final int maxPendingQueueDepth;
  final int avgBackendSendLatencyMs;
  final int p95BackendSendLatencyMs;
  final int avgFallbackPollLatencyMs;
  final int p95FallbackPollLatencyMs;
  final int avgRealtimeGapMs;
  final int p95RealtimeGapMs;
  final int avgScheduledIntervalMs;
  final int lastScheduledIntervalMs;
  final DateTime? lastRealtimeUpdateAt;
  final DateTime? lastBackendSuccessAt;
  final String? currentHealthState;
  final int currentRealtimeStalenessMs;
  final bool isRealtimeStale;

  double get backendSuccessRate {
    if (backendSendAttempts == 0) return 0;
    return backendSendSuccess / backendSendAttempts;
  }

  double get fallbackSuccessRate {
    if (fallbackPollAttempts == 0) return 0;
    return fallbackPollSuccess / fallbackPollAttempts;
  }

  Map<String, dynamic> toJson() {
    return {
      'scope': scope,
      'sessionId': sessionId,
      'sessionStartedAt': sessionStartedAt.toIso8601String(),
      'generatedAt': generatedAt.toIso8601String(),
      'locationSamples': locationSamples,
      'invalidCoordinateDrops': invalidCoordinateDrops,
      'backendSendAttempts': backendSendAttempts,
      'backendSendSuccess': backendSendSuccess,
      'backendSendFailures': backendSendFailures,
      'backendSuccessRate': backendSuccessRate,
      'fallbackPollAttempts': fallbackPollAttempts,
      'fallbackPollSuccess': fallbackPollSuccess,
      'fallbackPollFailures': fallbackPollFailures,
      'fallbackSuccessRate': fallbackSuccessRate,
      'socketReconnects': socketReconnects,
      'healthTransitions': healthTransitions,
      'staleEvents': staleEvents,
      'maxPendingQueueDepth': maxPendingQueueDepth,
      'avgBackendSendLatencyMs': avgBackendSendLatencyMs,
      'p95BackendSendLatencyMs': p95BackendSendLatencyMs,
      'avgFallbackPollLatencyMs': avgFallbackPollLatencyMs,
      'p95FallbackPollLatencyMs': p95FallbackPollLatencyMs,
      'avgRealtimeGapMs': avgRealtimeGapMs,
      'p95RealtimeGapMs': p95RealtimeGapMs,
      'avgScheduledIntervalMs': avgScheduledIntervalMs,
      'lastScheduledIntervalMs': lastScheduledIntervalMs,
      'lastRealtimeUpdateAt': lastRealtimeUpdateAt?.toIso8601String(),
      'lastBackendSuccessAt': lastBackendSuccessAt?.toIso8601String(),
      'currentHealthState': currentHealthState,
      'currentRealtimeStalenessMs': currentRealtimeStalenessMs,
      'isRealtimeStale': isRealtimeStale,
    };
  }
}

class TrackingTelemetryCollector {
  TrackingTelemetryCollector({required this.scope, this.sampleLimit = 180}) : _sessionStartedAt = DateTime.now();

  final String scope;
  final int sampleLimit;

  String? _sessionId;
  DateTime _sessionStartedAt;
  DateTime? _lastRealtimeUpdateAt;
  DateTime? _lastBackendSuccessAt;
  String? _lastHealthState;
  bool _wasStale = false;

  int _locationSamples = 0;
  int _invalidCoordinateDrops = 0;
  int _backendSendAttempts = 0;
  int _backendSendSuccess = 0;
  int _backendSendFailures = 0;
  int _fallbackPollAttempts = 0;
  int _fallbackPollSuccess = 0;
  int _fallbackPollFailures = 0;
  int _socketReconnects = 0;
  int _healthTransitions = 0;
  int _staleEvents = 0;
  int _maxPendingQueueDepth = 0;
  int _lastScheduledIntervalMs = 0;

  final List<int> _backendSendLatenciesMs = <int>[];
  final List<int> _fallbackPollLatenciesMs = <int>[];
  final List<int> _realtimeGapMs = <int>[];
  final List<int> _scheduledIntervalsMs = <int>[];

  void startSession({String? sessionId}) {
    _sessionId = sessionId;
    _sessionStartedAt = DateTime.now();
    _lastRealtimeUpdateAt = null;
    _lastBackendSuccessAt = null;
    _lastHealthState = null;
    _wasStale = false;

    _locationSamples = 0;
    _invalidCoordinateDrops = 0;
    _backendSendAttempts = 0;
    _backendSendSuccess = 0;
    _backendSendFailures = 0;
    _fallbackPollAttempts = 0;
    _fallbackPollSuccess = 0;
    _fallbackPollFailures = 0;
    _socketReconnects = 0;
    _healthTransitions = 0;
    _staleEvents = 0;
    _maxPendingQueueDepth = 0;
    _lastScheduledIntervalMs = 0;

    _backendSendLatenciesMs.clear();
    _fallbackPollLatenciesMs.clear();
    _realtimeGapMs.clear();
    _scheduledIntervalsMs.clear();
  }

  void recordLocationSample({DateTime? at}) {
    final now = at ?? DateTime.now();
    _locationSamples++;
    if (_lastRealtimeUpdateAt != null) {
      final gapMs = now.difference(_lastRealtimeUpdateAt!).inMilliseconds;
      if (gapMs > 0) {
        _addSample(_realtimeGapMs, gapMs);
      }
    }
    _lastRealtimeUpdateAt = now;
    _wasStale = false;
  }

  void recordInvalidCoordinateDrop() {
    _invalidCoordinateDrops++;
  }

  void recordBackendSendAttempt({int pendingQueueDepth = 0}) {
    _backendSendAttempts++;
    _maxPendingQueueDepth = max(_maxPendingQueueDepth, pendingQueueDepth);
  }

  void recordBackendSendResult({required bool success, required Duration latency, int pendingQueueDepth = 0}) {
    _maxPendingQueueDepth = max(_maxPendingQueueDepth, pendingQueueDepth);
    _addSample(_backendSendLatenciesMs, latency.inMilliseconds);
    if (success) {
      _backendSendSuccess++;
      _lastBackendSuccessAt = DateTime.now();
    } else {
      _backendSendFailures++;
    }
  }

  void recordFallbackPollResult({required bool success, required Duration latency}) {
    _fallbackPollAttempts++;
    _addSample(_fallbackPollLatenciesMs, latency.inMilliseconds);
    if (success) {
      _fallbackPollSuccess++;
    } else {
      _fallbackPollFailures++;
    }
  }

  void recordSocketReconnect() {
    _socketReconnects++;
  }

  void recordHealthTransition({required String from, required String to}) {
    if (from == to) {
      _lastHealthState = to;
      return;
    }
    _healthTransitions++;
    _lastHealthState = to;
  }

  void recordScheduledInterval(int intervalMs) {
    if (intervalMs <= 0) return;
    _lastScheduledIntervalMs = intervalMs;
    _addSample(_scheduledIntervalsMs, intervalMs);
  }

  TrackingTelemetrySnapshot snapshot({Duration staleThreshold = const Duration(seconds: 35)}) {
    final now = DateTime.now();
    final stalenessMs = _lastRealtimeUpdateAt == null ? -1 : now.difference(_lastRealtimeUpdateAt!).inMilliseconds;
    final isStale = _lastRealtimeUpdateAt == null || now.difference(_lastRealtimeUpdateAt!) > staleThreshold;

    if (isStale && !_wasStale) {
      _staleEvents++;
      _wasStale = true;
    } else if (!isStale) {
      _wasStale = false;
    }

    return TrackingTelemetrySnapshot(
      scope: scope,
      sessionId: _sessionId,
      sessionStartedAt: _sessionStartedAt,
      generatedAt: now,
      locationSamples: _locationSamples,
      invalidCoordinateDrops: _invalidCoordinateDrops,
      backendSendAttempts: _backendSendAttempts,
      backendSendSuccess: _backendSendSuccess,
      backendSendFailures: _backendSendFailures,
      fallbackPollAttempts: _fallbackPollAttempts,
      fallbackPollSuccess: _fallbackPollSuccess,
      fallbackPollFailures: _fallbackPollFailures,
      socketReconnects: _socketReconnects,
      healthTransitions: _healthTransitions,
      staleEvents: _staleEvents,
      maxPendingQueueDepth: _maxPendingQueueDepth,
      avgBackendSendLatencyMs: _average(_backendSendLatenciesMs),
      p95BackendSendLatencyMs: _percentile(_backendSendLatenciesMs, 0.95),
      avgFallbackPollLatencyMs: _average(_fallbackPollLatenciesMs),
      p95FallbackPollLatencyMs: _percentile(_fallbackPollLatenciesMs, 0.95),
      avgRealtimeGapMs: _average(_realtimeGapMs),
      p95RealtimeGapMs: _percentile(_realtimeGapMs, 0.95),
      avgScheduledIntervalMs: _average(_scheduledIntervalsMs),
      lastScheduledIntervalMs: _lastScheduledIntervalMs,
      lastRealtimeUpdateAt: _lastRealtimeUpdateAt,
      lastBackendSuccessAt: _lastBackendSuccessAt,
      currentHealthState: _lastHealthState,
      currentRealtimeStalenessMs: stalenessMs,
      isRealtimeStale: isStale,
    );
  }

  void _addSample(List<int> target, int value) {
    if (value < 0) return;
    target.add(value);
    if (target.length > sampleLimit) {
      target.removeRange(0, target.length - sampleLimit);
    }
  }

  int _average(List<int> values) {
    if (values.isEmpty) return 0;
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return (total / values.length).round();
  }

  int _percentile(List<int> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final clampedPercentile = percentile.clamp(0.0, 1.0);
    final index = (clampedPercentile * (sorted.length - 1)).round();
    return sorted[index];
  }
}
