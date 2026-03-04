import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

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

  Uri _riderUri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse(
      '$_baseUrl/riders/$path',
    ).replace(queryParameters: queryParameters);
  }

  Future<RiderWalletDashboardData> fetchDashboard({
    String transactionsPeriod = 'thisWeek',
  }) async {
    final headers = await _buildHeaders();

    final walletResponse = await _client.get(
      _riderUri('wallet'),
      headers: headers,
    );
    if (walletResponse.statusCode != 200) {
      throw Exception(
        'Failed to fetch wallet: ${walletResponse.statusCode} ${walletResponse.body}',
      );
    }

    final walletJson = jsonDecode(walletResponse.body) as Map<String, dynamic>;
    final walletData = walletJson['data'] as Map<String, dynamic>? ?? {};

    final results = await Future.wait<http.Response?>([
      _safeGet(_riderUri('earnings', {'period': 'today'}), headers),
      _safeGet(_riderUri('earnings', {'period': 'thisWeek'}), headers),
      _safeGet(_riderUri('earnings', {'period': 'thisMonth'}), headers),
      _safeGet(
        _riderUri('transactions', {'period': transactionsPeriod}),
        headers,
      ),
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

  double? _parseEarningsTotal(
    http.Response? response, {
    required String period,
  }) {
    if (response == null) return null;
    if (response.statusCode != 200) {
      debugPrint(
        'Failed earnings response for $period: ${response.statusCode} ${response.body}',
      );
      return null;
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final summary =
          (decoded['data'] as Map<String, dynamic>?)?['summary']
              as Map<String, dynamic>?;
      return _asDouble(summary?['total']);
    } catch (e) {
      debugPrint('Failed to parse earnings response for $period: $e');
      return null;
    }
  }

  List<TransactionModel> _parseTransactions(http.Response? response) {
    if (response == null) return [];
    if (response.statusCode != 200) {
      debugPrint(
        'Failed transactions response: ${response.statusCode} ${response.body}',
      );
      return [];
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTransactions = decoded['data'] as List<dynamic>? ?? [];

      return rawTransactions
          .whereType<Map<String, dynamic>>()
          .map(_mapTransaction)
          .toList();
    } catch (e) {
      debugPrint('Failed to parse transactions response: $e');
      return [];
    }
  }

  TransactionModel _mapTransaction(Map<String, dynamic> raw) {
    final type = _parseTransactionType(raw['type']?.toString());
    final status = _parseTransactionStatus(raw['status']?.toString());
    final createdAtRaw =
        raw['createdAt']?.toString() ?? raw['updatedAt']?.toString() ?? '';
    final createdAt =
        DateTime.tryParse(createdAtRaw)?.toLocal() ?? DateTime.now();
    final description = _resolveDescription(
      type,
      raw['description']?.toString(),
    );

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
}
