import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/device_id_service.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class RiderWalletDashboardData {
  final double balance;
  final double totalEarnings;
  final double totalWithdrawals;
  final double pendingWithdrawals;
  final double? todayEarnings;
  final double? thisWeekEarnings;
  final double? thisMonthEarnings;
  final List<TransactionModel> transactions;

  const RiderWalletDashboardData({
    required this.balance,
    required this.totalEarnings,
    required this.totalWithdrawals,
    required this.pendingWithdrawals,
    required this.todayEarnings,
    required this.thisWeekEarnings,
    required this.thisMonthEarnings,
    required this.transactions,
  });
}

class RiderWalletService {
  RiderWalletService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String get _baseUrl => AppConfig.apiBaseUrl;

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await CacheService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Build headers with device fingerprint + optional idempotency key.
  /// Used for sensitive operations like withdrawals.
  Future<Map<String, String>> _buildSecureHeaders({String? idempotencyKey}) async {
    final headers = await _buildHeaders();
    try {
      final deviceId = await DeviceIdService().getDeviceId();
      headers['X-Device-Id'] = deviceId;
    } catch (_) {
      // Best-effort — don't block the request
    }
    if (idempotencyKey != null) {
      headers['X-Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Uri _riderUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$_baseUrl/riders/$path').replace(queryParameters: queryParameters);
  }

  Future<RiderWalletDashboardData> fetchDashboard({String transactionsPeriod = 'thisWeek'}) async {
    final headers = await _buildHeaders();

    final walletResponse = await _client.get(_riderUri('wallet'), headers: headers);
    if (walletResponse.statusCode != 200) {
      throw Exception('Failed to fetch wallet: ${walletResponse.statusCode} ${walletResponse.body}');
    }

    final walletJson = jsonDecode(walletResponse.body) as Map<String, dynamic>;
    final walletData = walletJson['data'] as Map<String, dynamic>? ?? {};

    final results = await Future.wait<http.Response?>([
      _safeGet(_riderUri('earnings', {'period': 'today'}), headers),
      _safeGet(_riderUri('earnings', {'period': 'thisWeek'}), headers),
      _safeGet(_riderUri('earnings', {'period': 'thisMonth'}), headers),
      _safeGet(_riderUri('transactions', {'period': transactionsPeriod}), headers),
    ]);

    final todayEarnings = _parseEarningsTotal(results[0], period: 'today');
    final weekEarnings = _parseEarningsTotal(results[1], period: 'thisWeek');
    final monthEarnings = _parseEarningsTotal(results[2], period: 'thisMonth');
    final transactions = _parseTransactions(results[3]);

    return RiderWalletDashboardData(
      balance: _asDouble(walletData['balance']),
      totalEarnings: _asDouble(walletData['totalEarnings']),
      totalWithdrawals: _asDouble(walletData['totalWithdrawals']),
      pendingWithdrawals: _asDouble(walletData['pendingWithdrawals']),
      todayEarnings: todayEarnings,
      thisWeekEarnings: weekEarnings,
      thisMonthEarnings: monthEarnings,
      transactions: transactions,
    );
  }

  Future<http.Response?> _safeGet(Uri uri, Map<String, String> headers) async {
    try {
      return await _client.get(uri, headers: headers);
    } catch (e) {
      debugPrint('Failed request: $uri | error: $e');
      return null;
    }
  }

  double? _parseEarningsTotal(http.Response? response, {required String period}) {
    if (response == null) return null;
    if (response.statusCode != 200) {
      debugPrint('Failed earnings response for $period: ${response.statusCode} ${response.body}');
      return null;
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final summary = (decoded['data'] as Map<String, dynamic>?)?['summary'] as Map<String, dynamic>?;
      return _asDouble(summary?['total']);
    } catch (e) {
      debugPrint('Failed to parse earnings response for $period: $e');
      return null;
    }
  }

  List<TransactionModel> _parseTransactions(http.Response? response) {
    if (response == null) return [];
    if (response.statusCode != 200) {
      debugPrint('Failed transactions response: ${response.statusCode} ${response.body}');
      return [];
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTransactions = decoded['data'] as List<dynamic>? ?? [];

      return rawTransactions.whereType<Map<String, dynamic>>().map(_mapTransaction).toList();
    } catch (e) {
      debugPrint('Failed to parse transactions response: $e');
      return [];
    }
  }

  TransactionModel _mapTransaction(Map<String, dynamic> raw) {
    final type = _parseTransactionType(raw['type']?.toString());
    final status = _parseTransactionStatus(raw['status']?.toString());
    final createdAtRaw = raw['createdAt']?.toString() ?? raw['updatedAt']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal() ?? DateTime.now();
    final description = _resolveDescription(type, raw['description']?.toString());

    return TransactionModel(
      id: raw['id']?.toString() ?? '',
      amount: _asDouble(raw['amount']),
      type: type,
      description: description,
      dateTime: createdAt,
      status: status,
    );
  }

  TransactionType _parseTransactionType(String? value) {
    switch (value?.toLowerCase()) {
      case 'delivery':
        return TransactionType.delivery;
      case 'tip':
        return TransactionType.tip;
      case 'bonus':
        return TransactionType.bonus;
      case 'withdrawal':
        return TransactionType.withdrawal;
      case 'penalty':
        return TransactionType.penalty;
      default:
        return TransactionType.delivery;
    }
  }

  TransactionStatus _parseTransactionStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'pending':
      default:
        return TransactionStatus.pending;
    }
  }

  String _resolveDescription(TransactionType type, String? value) {
    final parsed = value?.trim() ?? '';
    if (parsed.isNotEmpty) return parsed;

    switch (type) {
      case TransactionType.delivery:
        return 'Delivery earning';
      case TransactionType.tip:
        return 'Tip received';
      case TransactionType.bonus:
        return 'Bonus payout';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.penalty:
        return 'Penalty charge';
    }
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  /// Submit a withdrawal request to the backend.
  ///
  /// [amount] – the GHS amount to withdraw.
  /// [withdrawalMethod] – one of `bank_account`, `mtn_mobile_money`, `vodafone_cash`.
  /// [withdrawalAccount] – account identifier (phone number or bank details).
  ///
  /// Returns a map with the transaction data on success, or throws on error.
  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String withdrawalMethod,
    required String withdrawalAccount,
    String? description,
  }) async {
    // Generate a unique idempotency key to prevent duplicate submissions
    final idempotencyKey = const Uuid().v4();
    final headers = await _buildSecureHeaders(idempotencyKey: idempotencyKey);
    final body = {
      'amount': amount,
      'withdrawalMethod': withdrawalMethod,
      'withdrawalAccount': withdrawalAccount,
      if (description != null) 'description': description,
    };

    final response = await _client.post(_riderUri('withdraw'), headers: headers, body: jsonEncode(body));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 || response.statusCode == 200) {
      return decoded['data'] as Map<String, dynamic>? ?? {};
    }

    // Extract error message from backend
    final message = decoded['message']?.toString() ?? 'Withdrawal request failed';
    throw Exception(message);
  }

  // ─── Loan / Cash Advance ─────────────────────────────────────────────────

  /// Fetch loan eligibility and policy info for the current rider.
  Future<LoanEligibility> fetchLoanEligibility() async {
    final headers = await _buildHeaders();
    final response = await _client.get(_riderUri('loan/eligibility'), headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch loan eligibility');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return LoanEligibility.fromJson(data);
  }

  /// Submit a loan application.
  Future<Map<String, dynamic>> applyForLoan({
    required double amount,
    required int termDays,
    required String purpose,
  }) async {
    final headers = await _buildSecureHeaders(idempotencyKey: const Uuid().v4());
    final body = {'amount': amount, 'termDays': termDays, 'purpose': purpose};

    final response = await _client.post(_riderUri('loan/apply'), headers: headers, body: jsonEncode(body));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 || response.statusCode == 200) {
      return decoded;
    }

    final message = decoded['message']?.toString() ?? 'Loan application failed';
    throw Exception(message);
  }

  /// Fetch loan history.
  Future<List<Map<String, dynamic>>> fetchLoanHistory({String? status}) async {
    final headers = await _buildHeaders();
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;

    final response = await _client.get(
      _riderUri('loan/history', queryParams.isNotEmpty ? queryParams : null),
      headers: headers,
    );

    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Fetch single loan detail.
  Future<Map<String, dynamic>> fetchLoanDetail(String loanId) async {
    final headers = await _buildHeaders();
    final response = await _client.get(_riderUri('loan/$loanId'), headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch loan detail');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }
}

// ─── Loan Eligibility Model ───────────────────────────────────────────────

class LoanEligibility {
  final bool eligible;
  final List<String> reasons;
  final String partnerLevel;
  final double maxAmount;
  final double minAmount;
  final double interestRate;
  final List<int> availableTerms;
  final int activeLoans;
  final int totalDeliveries;
  final double averageRating;
  final double outstandingBalance;

  const LoanEligibility({
    required this.eligible,
    required this.reasons,
    required this.partnerLevel,
    required this.maxAmount,
    required this.minAmount,
    required this.interestRate,
    required this.availableTerms,
    required this.activeLoans,
    required this.totalDeliveries,
    required this.averageRating,
    required this.outstandingBalance,
  });

  factory LoanEligibility.fromJson(Map<String, dynamic> json) {
    return LoanEligibility(
      eligible: json['eligible'] as bool? ?? false,
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      partnerLevel: json['partnerLevel']?.toString() ?? 'L1',
      maxAmount: _toDouble(json['maxAmount']),
      minAmount: _toDouble(json['minAmount']),
      interestRate: _toDouble(json['interestRate']),
      availableTerms: (json['availableTerms'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
      activeLoans: (json['activeLoans'] as num?)?.toInt() ?? 0,
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      averageRating: _toDouble(json['averageRating']),
      outstandingBalance: _toDouble(json['outstandingBalance']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
