import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/parcel/service/parcel_api_client.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ParcelProvider extends ChangeNotifier {
  final ParcelApiClient _apiClient;
  static const String _configCacheKey = 'parcel_config_cache_v1';
  static const Duration _configCacheMaxAge = Duration(hours: 6);

  ParcelProvider({ParcelApiClient? apiClient})
    : _apiClient = apiClient ?? ParcelApiClient();

  ParcelConfigModel? _config;
  ParcelQuoteResponseModel? _latestQuote;
  ParcelOrderSummary? _latestOrder;
  List<ParcelOrderSummary> _orders = const [];
  ParcelOrderDetailModel? _selectedOrder;

  bool _isLoadingConfig = false;
  bool _isQuoting = false;
  bool _isCreatingOrder = false;
  bool _isLoadingOrders = false;
  bool _isLoadingOrderDetail = false;
  bool _isInitializingPayment = false;
  bool _isConfirmingPayment = false;
  bool _isCancellingOrder = false;

  String? _errorMessage;

  ParcelConfigModel? get config => _config;
  ParcelQuoteResponseModel? get latestQuote => _latestQuote;
  ParcelOrderSummary? get latestOrder => _latestOrder;
  List<ParcelOrderSummary> get orders => _orders;
  ParcelOrderDetailModel? get selectedOrder => _selectedOrder;

  bool get isLoadingConfig => _isLoadingConfig;
  bool get isQuoting => _isQuoting;
  bool get isCreatingOrder => _isCreatingOrder;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingOrderDetail => _isLoadingOrderDetail;
  bool get isInitializingPayment => _isInitializingPayment;
  bool get isConfirmingPayment => _isConfirmingPayment;
  bool get isCancellingOrder => _isCancellingOrder;
  String? get errorMessage => _errorMessage;

  Future<void> loadConfig({bool forceRefresh = false}) async {
    _isLoadingConfig = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cached = forceRefresh ? null : _readCachedConfig();
      if (cached != null) {
        _config = cached.config;
      }

      if (cached != null && !cached.isStale) {
        return;
      }

      final fresh = await _apiClient.fetchConfig();
      _config = fresh;
      await _saveConfigToCache(fresh);
    } catch (e) {
      if (_config == null) {
        _errorMessage = _readableError(e);
      } else {
        debugPrint(
          'ParcelProvider: using cached config due to refresh error: $e',
        );
      }
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  Future<void> requestQuote(ParcelQuoteRequest request) async {
    _isQuoting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _latestQuote = await _apiClient.createQuote(request);
    } catch (e) {
      _errorMessage = _readableError(e);
      _latestQuote = null;
    } finally {
      _isQuoting = false;
      notifyListeners();
    }
  }

  Future<ParcelOrderSummary?> createOrder(
    ParcelCreateOrderRequest request,
  ) async {
    _isCreatingOrder = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _apiClient.createOrder(request);
      _latestOrder = order;
      _upsertOrder(order);
      return order;
    } catch (e) {
      _errorMessage = _readableError(e);
      return null;
    } finally {
      _isCreatingOrder = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders({int limit = 30}) async {
    _isLoadingOrders = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _apiClient.listOrders(limit: limit);
      _orders = _sortOrdersByCreatedAt(fetched);
      if (_latestOrder != null) {
        _upsertOrder(_latestOrder!);
      }
    } catch (e) {
      _errorMessage = _readableError(e);
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  Future<ParcelOrderDetailModel?> loadOrderDetail(String parcelId) async {
    _isLoadingOrderDetail = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final detail = await _apiClient.getOrder(parcelId);
      _selectedOrder = detail;
      _latestOrder = detail.toSummary();
      _upsertOrder(_latestOrder!);
      return detail;
    } catch (e) {
      _errorMessage = _readableError(e);
      return null;
    } finally {
      _isLoadingOrderDetail = false;
      notifyListeners();
    }
  }

  Future<ParcelPaymentInitialization?> initializePaystack(
    String parcelId,
  ) async {
    _isInitializingPayment = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _apiClient.initializePaystack(parcelId);
    } catch (e) {
      _errorMessage = _readableError(e);
      return null;
    } finally {
      _isInitializingPayment = false;
      notifyListeners();
    }
  }

  Future<ParcelPaymentConfirmation?> confirmPayment(
    String parcelId, {
    String? reference,
    String provider = 'paystack',
  }) async {
    _isConfirmingPayment = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final confirmation = await _apiClient.confirmPayment(
        parcelId,
        reference: reference,
        provider: provider,
      );

      await loadOrderDetail(parcelId);
      return confirmation;
    } catch (e) {
      _errorMessage = _readableError(e);
      return null;
    } finally {
      _isConfirmingPayment = false;
      notifyListeners();
    }
  }

  Future<ParcelOrderSummary?> cancelOrder(
    String parcelId, {
    String? reason,
  }) async {
    _isCancellingOrder = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _apiClient.cancelOrder(parcelId, reason: reason);
      _latestOrder = order;
      _upsertOrder(order);
      if (_selectedOrder?.id == parcelId) {
        await loadOrderDetail(parcelId);
      }
      return order;
    } catch (e) {
      _errorMessage = _readableError(e);
      return null;
    } finally {
      _isCancellingOrder = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void clearSelectedOrder() {
    if (_selectedOrder == null) return;
    _selectedOrder = null;
    notifyListeners();
  }

  void _upsertOrder(ParcelOrderSummary order) {
    final copy = [..._orders];
    final index = copy.indexWhere((entry) => entry.id == order.id);
    if (index >= 0) {
      copy[index] = order;
    } else {
      copy.add(order);
    }
    _orders = _sortOrdersByCreatedAt(copy);
  }

  List<ParcelOrderSummary> _sortOrdersByCreatedAt(
    List<ParcelOrderSummary> list,
  ) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  String _readableError(Object error) {
    if (error is ParcelApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception:', '').trim();
  }

  _CachedParcelConfig? _readCachedConfig() {
    try {
      final cachedJson = CacheService.getData(_configCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) return null;
      final cachedAtRaw = decoded['cachedAt'];
      final dataRaw = decoded['data'];
      if (cachedAtRaw is! String || dataRaw is! Map) return null;

      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (cachedAt == null) return null;

      final config = ParcelConfigModel.fromJson(
        Map<String, dynamic>.from(dataRaw),
      );
      final isStale = DateTime.now().difference(cachedAt) > _configCacheMaxAge;
      return _CachedParcelConfig(config: config, isStale: isStale);
    } catch (e) {
      debugPrint('ParcelProvider: failed to read config cache: $e');
      return null;
    }
  }

  Future<void> _saveConfigToCache(ParcelConfigModel config) async {
    try {
      final payload = {
        'cachedAt': DateTime.now().toIso8601String(),
        'data': config.toJson(),
      };
      await CacheService.saveData(_configCacheKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('ParcelProvider: failed to save config cache: $e');
    }
  }
}

class _CachedParcelConfig {
  final ParcelConfigModel config;
  final bool isStale;

  const _CachedParcelConfig({required this.config, required this.isStale});
}
