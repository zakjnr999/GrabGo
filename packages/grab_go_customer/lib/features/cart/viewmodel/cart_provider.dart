import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/services/promo_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class CartProvider extends ChangeNotifier {
  final Map<CartItem, int> _cartItems = {};
  bool _isSyncing = false;
  bool _syncQueued = false;
  Completer<bool>? _syncCompleter;
  int _localMutationVersion = 0;
  double? _subtotal;
  double _deliveryFee = 0.0;
  double _serviceFee = 0.0;
  double _originalDeliveryFee = 0.0;
  double _originalServiceFee = 0.0;
  double _tax = 0.0;
  double _rainFee = 0.0;
  String? _subscriptionTier;
  double _subscriptionDeliveryDiscount = 0.0;
  double _subscriptionServiceFeeDiscount = 0.0;
  double _creditsApplied = 0.0;
  double _availableCredits = 0.0;
  double? _total;
  int? _estimatedDeliveryMin;
  int? _estimatedDeliveryMax;
  int? _estimatedDeliveryFirstMin;
  int? _estimatedDeliveryFirstMax;
  int? _estimatedDeliveryCompletionMin;
  int? _estimatedDeliveryCompletionMax;
  bool _useCredits = true;
  bool _hasPricingFromBackend = false;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  String? _cartType;
  String _fulfillmentMode = 'delivery';
  Map<String, dynamic>? _scheduleAvailability;
  final Map<String, _VendorGroupEta> _vendorGroupEtasByKey = {};
  final Map<String, String> _cartItemIdsByKey = {};
  final Set<String> _pendingItemOps = {};
  bool _giftOrderEnabled = false;
  String _giftRecipientNameDraft = '';
  String _giftRecipientPhoneDraft = '';
  String _giftNoteDraft = '';
  final PromoService _promoService = PromoService();
  String? _appliedPromoCode;
  String? _promoType;
  double _promoDiscount = 0.0;
  String? _promoErrorMessage;

  Map<CartItem, int> get cartItems => _cartItems;
  bool get isSyncing => _isSyncing;
  double get subtotal => _subtotal ?? totalPrice;
  double get deliveryFee => _deliveryFee;
  double get serviceFee => _serviceFee;
  double get originalDeliveryFee => _originalDeliveryFee;
  double get originalServiceFee => _originalServiceFee;
  double get tax => _tax;
  double get rainFee => _rainFee;
  String? get subscriptionTier => _subscriptionTier;
  double get subscriptionDeliveryDiscount => _subscriptionDeliveryDiscount;
  double get subscriptionServiceFeeDiscount => _subscriptionServiceFeeDiscount;
  double get subscriptionTotalDiscount =>
      _subscriptionDeliveryDiscount + _subscriptionServiceFeeDiscount;
  double get creditsApplied => _creditsApplied;
  double get availableCredits => _availableCredits;
  double get total =>
      _total ?? (subtotal + deliveryFee + serviceFee + tax + rainFee);
  int? get estimatedDeliveryMin => _estimatedDeliveryMin;
  int? get estimatedDeliveryMax => _estimatedDeliveryMax;
  int? get estimatedDeliveryFirstMin => _estimatedDeliveryFirstMin;
  int? get estimatedDeliveryFirstMax => _estimatedDeliveryFirstMax;
  int? get estimatedDeliveryCompletionMin => _estimatedDeliveryCompletionMin;
  int? get estimatedDeliveryCompletionMax => _estimatedDeliveryCompletionMax;
  bool get useCredits => _useCredits;
  bool get isPricingLoading => _isSyncing && !_hasPricingFromBackend;
  bool get hasPendingCartOperations => _pendingItemOps.isNotEmpty;
  bool get isCartInteractionLocked => hasPendingCartOperations;
  String get fulfillmentMode => _fulfillmentMode;
  Map<String, String> get vendorEtaLabelsByGroupKey => _vendorGroupEtasByKey
      .map((key, value) => MapEntry(key, _formatEtaWindow(value)));
  int get providerCount => _cartItems.keys
      .map((item) => '${item.itemType}:${item.providerId}')
      .where((key) => key.trim().isNotEmpty)
      .toSet()
      .length;
  Map<String, dynamic>? get scheduleAvailability =>
      _scheduleAvailability == null
      ? null
      : Map<String, dynamic>.unmodifiable(_scheduleAvailability!);
  bool get isGiftOrderDraftEnabled => _giftOrderEnabled;
  String get giftRecipientNameDraft => _giftRecipientNameDraft;
  String get giftRecipientPhoneDraft => _giftRecipientPhoneDraft;
  String get giftNoteDraft => _giftNoteDraft;
  String? get appliedPromoCode => _appliedPromoCode;
  String? get promoType => _promoType;
  double get promoDiscount => _promoDiscount;
  String? get promoErrorMessage => _promoErrorMessage;
  bool isItemOperationPending(CartItem item) =>
      _pendingItemOps.contains(_itemKey(item));

  bool hasItemInCart(CartItem item, {bool includeFoodCustomizations = false}) =>
      getItemQuantity(
        item,
        includeFoodCustomizations: includeFoodCustomizations,
      ) >
      0;

  int getItemQuantity(CartItem item, {bool includeFoodCustomizations = false}) {
    final entries = _findMatchingCartEntries(
      item,
      includeFoodCustomizations: includeFoodCustomizations,
    );
    if (entries.isEmpty) return 0;
    return entries.fold<int>(0, (sum, entry) => sum + entry.value);
  }

  bool isItemOperationPendingForDisplay(
    CartItem item, {
    bool includeFoodCustomizations = false,
  }) {
    if (isItemOperationPending(item)) return true;
    if (!includeFoodCustomizations || item is! FoodItem) return false;

    final entries = _findMatchingCartEntries(
      item,
      includeFoodCustomizations: true,
    );
    for (final entry in entries) {
      if (isItemOperationPending(entry.key)) {
        return true;
      }
    }
    return false;
  }

  CartItem? resolveItemForCartAction(
    CartItem item, {
    bool includeFoodCustomizations = false,
  }) {
    if (_cartItems.containsKey(item)) return item;
    final entries = _findMatchingCartEntries(
      item,
      includeFoodCustomizations: includeFoodCustomizations,
    );
    if (entries.isEmpty) return null;
    return entries.first.key;
  }

  List<MapEntry<CartItem, int>> _findMatchingCartEntries(
    CartItem item, {
    bool includeFoodCustomizations = false,
  }) {
    final exactQuantity = _cartItems[item];
    if (exactQuantity != null) {
      return [MapEntry(item, exactQuantity)];
    }
    if (!includeFoodCustomizations || item is! FoodItem) {
      return const <MapEntry<CartItem, int>>[];
    }

    final matches = <MapEntry<CartItem, int>>[];
    for (final entry in _cartItems.entries) {
      if (_isSameFoodBaseItem(item, entry.key)) {
        matches.add(entry);
      }
    }
    return matches;
  }

  bool _isSameFoodBaseItem(CartItem current, CartItem other) {
    if (current is! FoodItem || other is! FoodItem) return false;

    if (current.id.isNotEmpty && other.id.isNotEmpty) {
      return current.id == other.id;
    }

    return current.name == other.name &&
        current.restaurantId == other.restaurantId;
  }

  Future<String?> replaceFoodCustomizationInCart({
    required FoodItem currentItem,
    required FoodItem updatedItem,
  }) async {
    final oldKey = _itemKey(currentItem);
    final newKey = _itemKey(updatedItem);
    if (oldKey == newKey) return null;

    if (_pendingItemOps.contains(oldKey) || _pendingItemOps.contains(newKey)) {
      return 'Please wait for the current cart update to finish.';
    }

    final currentQuantity = _cartItems[currentItem];
    if (currentQuantity == null || currentQuantity <= 0) {
      return 'Item not found in cart.';
    }

    final previousItems = Map<CartItem, int>.from(_cartItems);
    final previousItemIds = Map<String, String>.from(_cartItemIdsByKey);
    final previousCartType = _cartType;

    Future<void> rollbackLocalState() async {
      _cartItems
        ..clear()
        ..addAll(previousItems);
      _cartItemIdsByKey
        ..clear()
        ..addAll(previousItemIds);
      _cartType = previousCartType;
      _markLocalCartMutated();
      _recalculateLocalPricing();
      await _saveCart();
      notifyListeners();
    }

    _pendingItemOps
      ..add(oldKey)
      ..add(newKey);
    notifyListeners();

    try {
      _cartItems.remove(currentItem);
      final mergedQuantity = (_cartItems[updatedItem] ?? 0) + currentQuantity;
      _cartItems[updatedItem] = mergedQuantity;
      _cartItemIdsByKey.remove(oldKey);
      _markLocalCartMutated();
      _recalculateLocalPricing();
      _saveCart();
      notifyListeners();

      var oldCartItemId = _cartItemIdsByKey[oldKey];
      oldCartItemId ??= await _ensureCartItemId(oldKey, forceRefresh: true);
      if (oldCartItemId == null) {
        await rollbackLocalState();
        await syncFromBackend();
        return 'Could not update item customization. Please try again.';
      }

      var removeError = await _removeFromBackend(oldCartItemId);
      if (_isItemNotFoundInCartError(removeError)) {
        final freshCartItemId = await _ensureCartItemId(
          oldKey,
          forceRefresh: true,
        );
        if (freshCartItemId != null) {
          removeError = await _removeFromBackend(freshCartItemId);
        } else {
          removeError = null;
        }
      }
      if (removeError != null) {
        await rollbackLocalState();
        await syncFromBackend();
        return removeError;
      }

      final addError = await _addToBackend(updatedItem, currentQuantity);
      if (addError != null) {
        await _addToBackend(currentItem, currentQuantity);
        await rollbackLocalState();
        await syncFromBackend();
        return addError;
      }

      await syncFromBackend();
      return null;
    } catch (e) {
      await rollbackLocalState();
      await syncFromBackend();
      return e.toString();
    } finally {
      _pendingItemOps
        ..remove(oldKey)
        ..remove(newKey);
      notifyListeners();
    }
  }

  String buildVendorGroupKey({
    required String itemType,
    required String providerId,
    required String providerName,
  }) {
    final normalizedItemType = itemType.trim();
    final normalizedProviderId = providerId.trim();
    final normalizedProviderName = providerName.trim();
    final providerKey = normalizedProviderId.isNotEmpty
        ? normalizedProviderId
        : '$normalizedItemType:${normalizedProviderName.toLowerCase()}';
    return '$normalizedItemType:$providerKey';
  }

  String? etaLabelForVendorGroupKey(String groupKey) {
    final eta = _vendorGroupEtasByKey[groupKey];
    if (eta == null) return null;
    return _formatEtaWindow(eta);
  }

  String? etaLabelForVendor({
    required String itemType,
    required String providerId,
    required String providerName,
  }) {
    final key = buildVendorGroupKey(
      itemType: itemType,
      providerId: providerId,
      providerName: providerName,
    );
    return etaLabelForVendorGroupKey(key);
  }

  String _formatEtaWindow(_VendorGroupEta eta) {
    var min = eta.minMinutes;
    var max = eta.maxMinutes;
    if (min == max) {
      const padding = 5;
      min = math.max(5, min - padding);
      max = max + padding;
    }
    return '$min-$max mins';
  }

  String? _mapCartTypeToItemType(String? cartType) {
    final normalized = cartType?.trim().toLowerCase();
    if (normalized == 'food') return 'Food';
    if (normalized == 'grocery') return 'GroceryItem';
    if (normalized == 'pharmacy') return 'PharmacyItem';
    if (normalized == 'grabmart') return 'GrabMartItem';
    return null;
  }

  String? _inferItemTypeFromRawGroup(Map<String, dynamic> group) {
    final fromCartType = _mapCartTypeToItemType(group['cartType']?.toString());
    if (fromCartType != null) return fromCartType;

    final rawItems = group['items'];
    if (rawItems is! List || rawItems.isEmpty) return null;
    final firstRawItem = rawItems.first;
    if (firstRawItem is! Map) return null;
    final firstItem = Map<String, dynamic>.from(firstRawItem);
    final directType = firstItem['itemType']?.toString();
    if (directType != null && directType.trim().isNotEmpty) {
      return directType.trim();
    }
    if (firstItem['food'] != null) return 'Food';
    if (firstItem['groceryItem'] != null) return 'GroceryItem';
    if (firstItem['pharmacyItem'] != null) return 'PharmacyItem';
    if (firstItem['grabMartItem'] != null) return 'GrabMartItem';
    return null;
  }

  _ProviderIdentity _extractProviderIdentityFromRawGroup(
    Map<String, dynamic> group,
    String itemType,
  ) {
    String providerId = '';
    String providerName = 'Vendor';

    final rawItems = group['items'];
    Map<String, dynamic>? firstItem;
    if (rawItems is List && rawItems.isNotEmpty && rawItems.first is Map) {
      firstItem = Map<String, dynamic>.from(rawItems.first as Map);
    }

    if (itemType == 'Food') {
      providerId = group['restaurantId']?.toString() ?? '';
      final restaurant = group['restaurant'];
      if (restaurant is Map) {
        providerName =
            restaurant['restaurantName']?.toString() ??
            restaurant['restaurant_name']?.toString() ??
            restaurant['name']?.toString() ??
            providerName;
      }

      final itemDataRaw = firstItem?['itemId'] ?? firstItem?['food'];
      if (itemDataRaw is Map) {
        final itemData = Map<String, dynamic>.from(itemDataRaw);
        final restaurantData = itemData['restaurant'];
        if (restaurantData is Map) {
          providerId = providerId.isNotEmpty
              ? providerId
              : (restaurantData['_id']?.toString() ??
                    restaurantData['id']?.toString() ??
                    '');
          providerName =
              restaurantData['restaurantName']?.toString() ??
              restaurantData['restaurant_name']?.toString() ??
              restaurantData['name']?.toString() ??
              providerName;
        } else if (restaurantData is String && providerId.isEmpty) {
          providerId = restaurantData;
        }
        providerId = providerId.isNotEmpty
            ? providerId
            : (itemData['restaurantId']?.toString() ??
                  firstItem?['restaurantId']?.toString() ??
                  '');
        providerName = itemData['restaurantName']?.toString() ?? providerName;
      }
    } else if (itemType == 'GroceryItem') {
      providerId = group['groceryStoreId']?.toString() ?? '';
      final store = group['groceryStore'];
      if (store is Map) {
        providerName =
            store['storeName']?.toString() ??
            store['store_name']?.toString() ??
            store['name']?.toString() ??
            providerName;
      }

      final itemDataRaw = firstItem?['itemId'] ?? firstItem?['groceryItem'];
      if (itemDataRaw is Map) {
        final itemData = Map<String, dynamic>.from(itemDataRaw);
        final storeData = itemData['store'];
        if (storeData is Map) {
          providerId = providerId.isNotEmpty
              ? providerId
              : (storeData['_id']?.toString() ??
                    storeData['id']?.toString() ??
                    '');
          providerName =
              storeData['storeName']?.toString() ??
              storeData['store_name']?.toString() ??
              storeData['name']?.toString() ??
              providerName;
        } else if (storeData is String && providerId.isEmpty) {
          providerId = storeData;
        }
        providerId = providerId.isNotEmpty
            ? providerId
            : (itemData['storeId']?.toString() ??
                  firstItem?['groceryStoreId']?.toString() ??
                  '');
      }
    } else if (itemType == 'PharmacyItem') {
      providerId = group['pharmacyStoreId']?.toString() ?? '';
      final store = group['pharmacyStore'];
      if (store is Map) {
        providerName =
            store['storeName']?.toString() ??
            store['store_name']?.toString() ??
            store['name']?.toString() ??
            providerName;
      }

      final itemDataRaw = firstItem?['itemId'] ?? firstItem?['pharmacyItem'];
      if (itemDataRaw is Map) {
        final itemData = Map<String, dynamic>.from(itemDataRaw);
        final storeData = itemData['store'];
        if (storeData is Map) {
          providerId = providerId.isNotEmpty
              ? providerId
              : (storeData['_id']?.toString() ??
                    storeData['id']?.toString() ??
                    '');
          providerName =
              storeData['storeName']?.toString() ??
              storeData['store_name']?.toString() ??
              storeData['name']?.toString() ??
              providerName;
        } else if (storeData is String && providerId.isEmpty) {
          providerId = storeData;
        }
        providerId = providerId.isNotEmpty
            ? providerId
            : (itemData['storeId']?.toString() ??
                  firstItem?['pharmacyStoreId']?.toString() ??
                  '');
      }
    } else if (itemType == 'GrabMartItem') {
      providerId = group['grabMartStoreId']?.toString() ?? '';
      final store = group['grabMartStore'];
      if (store is Map) {
        providerName =
            store['storeName']?.toString() ??
            store['store_name']?.toString() ??
            store['name']?.toString() ??
            providerName;
      }

      final itemDataRaw = firstItem?['itemId'] ?? firstItem?['grabMartItem'];
      if (itemDataRaw is Map) {
        final itemData = Map<String, dynamic>.from(itemDataRaw);
        final storeData = itemData['store'];
        if (storeData is Map) {
          providerId = providerId.isNotEmpty
              ? providerId
              : (storeData['_id']?.toString() ??
                    storeData['id']?.toString() ??
                    '');
          providerName =
              storeData['storeName']?.toString() ??
              storeData['store_name']?.toString() ??
              storeData['name']?.toString() ??
              providerName;
        } else if (storeData is String && providerId.isEmpty) {
          providerId = storeData;
        }
        providerId = providerId.isNotEmpty
            ? providerId
            : (itemData['storeId']?.toString() ??
                  firstItem?['grabMartStoreId']?.toString() ??
                  '');
      }
    }

    providerName = providerName.trim().isNotEmpty
        ? providerName.trim()
        : 'Vendor';
    providerId = providerId.trim();
    return _ProviderIdentity(id: providerId, name: providerName);
  }

  _VendorGroupEta? _extractEtaFromPricing(dynamic rawPricing) {
    if (rawPricing is! Map) return null;
    final pricing = Map<String, dynamic>.from(rawPricing);
    final minMinutes = (pricing['estimatedDeliveryMin'] as num?)?.toInt();
    final maxMinutes = (pricing['estimatedDeliveryMax'] as num?)?.toInt();
    if (minMinutes == null || maxMinutes == null) return null;
    if (minMinutes <= 0 || maxMinutes <= 0) return null;
    return _VendorGroupEta(minMinutes: minMinutes, maxMinutes: maxMinutes);
  }

  String _normalizeFulfillmentMode(String? mode) {
    if (mode == null) return 'delivery';
    return mode.toLowerCase() == 'pickup' ? 'pickup' : 'delivery';
  }

  CartProvider() {
    // Load cart data asynchronously without blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCart();
    });
  }

  Future<void> _loadCart() async {
    try {
      // First load from local cache for immediate UI
      final cartList = CacheService.getCartItems();
      _cartItems.clear();
      if (cartList.isNotEmpty) {
        _fulfillmentMode = _normalizeFulfillmentMode(
          cartList.first['fulfillmentMode'] as String?,
        );
      }

      for (var item in cartList) {
        final itemData = item['item'];
        final quantity = item['quantity'] as int;
        final cachedItemType = item['itemType'] as String?; // Get cached type

        // Detect item type from cached data
        CartItem? cartItem;

        // Use cached itemType if available, otherwise detect from fields
        if (cachedItemType == 'GroceryItem') {
          cartItem = GroceryItem.fromJson(itemData);
        } else if (cachedItemType == 'PharmacyItem') {
          cartItem = PharmacyItem.fromJson(itemData);
        } else if (cachedItemType == 'GrabMartItem') {
          cartItem = GrabMartItem.fromJson(itemData);
        } else if (itemData['unit'] != null || itemData['brand'] != null) {
          cartItem = GroceryItem.fromJson(itemData);
        } else {
          // Default to FoodItem
          cartItem = FoodItem.fromJson(itemData);
        }

        _cartItems[cartItem] = quantity;
      }

      _cartType = _inferCartType();
      _recalculateLocalPricing();
      notifyListeners();

      // Then sync from backend in background
      await syncFromBackend();
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  /// Sync cart from backend
  Future<bool> syncFromBackend() async {
    if (_isSyncing) {
      _syncQueued = true;
      final currentSync = _syncCompleter;
      if (currentSync != null) {
        return currentSync.future;
      }
      return true;
    }
    _isSyncing = true;
    final activeSyncCompleter = Completer<bool>();
    _syncCompleter = activeSyncCompleter;
    notifyListeners();

    var anySyncSucceeded = false;

    try {
      do {
        _syncQueued = false;
        final syncSucceeded = await _syncFromBackendOnce();
        anySyncSucceeded = anySyncSucceeded || syncSucceeded;
      } while (_syncQueued);

      return anySyncSucceeded;
    } finally {
      _isSyncing = false;
      _syncCompleter = null;
      if (!activeSyncCompleter.isCompleted) {
        activeSyncCompleter.complete(anySyncSucceeded);
      }
      notifyListeners();
    }
  }

  Future<bool> _syncFromBackendOnce() async {
    var syncSucceeded = false;
    final mutationVersionAtStart = _localMutationVersion;
    final parsedVendorGroupEtas = <String, _VendorGroupEta>{};

    try {
      final previousOpenById = <String, bool>{};
      final previousOpenByProviderId = <String, bool>{};
      for (final item in _cartItems.keys) {
        if (item is FoodItem && item.id.isNotEmpty) {
          previousOpenById[item.id] = item.isRestaurantOpen;
        }
        if (item is FoodItem && item.restaurantId.isNotEmpty) {
          previousOpenByProviderId[item.restaurantId] = item.isRestaurantOpen;
        }
      }
      Map<String, dynamic>? cartData;
      Object? syncError;

      try {
        final groupsResponse = await cartApiService.getCartGroups(
          fulfillmentMode: _fulfillmentMode,
          lat: _deliveryLatitude,
          lng: _deliveryLongitude,
          useCredits: _useCredits,
          promoCode: _appliedPromoCode,
        );
        final groupsBody = groupsResponse.body;
        if (groupsResponse.isSuccessful &&
            groupsBody != null &&
            groupsBody['success'] == true) {
          syncSucceeded = true;
          final rawGroups = groupsBody['groups'];
          final flattenedItems = <Map<String, dynamic>>[];
          Map<String, dynamic>? singleGroupScheduleAvailability;
          String? groupedFulfillmentMode;

          if (rawGroups is List) {
            for (final rawGroup in rawGroups) {
              if (rawGroup is! Map) continue;
              final group = Map<String, dynamic>.from(rawGroup);
              final groupItemType = _inferItemTypeFromRawGroup(group);
              final groupEta = _extractEtaFromPricing(group['pricing']);
              if (groupItemType != null && groupEta != null) {
                final provider = _extractProviderIdentityFromRawGroup(
                  group,
                  groupItemType,
                );
                final groupKey = buildVendorGroupKey(
                  itemType: groupItemType,
                  providerId: provider.id,
                  providerName: provider.name,
                );
                parsedVendorGroupEtas[groupKey] = groupEta;
              }
              groupedFulfillmentMode =
                  groupedFulfillmentMode ??
                  group['fulfillmentMode']?.toString();
              if (rawGroups.length == 1) {
                final scheduleAvailability = group['scheduleAvailability'];
                if (scheduleAvailability is Map) {
                  singleGroupScheduleAvailability = Map<String, dynamic>.from(
                    scheduleAvailability,
                  );
                }
              }

              final groupItems = group['items'];
              if (groupItems is! List) continue;
              final groupMode = _normalizeFulfillmentMode(
                group['fulfillmentMode']?.toString(),
              );

              for (final rawItem in groupItems) {
                if (rawItem is! Map) continue;
                final item = Map<String, dynamic>.from(rawItem);
                item['fulfillmentMode'] = groupMode;
                flattenedItems.add(item);
              }
            }
          }

          final summary = groupsBody['summary'];
          cartData = {
            'items': flattenedItems,
            'fulfillmentMode': groupedFulfillmentMode ?? _fulfillmentMode,
            'scheduleAvailability': singleGroupScheduleAvailability,
            'pricing': summary is Map
                ? Map<String, dynamic>.from(summary)
                : null,
          };
        }
      } catch (e) {
        syncError = e;
      }

      if (cartData == null) {
        final response = await cartApiService.getCart(
          type: _cartType ?? _inferCartType(),
          fulfillmentMode: _fulfillmentMode,
          lat: _deliveryLatitude,
          lng: _deliveryLongitude,
          useCredits: _useCredits,
          promoCode: _appliedPromoCode,
        );

        if (response.isSuccessful && response.body != null) {
          syncSucceeded = true;
          final backendCart = response.body!['cart'];
          if (backendCart is Map) {
            cartData = Map<String, dynamic>.from(backendCart);
          }
        } else {
          syncError = response.error;
        }
      }

      if (cartData == null) {
        _scheduleAvailability = null;
        _vendorGroupEtasByKey.clear();
        debugPrint('Error syncing cart from backend: $syncError');
        return syncSucceeded;
      }

      final rawItems = cartData['items'];
      if (rawItems is! List) {
        _scheduleAvailability = null;
        _vendorGroupEtasByKey.clear();
        _cartItems.clear();
        _cartItemIdsByKey.clear();
        _cartType = null;
        _applyPricing(null);
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        await _saveCart();
        notifyListeners();
        return syncSucceeded;
      }

      {
        final shouldSkipApplyingSnapshot =
            mutationVersionAtStart != _localMutationVersion;
        if (shouldSkipApplyingSnapshot) {
          _syncQueued = true;
          return syncSucceeded;
        }

        _scheduleAvailability = _parseScheduleAvailability(
          cartData['scheduleAvailability'],
        );
        _vendorGroupEtasByKey
          ..clear()
          ..addAll(parsedVendorGroupEtas);
        final previousMode = _normalizeFulfillmentMode(_fulfillmentMode);
        final previousItemOrderStableKeys = _cartItems.keys
            .map(_itemStableKey)
            .toList(growable: false);
        _fulfillmentMode = _normalizeFulfillmentMode(
          cartData['fulfillmentMode']?.toString(),
        );
        final parsedEntriesByStableKey = <String, MapEntry<CartItem, int>>{};
        final parsedEntryStableKeysInOrder = <String>[];
        _cartItems.clear();
        _cartItemIdsByKey.clear();

        for (final rawItem in rawItems) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);

          final itemData =
              item['itemId'] ??
              item['food'] ??
              item['groceryItem'] ??
              item['pharmacyItem'] ??
              item['grabMartItem'];
          if (itemData == null || itemData is! Map) continue;

          String? itemType = item['itemType']?.toString();
          if (itemType == null || itemType.isEmpty) {
            if (item['food'] != null) itemType = 'Food';
            if (item['groceryItem'] != null) itemType = 'GroceryItem';
            if (item['pharmacyItem'] != null) itemType = 'PharmacyItem';
            if (item['grabMartItem'] != null) itemType = 'GrabMartItem';
          }
          if (itemType == null || itemType.isEmpty) continue;

          CartItem? cartItem;

          if (itemType == 'Food') {
            final itemDataMap = Map<String, dynamic>.from(itemData);
            final restaurantData = itemDataMap['restaurant'];
            String? providerId;
            if (restaurantData is Map) {
              providerId =
                  restaurantData['_id']?.toString() ??
                  restaurantData['id']?.toString();
            }
            providerId ??=
                itemDataMap['restaurantId']?.toString() ??
                itemDataMap['restaurant']?.toString();
            providerId ??= item['restaurantId']?.toString();

            final fallbackOpen =
                previousOpenById[itemDataMap['_id']?.toString() ??
                    itemDataMap['id']?.toString() ??
                    item['foodId']?.toString() ??
                    item['itemId']?.toString() ??
                    ''] ??
                (providerId != null
                    ? previousOpenByProviderId[providerId]
                    : null);

            cartItem = _createFoodItemFromBackend(
              itemDataMap,
              item,
              fallbackIsOpen: fallbackOpen,
            );
          } else if (itemType == 'GroceryItem') {
            cartItem = _createGroceryItemFromBackend(
              Map<String, dynamic>.from(itemData),
              item,
            );
          } else if (itemType == 'PharmacyItem') {
            cartItem = _createPharmacyItemFromBackend(
              Map<String, dynamic>.from(itemData),
              item,
            );
          } else if (itemType == 'GrabMartItem') {
            cartItem = _createGrabMartItemFromBackend(
              Map<String, dynamic>.from(itemData),
              item,
            );
          } else {
            debugPrint('Unknown item type: $itemType');
            continue;
          }

          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final stableKey = _itemStableKey(cartItem);
          parsedEntriesByStableKey[stableKey] = MapEntry(cartItem, quantity);
          parsedEntryStableKeysInOrder.add(stableKey);

          final cartItemId = item['id']?.toString();
          final itemKey = _itemKeyFromBackend(
            itemType,
            Map<String, dynamic>.from(itemData),
            item,
          );
          if (cartItemId != null && itemKey != null) {
            _cartItemIdsByKey[itemKey] = cartItemId;
          }
        }

        final shouldPreserveOrder = previousMode == _fulfillmentMode;
        if (shouldPreserveOrder) {
          for (final stableKey in previousItemOrderStableKeys) {
            final entry = parsedEntriesByStableKey.remove(stableKey);
            if (entry == null) continue;
            _cartItems[entry.key] = entry.value;
          }
        }
        for (final stableKey in parsedEntryStableKeysInOrder) {
          final entry = parsedEntriesByStableKey.remove(stableKey);
          if (entry == null) continue;
          _cartItems[entry.key] = entry.value;
        }

        _cartType = _cartItems.isEmpty ? null : _inferCartType();
        final pricing = cartData['pricing'];
        if (pricing is Map) {
          _applyPricing(Map<String, dynamic>.from(pricing));
        } else {
          _recalculateLocalPricing();
        }
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        await _saveCart();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing cart from backend: $e');
      // Continue with local cache on error
    }
    return syncSucceeded;
  }

  void _applyPricing(Map<String, dynamic>? pricing) {
    if (pricing == null) {
      _subtotal = null;
      _deliveryFee = 0.0;
      _serviceFee = 0.0;
      _originalDeliveryFee = 0.0;
      _originalServiceFee = 0.0;
      _tax = 0.0;
      _rainFee = 0.0;
      _appliedPromoCode = null;
      _promoType = null;
      _promoDiscount = 0.0;
      _promoErrorMessage = null;
      _subscriptionTier = null;
      _subscriptionDeliveryDiscount = 0.0;
      _subscriptionServiceFeeDiscount = 0.0;
      _creditsApplied = 0.0;
      _availableCredits = 0.0;
      _total = null;
      _estimatedDeliveryMin = null;
      _estimatedDeliveryMax = null;
      _estimatedDeliveryFirstMin = null;
      _estimatedDeliveryFirstMax = null;
      _estimatedDeliveryCompletionMin = null;
      _estimatedDeliveryCompletionMax = null;
      _hasPricingFromBackend = false;
      return;
    }

    _subtotal = (pricing['subtotal'] as num?)?.toDouble();
    _deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    _serviceFee = (pricing['serviceFee'] as num?)?.toDouble() ?? 0.0;
    _originalDeliveryFee =
        (pricing['originalDeliveryFee'] as num?)?.toDouble() ??
        _deliveryFee +
            ((pricing['subscriptionDeliveryDiscount'] as num?)?.toDouble() ??
                0.0);
    _originalServiceFee =
        (pricing['originalServiceFee'] as num?)?.toDouble() ??
        _serviceFee +
            ((pricing['subscriptionServiceFeeDiscount'] as num?)?.toDouble() ??
                0.0);
    _tax = (pricing['tax'] as num?)?.toDouble() ?? 0.0;
    _rainFee = (pricing['rainFee'] as num?)?.toDouble() ?? 0.0;
    final promoCodeRaw = pricing['promoCode']?.toString().trim();
    _appliedPromoCode = (promoCodeRaw == null || promoCodeRaw.isEmpty)
        ? null
        : promoCodeRaw.toUpperCase();
    final promoTypeRaw = pricing['promoType']?.toString().trim();
    _promoType = (promoTypeRaw == null || promoTypeRaw.isEmpty)
        ? null
        : promoTypeRaw;
    _promoDiscount = (pricing['promoDiscount'] as num?)?.toDouble() ?? 0.0;
    final promoValidationMessageRaw = pricing['promoValidationMessage']
        ?.toString()
        .trim();
    _promoErrorMessage =
        (promoValidationMessageRaw == null || promoValidationMessageRaw.isEmpty)
        ? null
        : promoValidationMessageRaw;
    _subscriptionTier = pricing['subscriptionTier']?.toString();
    _subscriptionDeliveryDiscount =
        (pricing['subscriptionDeliveryDiscount'] as num?)?.toDouble() ?? 0.0;
    _subscriptionServiceFeeDiscount =
        (pricing['subscriptionServiceFeeDiscount'] as num?)?.toDouble() ?? 0.0;
    _creditsApplied = (pricing['creditsApplied'] as num?)?.toDouble() ?? 0.0;
    _availableCredits =
        (pricing['availableBalance'] as num?)?.toDouble() ??
        (pricing['creditBalance'] as num?)?.toDouble() ??
        0.0;
    _total = (pricing['total'] as num?)?.toDouble();
    _estimatedDeliveryMin = (pricing['estimatedDeliveryMin'] as num?)?.toInt();
    _estimatedDeliveryMax = (pricing['estimatedDeliveryMax'] as num?)?.toInt();
    _estimatedDeliveryFirstMin = (pricing['estimatedDeliveryFirstMin'] as num?)
        ?.toInt();
    _estimatedDeliveryFirstMax = (pricing['estimatedDeliveryFirstMax'] as num?)
        ?.toInt();
    _estimatedDeliveryCompletionMin =
        (pricing['estimatedDeliveryCompletionMin'] as num?)?.toInt();
    _estimatedDeliveryCompletionMax =
        (pricing['estimatedDeliveryCompletionMax'] as num?)?.toInt();

    _estimatedDeliveryCompletionMin ??= _estimatedDeliveryMin;
    _estimatedDeliveryCompletionMax ??= _estimatedDeliveryMax;
    if (_estimatedDeliveryFirstMin == null &&
        _estimatedDeliveryFirstMax == null &&
        providerCount <= 1) {
      _estimatedDeliveryFirstMin = _estimatedDeliveryMin;
      _estimatedDeliveryFirstMax = _estimatedDeliveryMax;
    }
    _hasPricingFromBackend = true;

    if (_availableCredits <= 0 && _useCredits) {
      _useCredits = false;
    }
  }

  Map<String, dynamic>? _parseScheduleAvailability(dynamic raw) {
    if (raw is! Map) return null;
    final parsed = Map<String, dynamic>.from(raw);
    final openingHoursRaw = parsed['openingHours'];
    if (openingHoursRaw is List) {
      parsed['openingHours'] = openingHoursRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      parsed['openingHours'] = const <Map<String, dynamic>>[];
    }
    return parsed;
  }

  void _recalculateLocalPricing() {
    _subtotal = totalPrice;
    _promoType = null;
    _promoDiscount = 0.0;
    if (_cartItems.isEmpty) {
      _appliedPromoCode = null;
      _promoErrorMessage = null;
    }
    _subscriptionTier = null;
    _subscriptionDeliveryDiscount = 0.0;
    _subscriptionServiceFeeDiscount = 0.0;
    _originalDeliveryFee = _deliveryFee;
    _originalServiceFee = _serviceFee;
    _total = _subtotal! + _deliveryFee + _serviceFee + _tax + _rainFee;
    _hasPricingFromBackend = false;
  }

  bool _resetGiftOrderDraft({bool notify = true}) {
    final hadGiftDraft =
        _giftOrderEnabled ||
        _giftRecipientNameDraft.isNotEmpty ||
        _giftRecipientPhoneDraft.isNotEmpty ||
        _giftNoteDraft.isNotEmpty;
    if (!hadGiftDraft) return false;

    _giftOrderEnabled = false;
    _giftRecipientNameDraft = '';
    _giftRecipientPhoneDraft = '';
    _giftNoteDraft = '';

    if (notify) {
      notifyListeners();
    }
    return true;
  }

  void _resetGiftOrderDraftIfCartIsEmpty({bool notify = true}) {
    final shouldReset =
        _cartItems.isEmpty ||
        _normalizeFulfillmentMode(_fulfillmentMode) == 'pickup' ||
        providerCount > 1;
    if (!shouldReset) return;
    _resetGiftOrderDraft(notify: notify);
  }

  void setGiftOrderDraftEnabled(bool enabled) {
    if (_giftOrderEnabled == enabled) return;
    _giftOrderEnabled = enabled;
    notifyListeners();
  }

  void setGiftOrderDraft({
    required bool enabled,
    required String recipientName,
    required String recipientPhone,
    required String giftNote,
    bool notify = true,
  }) {
    final normalizedName = recipientName.trim();
    final normalizedPhone = recipientPhone.trim();
    final normalizedNote = giftNote.trim();
    final changed =
        _giftOrderEnabled != enabled ||
        _giftRecipientNameDraft != normalizedName ||
        _giftRecipientPhoneDraft != normalizedPhone ||
        _giftNoteDraft != normalizedNote;

    if (!changed) return;

    _giftOrderEnabled = enabled;
    _giftRecipientNameDraft = normalizedName;
    _giftRecipientPhoneDraft = normalizedPhone;
    _giftNoteDraft = normalizedNote;

    if (notify) {
      notifyListeners();
    }
  }

  String _itemKey(CartItem item) {
    final mode = _normalizeFulfillmentMode(_fulfillmentMode);
    return '$mode:${_itemStableKey(item)}';
  }

  String? _itemKeyFromBackend(
    String? itemType,
    Map<String, dynamic> itemData,
    Map<String, dynamic> cartItem,
  ) {
    if (itemType == null) return null;
    final id =
        itemData['_id']?.toString() ??
        itemData['id']?.toString() ??
        cartItem['foodId']?.toString() ??
        cartItem['groceryItemId']?.toString() ??
        cartItem['pharmacyItemId']?.toString() ??
        cartItem['grabMartItemId']?.toString() ??
        cartItem['itemId']?.toString();

    if (id == null || id.isEmpty) return null;
    final mode = _normalizeFulfillmentMode(
      cartItem['fulfillmentMode']?.toString() ?? _fulfillmentMode,
    );
    final customizationKey = cartItem['customizationKey']?.toString();
    if (customizationKey != null && customizationKey.trim().isNotEmpty) {
      return '$mode:$itemType:$id:${customizationKey.trim()}';
    }
    return '$mode:$itemType:$id';
  }

  String _itemStableKey(CartItem item) {
    if (item is FoodItem) {
      final customizationKey = item.cartCustomizationKey?.trim();
      if (customizationKey != null && customizationKey.isNotEmpty) {
        return '${item.itemType}:${item.id}:$customizationKey';
      }
    }
    final id = item.id;
    if (id.isNotEmpty) {
      return '${item.itemType}:$id';
    }
    return '${item.itemType}:${item.name}:${item.providerId}';
  }

  String? _inferCartType() {
    if (_cartItems.isEmpty) return _cartType;

    final itemType = _cartItems.keys.first.itemType;
    if (itemType == 'Food') return 'food';
    if (itemType == 'GroceryItem') return 'grocery';
    if (itemType == 'PharmacyItem') return 'pharmacy';
    if (itemType == 'GrabMartItem') return 'grabmart';
    return _cartType;
  }

  Future<void> setFulfillmentMode(String mode) async {
    final normalizedMode = _normalizeFulfillmentMode(mode);
    if (_fulfillmentMode == normalizedMode) return;

    _fulfillmentMode = normalizedMode;
    _cartItems.clear();
    _cartItemIdsByKey.clear();
    _vendorGroupEtasByKey.clear();
    _cartType = null;
    _scheduleAvailability = null;
    _markLocalCartMutated();
    _applyPricing(null);
    _resetGiftOrderDraftIfCartIsEmpty(notify: false);
    notifyListeners();
    await syncFromBackend();
  }

  void updateDeliveryLocation({double? latitude, double? longitude}) {
    if (latitude == null || longitude == null) return;

    const double threshold = 0.0001; // ~11m, avoids frequent refreshes
    final bool changed =
        _deliveryLatitude == null ||
        _deliveryLongitude == null ||
        (_deliveryLatitude! - latitude).abs() > threshold ||
        (_deliveryLongitude! - longitude).abs() > threshold;

    if (!changed) return;

    _deliveryLatitude = latitude;
    _deliveryLongitude = longitude;

    if (_cartItems.isNotEmpty) {
      syncFromBackend();
    }
  }

  Future<void> setUseCredits(bool value) async {
    if (_useCredits == value) return;
    _useCredits = value;
    notifyListeners();
    await syncFromBackend();
  }

  void clearPromoErrorMessage() {
    if (_promoErrorMessage == null || _promoErrorMessage!.trim().isEmpty) {
      return;
    }
    _promoErrorMessage = null;
    notifyListeners();
  }

  Future<String?> applyPromoCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return 'Enter a promo code.';
    }
    if (_cartItems.isEmpty) {
      return 'Add items to cart before applying a promo code.';
    }
    if (providerCount > 1) {
      final message =
          'Promo codes are currently available for single-vendor carts only.';
      _appliedPromoCode = null;
      _promoType = null;
      _promoDiscount = 0.0;
      _promoErrorMessage = message;
      notifyListeners();
      return message;
    }

    final orderType = _inferCartType() ?? _cartType;
    if (orderType != 'food' && orderType != 'grocery') {
      return 'Promo codes are currently available for food and grocery orders only.';
    }

    final validation = await _promoService.validateCode(
      code: normalizedCode,
      orderAmount: subtotal,
      orderType: orderType!,
    );

    if (!validation.valid) {
      _promoErrorMessage = validation.message;
      notifyListeners();
      return validation.message;
    }

    _appliedPromoCode = validation.code.isEmpty
        ? normalizedCode
        : validation.code;
    _promoErrorMessage = null;
    notifyListeners();

    await syncFromBackend();

    if (_appliedPromoCode == null || _appliedPromoCode!.isEmpty) {
      return _promoErrorMessage ?? 'Unable to apply promo code right now.';
    }
    return null;
  }

  Future<void> removePromoCode({bool syncWithBackend = true}) async {
    if (_appliedPromoCode == null &&
        _promoType == null &&
        _promoDiscount == 0.0 &&
        (_promoErrorMessage == null || _promoErrorMessage!.trim().isEmpty)) {
      return;
    }

    _appliedPromoCode = null;
    _promoType = null;
    _promoDiscount = 0.0;
    _promoErrorMessage = null;
    notifyListeners();

    if (syncWithBackend && _cartItems.isNotEmpty) {
      await syncFromBackend();
    }
  }

  Future<bool> replaceCartWithOrder(Map<String, dynamic> order) async {
    final rawItems = order['items'];
    if (rawItems is! List || rawItems.isEmpty) return false;
    _fulfillmentMode = _normalizeFulfillmentMode(
      order['fulfillmentMode']?.toString(),
    );

    final orderType = order['orderType']?.toString().toLowerCase();
    if (orderType == 'pharmacy') {
      debugPrint('⚠️ Pharmacy orders are not supported in cart retry yet.');
      return false;
    }

    _cartItems.clear();
    _cartItemIdsByKey.clear();
    _vendorGroupEtasByKey.clear();
    _cartType = null;
    _markLocalCartMutated();
    _applyPricing(null);
    notifyListeners();

    try {
      await cartApiService.clearCart(
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
        promoCode: _appliedPromoCode,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to clear backend cart: $e');
    }

    final restaurant = order['restaurant'];
    final groceryStore = order['groceryStore'];

    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final itemType = item['itemType']?.toString();

      CartItem? cartItem;
      if (itemType == 'Food' || item['food'] != null) {
        final itemData = Map<String, dynamic>.from(item['food'] ?? {});
        itemData['name'] ??= item['name'];
        itemData['price'] ??= item['price'];
        itemData['image'] ??= item['image'];
        if (restaurant is Map && itemData['restaurant'] == null) {
          itemData['restaurant'] = restaurant;
        }
        itemData['restaurantId'] ??= order['restaurantId'];
        itemData['_id'] ??= item['foodId'];
        itemData['id'] ??= item['foodId'];
        cartItem = _createFoodItemFromBackend(itemData, item);
      } else if (itemType == 'GroceryItem' || item['groceryItem'] != null) {
        final itemData = Map<String, dynamic>.from(item['groceryItem'] ?? {});
        itemData['name'] ??= item['name'];
        itemData['price'] ??= item['price'];
        itemData['image'] ??= item['image'];
        if (groceryStore is Map && itemData['store'] == null) {
          final storeMap = Map<String, dynamic>.from(groceryStore);
          storeMap['_id'] ??= order['groceryStoreId'];
          storeMap['store_name'] ??= storeMap['storeName'];
          itemData['store'] = storeMap;
        }
        itemData['store'] ??= order['groceryStoreId'];
        itemData['_id'] ??= item['groceryItemId'];
        cartItem = _createGroceryItemFromBackend(itemData, item);
      } else if (itemType == 'PharmacyItem' || item['pharmacyItem'] != null) {
        debugPrint('⚠️ Pharmacy orders are not supported in cart retry yet.');
        return false;
      }

      if (cartItem == null) continue;

      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      if (quantity <= 0) continue;

      _cartItems[cartItem] = quantity;
      _cartType = cartItem.itemType == 'Food' ? 'food' : 'grocery';

      await _addToBackend(cartItem, quantity);
    }

    _recalculateLocalPricing();
    await _saveCart();
    notifyListeners();
    await syncFromBackend();

    return _cartItems.isNotEmpty;
  }

  /// Create FoodItem from backend data
  FoodItem _createFoodItemFromBackend(
    Map<String, dynamic> itemData,
    Map<String, dynamic> cartItem, {
    bool? fallbackIsOpen,
  }) {
    // Extract restaurant data if available
    final restaurantData = itemData['restaurant'];
    String restaurantId = '';
    String restaurantName = '';
    String restaurantImage = '';
    if (restaurantData != null) {
      restaurantId =
          restaurantData['_id']?.toString() ??
          restaurantData['id']?.toString() ??
          '';
      restaurantName =
          restaurantData['name']?.toString() ??
          restaurantData['restaurant_name']?.toString() ??
          restaurantData['restaurantName']?.toString() ??
          '';
      restaurantImage =
          restaurantData['logo']?.toString() ??
          restaurantData['image']?.toString() ??
          restaurantData['imageUrl']?.toString() ??
          '';
    }

    if (restaurantId.isEmpty) {
      final rawRestaurantId =
          itemData['restaurantId'] ?? itemData['restaurant'];
      if (rawRestaurantId != null) {
        restaurantId = rawRestaurantId.toString();
      }
    }

    if (restaurantName.isEmpty) {
      restaurantName = itemData['restaurantName']?.toString() ?? '';
    }

    dynamic rawOpen = () {
      if (itemData.containsKey('isRestaurantOpen')) {
        return itemData['isRestaurantOpen'];
      }
      if (restaurantData is Map) {
        if (restaurantData.containsKey('isRestaurantOpen')) {
          return restaurantData['isRestaurantOpen'];
        }
        if (restaurantData.containsKey('isOpen')) {
          return restaurantData['isOpen'];
        }
        if (restaurantData.containsKey('is_open')) {
          return restaurantData['is_open'];
        }
      }
      if (itemData.containsKey('isOpen')) {
        return itemData['isOpen'];
      }
      if (itemData.containsKey('is_open')) {
        return itemData['is_open'];
      }
      return null;
    }();
    rawOpen ??= fallbackIsOpen;
    final isVendorOperational = _isVendorOperational(restaurantData);
    final isVendorOpenNow = _isVendorOpenNow(restaurantData);
    final effectiveItemAvailable =
        _parseBool(itemData['isAvailable'], defaultValue: true) &&
        isVendorOperational;
    final effectiveRestaurantOpen =
        _parseBool(rawOpen, defaultValue: isVendorOpenNow) &&
        isVendorOperational;

    return FoodItem(
      id:
          itemData['_id']?.toString() ??
          itemData['id']?.toString() ??
          cartItem['itemId']?.toString() ??
          cartItem['foodId']?.toString() ??
          '',
      name: itemData['name']?.toString() ?? '',
      price:
          (cartItem['price'] as num?)?.toDouble() ??
          (itemData['price'] as num?)?.toDouble() ??
          0.0,
      image:
          itemData['food_image']?.toString() ??
          itemData['image']?.toString() ??
          itemData['foodImage']?.toString() ??
          '',
      rating:
          ((itemData['weightedRating'] ??
                      itemData['displayRating'] ??
                      itemData['rating'])
                  as num?)
              ?.toDouble() ??
          0.0,
      reviewCount:
          ((itemData['reviewCount'] ??
                      itemData['totalReviews'] ??
                      itemData['ratingCount'])
                  as num?)
              ?.toInt() ??
          0,
      description: itemData['description']?.toString() ?? '',
      sellerName: restaurantName,
      sellerId: restaurantId.isNotEmpty ? restaurantId.hashCode % 1000000 : 0,
      restaurantId: restaurantId,
      restaurantImage: restaurantImage,
      prepTimeMinutes: (itemData['prepTimeMinutes'] as num?)?.toInt() ?? 15,
      calories: (itemData['calories'] as num?)?.toInt() ?? 300,
      portionOptions: ((itemData['portionOptions'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false),
      preferenceGroups: ((itemData['preferenceGroups'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false),
      selectedPortion: cartItem['selectedPortion'] is Map
          ? Map<String, dynamic>.from(cartItem['selectedPortion'])
          : null,
      selectedPreferences:
          ((cartItem['selectedPreferences'] as List?) ?? const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false),
      itemNote: cartItem['itemNote']?.toString(),
      cartCustomizationKey: cartItem['customizationKey']?.toString(),
      deliveryTimeMinutes:
          (itemData['deliveryTimeMinutes'] as num?)?.toInt() ?? 30,
      isAvailable: effectiveItemAvailable,
      isRestaurantOpen: effectiveRestaurantOpen,
    );
  }

  /// Create GroceryItem from backend data
  GroceryItem _createGroceryItemFromBackend(
    Map<String, dynamic> itemData,
    Map<String, dynamic> cartItem,
  ) {
    // Extract store data if available
    final storeData = itemData['store'];
    String storeId = '';

    if (storeData != null) {
      storeId =
          storeData['_id']?.toString() ?? storeData['id']?.toString() ?? '';
    }
    final isStoreOperational = _isVendorOperational(storeData);
    final effectiveItemAvailable =
        _parseBool(itemData['isAvailable'], defaultValue: true) &&
        isStoreOperational;

    return GroceryItem.fromJson({
      '_id':
          itemData['_id'] ??
          itemData['id'] ??
          cartItem['itemId'] ??
          cartItem['groceryItemId'],
      'name': itemData['name'] ?? '',
      'description': itemData['description'] ?? '',
      'image': itemData['image'] ?? itemData['imageUrl'] ?? '',
      'price': itemData['price'] ?? 0.0,
      'unit': itemData['unit'] ?? 'piece',
      'category': itemData['category'],
      'store': storeData is Map
          ? {
              ...Map<String, dynamic>.from(storeData),
              '_id': storeId.isNotEmpty
                  ? storeId
                  : (storeData['_id']?.toString() ??
                        storeData['id']?.toString() ??
                        itemData['storeId']),
            }
          : (storeId.isNotEmpty ? storeId : itemData['storeId']),
      'brand': itemData['brand'] ?? '',
      'stock': itemData['stock'] ?? 0,
      'isAvailable': effectiveItemAvailable,
      'discountPercentage': itemData['discountPercentage'] ?? 0.0,
      'discountEndDate': itemData['discountEndDate'],
      'nutritionInfo': itemData['nutritionInfo'],
      'tags': itemData['tags'] ?? [],
      'rating':
          itemData['weightedRating'] ??
          itemData['displayRating'] ??
          itemData['rating'] ??
          0.0,
      'reviewCount':
          itemData['reviewCount'] ??
          itemData['totalReviews'] ??
          itemData['ratingCount'] ??
          0,
      'orderCount': itemData['orderCount'] ?? 0,
      'createdAt': itemData['createdAt'],
    });
  }

  PharmacyItem _createPharmacyItemFromBackend(
    Map<String, dynamic> itemData,
    Map<String, dynamic> cartItem,
  ) {
    final storeData = itemData['store'];
    final storeMap = storeData is Map
        ? Map<String, dynamic>.from(storeData)
        : null;
    final storeId =
        storeMap?['_id']?.toString() ??
        storeMap?['id']?.toString() ??
        itemData['storeId']?.toString();
    final isStoreOperational = _isVendorOperational(storeData);
    final effectiveItemAvailable =
        _parseBool(itemData['isAvailable'], defaultValue: true) &&
        isStoreOperational;

    return PharmacyItem.fromJson({
      ...itemData,
      '_id':
          itemData['_id'] ??
          itemData['id'] ??
          cartItem['itemId'] ??
          cartItem['pharmacyItemId'],
      'store': storeMap != null
          ? {...storeMap, '_id': storeId}
          : (storeId ?? itemData['store']),
      'isAvailable': effectiveItemAvailable,
    });
  }

  GrabMartItem _createGrabMartItemFromBackend(
    Map<String, dynamic> itemData,
    Map<String, dynamic> cartItem,
  ) {
    final storeData = itemData['store'];
    final storeMap = storeData is Map
        ? Map<String, dynamic>.from(storeData)
        : null;
    final storeId =
        storeMap?['_id']?.toString() ??
        storeMap?['id']?.toString() ??
        itemData['storeId']?.toString();
    final isStoreOperational = _isVendorOperational(storeData);
    final effectiveItemAvailable =
        _parseBool(itemData['isAvailable'], defaultValue: true) &&
        isStoreOperational;

    return GrabMartItem.fromJson({
      ...itemData,
      '_id':
          itemData['_id'] ??
          itemData['id'] ??
          cartItem['itemId'] ??
          cartItem['grabMartItemId'],
      'store': storeMap != null
          ? {...storeMap, '_id': storeId}
          : (storeId ?? itemData['store']),
      'isAvailable': effectiveItemAvailable,
    });
  }

  bool _parseBool(dynamic value, {bool defaultValue = true}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes', 'y', 'on'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n', 'off'].contains(normalized)) return false;
    }
    return defaultValue;
  }

  bool _isVendorOperational(dynamic vendorData) {
    if (vendorData is! Map) return true;
    final map = vendorData;

    final status = map['status']?.toString().toLowerCase();
    final isApproved = status == null || status == 'approved';
    final isAcceptingOrders = _parseBool(
      map['isAcceptingOrders'],
      defaultValue: true,
    );
    final isDeleted = _parseBool(map['isDeleted'], defaultValue: false);

    return isApproved && isAcceptingOrders && !isDeleted;
  }

  bool _isVendorOpenNow(dynamic vendorData) {
    if (vendorData is! Map) return true;
    return _parseBool(
      vendorData['isOpen'] ??
          vendorData['is_open'] ??
          vendorData['isRestaurantOpen'],
      defaultValue: true,
    );
  }

  Future<void> _saveCart() async {
    try {
      final List<Map<String, dynamic>> cartList = _cartItems.entries.map((
        entry,
      ) {
        return {
          'item': entry.key.toJson(),
          'quantity': entry.value,
          'itemType': entry.key.itemType,
          'fulfillmentMode': _fulfillmentMode,
        };
      }).toList();

      await CacheService.saveCartItems(cartList);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  void _markLocalCartMutated() {
    _localMutationVersion++;
  }

  /// Add item to backend
  Future<String?> _addToBackend(CartItem item, int quantity) async {
    try {
      debugPrint('🛒 Adding to backend cart:');
      debugPrint('  Item ID: ${item.id}');
      debugPrint('  Item Type: ${item.itemType}');
      debugPrint('  Item Name: ${item.name}');
      debugPrint('  Provider ID: ${item.providerId}');

      final body = {
        'itemId': item.id,
        'itemType': item.itemType,
        'quantity': quantity,
      };
      body['fulfillmentMode'] = _fulfillmentMode;

      if (item.itemType == 'Food') {
        body['restaurantId'] = item.providerId;
        if (item is FoodItem) {
          final selectedPortionId = item.selectedPortionId;
          if (selectedPortionId != null && selectedPortionId.isNotEmpty) {
            body['selectedPortionId'] = selectedPortionId;
          }
          if (item.selectedPreferenceOptionIds.isNotEmpty) {
            body['selectedPreferenceOptionIds'] =
                item.selectedPreferenceOptionIds;
          }
          final note = item.itemNote?.trim();
          if (note != null && note.isNotEmpty) {
            body['itemNote'] = note;
          }
        }
      } else if (item.itemType == 'GroceryItem') {
        body['groceryStoreId'] = item.providerId;
      } else if (item.itemType == 'PharmacyItem') {
        body['pharmacyStoreId'] = item.providerId;
      } else if (item.itemType == 'GrabMartItem') {
        body['grabMartStoreId'] = item.providerId;
      }

      debugPrint('  Request body: $body');
      final response = await cartApiService.addToCart(
        body,
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
        promoCode: _appliedPromoCode,
      );
      if (!response.isSuccessful) {
        return _extractCartApiErrorMessage(
          response,
          fallback: 'Failed to add item to cart.',
        );
      }
      debugPrint('✅ Successfully added to backend');
      return null;
    } catch (e) {
      debugPrint('❌ Error adding to backend cart: $e');
      return e.toString();
    }
  }

  String _extractCartApiErrorMessage(
    Response<Map<String, dynamic>> response, {
    required String fallback,
  }) {
    final body = response.body;
    if (body is Map<String, dynamic>) {
      final message = body['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
      final error = body['error']?.toString();
      if (error != null && error.trim().isNotEmpty) {
        return error.trim();
      }
    }

    final errorBody = response.error;
    if (errorBody is Map<String, dynamic>) {
      final message = errorBody['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
      final error = errorBody['error']?.toString();
      if (error != null && error.trim().isNotEmpty) {
        return error.trim();
      }
    }

    final rawError = response.error?.toString();
    if (rawError != null && rawError.trim().isNotEmpty) {
      return rawError.trim();
    }

    return fallback;
  }

  String? _getLocalAddToCartBlockingIssue(CartItem item) {
    if (!item.isAvailable) return 'This item is currently unavailable.';
    if (item is GroceryItem && item.stock <= 0) {
      return 'This item is out of stock.';
    }
    if (item is PharmacyItem && item.stock <= 0) {
      return 'This item is out of stock.';
    }
    if (item is GrabMartItem && item.stock <= 0) {
      return 'This item is out of stock.';
    }
    return null;
  }

  String _humanizeAddToCartError(String rawError) {
    final normalized = rawError.toLowerCase();
    if (normalized.contains('currently closed') ||
        normalized.contains('vendor is closed')) {
      return 'This vendor is currently closed.';
    }
    if (normalized.contains('not accepting orders')) {
      return 'This vendor is not accepting orders right now.';
    }
    if (normalized.contains('inactive') || normalized.contains('not found')) {
      return 'This vendor is unavailable right now.';
    }
    if (normalized.contains('out of stock') ||
        normalized.contains('not enough stock') ||
        normalized.contains('insufficient stock')) {
      return 'This item is out of stock.';
    }
    if (normalized.contains('unavailable')) {
      return 'This item is currently unavailable.';
    }
    if (normalized.contains('portion')) {
      return 'Please select a portion size before adding to cart.';
    }
    if (normalized.contains('preference')) {
      return 'Please review your food preferences and try again.';
    }
    return 'Could not add item to cart. Please try again.';
  }

  bool _isItemNotFoundInCartError(String? rawError) {
    if (rawError == null || rawError.trim().isEmpty) return false;
    return rawError.toLowerCase().contains('item not found in cart');
  }

  Future<String?> _ensureCartItemId(
    String key, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await syncFromBackend();
    }
    var cartItemId = _cartItemIdsByKey[key];
    if (cartItemId != null) return cartItemId;

    await syncFromBackend();
    cartItemId = _cartItemIdsByKey[key];
    return cartItemId;
  }

  /// Update quantity on backend
  Future<String?> _updateQuantityOnBackend(String itemId, int quantity) async {
    try {
      final response = await cartApiService.updateCartItem(
        itemId,
        {'quantity': quantity},
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
        promoCode: _appliedPromoCode,
      );
      if (!response.isSuccessful) {
        return _extractCartApiErrorMessage(
          response,
          fallback: 'Failed to update cart item quantity.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error updating backend cart: $e');
      return e.toString();
    }
  }

  /// Remove from backend
  Future<String?> _removeFromBackend(String itemId) async {
    try {
      debugPrint('🔄 Calling backend remove API for item: $itemId');
      final response = await cartApiService.removeFromCart(
        itemId,
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
        promoCode: _appliedPromoCode,
      );
      if (!response.isSuccessful) {
        return _extractCartApiErrorMessage(
          response,
          fallback: 'Failed to remove item from cart.',
        );
      }
      debugPrint('✅ Successfully removed from backend');
      return null;
    } catch (e) {
      debugPrint('❌ Error removing from backend cart: $e');
      return e.toString();
    }
  }

  Future<void> addToCart(CartItem item, {BuildContext? context}) async {
    if (!UserService().isLoggedIn) {
      if (context != null && context.mounted) {
        await AuthGuard.ensureAuthenticated(context);
      }
      return;
    }

    final key = _itemKey(item);
    if (_pendingItemOps.contains(key)) return;
    _pendingItemOps.add(key);

    final localIssue = _getLocalAddToCartBlockingIssue(item);
    if (localIssue != null) {
      if (context != null && context.mounted) {
        AppToastMessage.show(
          context: context,
          backgroundColor: context.appColors.error,
          message: localIssue,
          maxLines: 2,
        );
      }
      _pendingItemOps.remove(key);
      return;
    }

    _cartType = item.itemType == 'Food'
        ? 'food'
        : item.itemType == 'GroceryItem'
        ? 'grocery'
        : item.itemType == 'PharmacyItem'
        ? 'pharmacy'
        : item.itemType == 'GrabMartItem'
        ? 'grabmart'
        : _cartType;
    final previousQuantity = _cartItems[item] ?? 0;

    try {
      if (_cartItems.containsKey(item)) {
        _cartItems[item] = _cartItems[item]! + 1;
      } else {
        _cartItems[item] = 1;
      }

      _markLocalCartMutated();
      _recalculateLocalPricing();
      _saveCart();
      _resetGiftOrderDraftIfCartIsEmpty(notify: false);
      notifyListeners();

      // Sync to backend async
      String? addError;
      if (previousQuantity == 0) {
        _cartItemIdsByKey.remove(key);
        addError = await _addToBackend(item, 1);
      } else {
        final cartItemId = _cartItemIdsByKey[key];
        if (cartItemId != null) {
          addError = await _updateQuantityOnBackend(
            cartItemId,
            _cartItems[item]!,
          );
        } else {
          addError = await _addToBackend(item, 1);
        }
      }

      if (addError != null) {
        if (previousQuantity == 0) {
          _cartItems.remove(item);
        } else {
          _cartItems[item] = previousQuantity;
        }
        _markLocalCartMutated();
        _recalculateLocalPricing();
        _saveCart();
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        notifyListeners();
        await syncFromBackend();
        if (context != null && context.mounted) {
          AppToastMessage.show(
            context: context,
            backgroundColor: context.appColors.error,
            message: _humanizeAddToCartError(addError),
            maxLines: 2,
          );
        }
        return;
      }

      await syncFromBackend();
    } finally {
      _pendingItemOps.remove(key);
    }
  }

  Future<void> removeFromCart(CartItem item) async {
    if (!_cartItems.containsKey(item)) return;

    final key = _itemKey(item);
    if (_pendingItemOps.contains(key)) return;
    var cartItemId = _cartItemIdsByKey[key];
    cartItemId ??= await _ensureCartItemId(key, forceRefresh: true);
    if (cartItemId == null) {
      await syncFromBackend();
      return;
    }
    _pendingItemOps.add(key);

    try {
      final previousQuantity = _cartItems[item]!;
      final previousCartType = _cartType;
      String? backendError;

      if (_cartItems[item]! > 1) {
        _cartItems[item] = _cartItems[item]! - 1;
        _markLocalCartMutated();
        _recalculateLocalPricing();
        _saveCart();
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        notifyListeners();
        backendError = await _updateQuantityOnBackend(
          cartItemId,
          _cartItems[item]!,
        );
        if (_isItemNotFoundInCartError(backendError)) {
          final freshCartItemId = await _ensureCartItemId(
            key,
            forceRefresh: true,
          );
          if (freshCartItemId != null) {
            cartItemId = freshCartItemId;
            backendError = await _updateQuantityOnBackend(
              freshCartItemId,
              _cartItems[item]!,
            );
          }
        }
      } else {
        _cartItems.remove(item);
        if (_cartItems.isEmpty) {
          _cartType = null;
        }
        _markLocalCartMutated();
        _recalculateLocalPricing();
        _saveCart();
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        notifyListeners();
        backendError = await _removeFromBackend(cartItemId);
        if (_isItemNotFoundInCartError(backendError)) {
          final freshCartItemId = await _ensureCartItemId(
            key,
            forceRefresh: true,
          );
          if (freshCartItemId != null) {
            cartItemId = freshCartItemId;
            backendError = await _removeFromBackend(freshCartItemId);
          } else {
            backendError = null;
          }
        }
      }

      if (backendError != null) {
        _cartItems[item] = previousQuantity;
        _cartType = previousCartType;
        _markLocalCartMutated();
        _recalculateLocalPricing();
        _saveCart();
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        notifyListeners();
        await syncFromBackend();
        return;
      }

      await syncFromBackend();
    } finally {
      _pendingItemOps.remove(key);
    }
  }

  Future<void> removeItemCompletely(CartItem item) async {
    debugPrint('🗑️ Removing item completely:');
    debugPrint('  Item ID: ${item.id}');
    debugPrint('  Item Type: ${item.itemType}');
    debugPrint('  Item Name: ${item.name}');
    debugPrint('  Was in cart: ${_cartItems.containsKey(item)}');

    final key = _itemKey(item);
    if (_pendingItemOps.contains(key)) return;
    var cartItemId = _cartItemIdsByKey[key];
    cartItemId ??= await _ensureCartItemId(key, forceRefresh: true);
    if (cartItemId == null) {
      await syncFromBackend();
      return;
    }
    _pendingItemOps.add(key);

    try {
      var backendError = await _removeFromBackend(cartItemId);
      if (_isItemNotFoundInCartError(backendError)) {
        final freshCartItemId = await _ensureCartItemId(
          key,
          forceRefresh: true,
        );
        if (freshCartItemId != null) {
          cartItemId = freshCartItemId;
          backendError = await _removeFromBackend(freshCartItemId);
        } else {
          backendError = null;
        }
      }
      if (backendError != null) {
        await syncFromBackend();
        return;
      }

      _cartItems.remove(item);
      if (_cartItems.isEmpty) {
        _cartType = null;
      }
      _markLocalCartMutated();
      _recalculateLocalPricing();
      _saveCart();
      _resetGiftOrderDraftIfCartIsEmpty(notify: false);
      notifyListeners();
      debugPrint('✅ Remove operation completed');

      await syncFromBackend();
    } finally {
      _pendingItemOps.remove(key);
    }
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    _cartType = null;
    _cartItemIdsByKey.clear();
    _vendorGroupEtasByKey.clear();
    _markLocalCartMutated();
    _applyPricing(null);
    _resetGiftOrderDraftIfCartIsEmpty(notify: false);
    _saveCart();
    notifyListeners();

    // Clear backend cart async
    try {
      await cartApiService.clearCart(
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
        promoCode: _appliedPromoCode,
      );
      await syncFromBackend();
    } catch (e) {
      debugPrint('Error clearing backend cart: $e');
    }
  }

  double get totalPrice {
    double total = 0.0;
    _cartItems.forEach((item, qty) {
      total += item.price * qty;
    });
    return total;
  }

  int get totalQuantity {
    int total = 0;
    _cartItems.forEach((_, qty) => total += qty);
    return total;
  }

  int get uniqueItemCount => _cartItems.length;
}

class _VendorGroupEta {
  final int minMinutes;
  final int maxMinutes;

  const _VendorGroupEta({required this.minMinutes, required this.maxMinutes});
}

class _ProviderIdentity {
  final String id;
  final String name;

  const _ProviderIdentity({required this.id, required this.name});
}
