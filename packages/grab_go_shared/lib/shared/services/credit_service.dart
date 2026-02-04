import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

/// Credit transaction model
class CreditTransaction {
  final String id;
  final double amount;
  final String formattedAmount;
  final String type;
  final String typeLabel;
  final String? description;
  final String? orderId;
  final DateTime createdAt;
  final bool isCredit;

  CreditTransaction({
    required this.id,
    required this.amount,
    required this.formattedAmount,
    required this.type,
    required this.typeLabel,
    this.description,
    this.orderId,
    required this.createdAt,
    required this.isCredit,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      formattedAmount: json['formattedAmount'] ?? '',
      type: json['type'] ?? '',
      typeLabel: json['typeLabel'] ?? '',
      description: json['description'],
      orderId: json['orderId'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isCredit: json['isCredit'] ?? false,
    );
  }
}

/// Credit balance model
class CreditBalance {
  final double balance;
  final String currency;
  final String formatted;

  CreditBalance({required this.balance, required this.currency, required this.formatted});

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      balance: (json['balance'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'GHS',
      formatted: json['formatted'] ?? '₵0.00',
    );
  }
}

/// Credit calculation result for checkout
class CreditCalculation {
  final double creditsApplied;
  final double remainingPayment;
  final double creditBalance;
  final String formattedCreditsApplied;
  final String formattedRemainingPayment;
  final String formattedCreditBalance;

  CreditCalculation({
    required this.creditsApplied,
    required this.remainingPayment,
    required this.creditBalance,
    required this.formattedCreditsApplied,
    required this.formattedRemainingPayment,
    required this.formattedCreditBalance,
  });

  factory CreditCalculation.fromJson(Map<String, dynamic> json) {
    return CreditCalculation(
      creditsApplied: (json['creditsApplied'] ?? 0).toDouble(),
      remainingPayment: (json['remainingPayment'] ?? 0).toDouble(),
      creditBalance: (json['creditBalance'] ?? 0).toDouble(),
      formattedCreditsApplied: json['formattedCreditsApplied'] ?? '₵0.00',
      formattedRemainingPayment: json['formattedRemainingPayment'] ?? '₵0.00',
      formattedCreditBalance: json['formattedCreditBalance'] ?? '₵0.00',
    );
  }
}

/// GrabGo Credit Service
/// Manages in-app store credits for customers
class CreditService {
  static final CreditService _instance = CreditService._internal();
  factory CreditService() => _instance;
  CreditService._internal();

  static const String _baseUrl = 'https://grabgo-backend.onrender.com/api/credits';

  /// Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorageService.getAuthToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  /// Get current user's credit balance
  Future<CreditBalance?> getBalance() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$_baseUrl/balance'), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return CreditBalance.fromJson(data['data']);
        }
      }
      debugPrint('Failed to get credit balance: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error getting credit balance: $e');
      return null;
    }
  }

  /// Get credit transaction history
  Future<List<CreditTransaction>> getTransactionHistory({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$_baseUrl/transactions?page=$page&limit=$limit'), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final transactions = (data['data']['transactions'] as List)
              .map((tx) => CreditTransaction.fromJson(tx))
              .toList();
          return transactions;
        }
      }
      debugPrint('Failed to get transactions: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  /// Calculate credit application for checkout
  Future<CreditCalculation?> calculateForCheckout(double orderTotal, {bool useCredits = true}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/calculate'),
        headers: headers,
        body: jsonEncode({'orderTotal': orderTotal, 'useCredits': useCredits}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return CreditCalculation.fromJson(data['data']);
        }
      }
      debugPrint('Failed to calculate credits: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error calculating credits: $e');
      return null;
    }
  }

  /// Check if user has any credits available
  Future<bool> hasCredits() async {
    final balance = await getBalance();
    return balance != null && balance.balance > 0;
  }

  /// Get formatted balance string
  Future<String> getFormattedBalance() async {
    final balance = await getBalance();
    return balance?.formatted ?? '₵0.00';
  }
}
