import 'package:flutter/material.dart';
import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class CartProvider extends ChangeNotifier {
  final Map<CartItem, int> _cartItems = {};
  bool _isSyncing = false;
  double? _subtotal;
  double _deliveryFee = 0.0;
  double _serviceFee = 0.0;
  double _tax = 0.0;
  double _rainFee = 0.0;
  double _creditsApplied = 0.0;
  double _availableCredits = 0.0;
  double? _total;
  int? _estimatedDeliveryMin;
  int? _estimatedDeliveryMax;
  bool _useCredits = true;
  bool _hasPricingFromBackend = false;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  String? _cartType;
  String _fulfillmentMode = 'delivery';
  Map<String, dynamic>? _scheduleAvailability;
  final Map<String, String> _cartItemIdsByKey = {};
  final Set<String> _pendingItemOps = {};
  bool _giftOrderEnabled = false;
  String _giftRecipientNameDraft = '';
  String _giftRecipientPhoneDraft = '';
  String _giftNoteDraft = '';

  Map<CartItem, int> get cartItems => _cartItems;
  bool get isSyncing => _isSyncing;
  double get subtotal => _subtotal ?? totalPrice;
  double get deliveryFee => _deliveryFee;
  double get serviceFee => _serviceFee;
  double get tax => _tax;
  double get rainFee => _rainFee;
  double get creditsApplied => _creditsApplied;
  double get availableCredits => _availableCredits;
  double get total =>
      _total ?? (subtotal + deliveryFee + serviceFee + tax + rainFee);
  int? get estimatedDeliveryMin => _estimatedDeliveryMin;
  int? get estimatedDeliveryMax => _estimatedDeliveryMax;
  bool get useCredits => _useCredits;
  bool get isPricingLoading => _isSyncing && !_hasPricingFromBackend;
  String get fulfillmentMode => _fulfillmentMode;
  Map<String, dynamic>? get scheduleAvailability =>
      _scheduleAvailability == null
      ? null
      : Map<String, dynamic>.unmodifiable(_scheduleAvailability!);
  bool get isGiftOrderDraftEnabled => _giftOrderEnabled;
  String get giftRecipientNameDraft => _giftRecipientNameDraft;
  String get giftRecipientPhoneDraft => _giftRecipientPhoneDraft;
  String get giftNoteDraft => _giftNoteDraft;

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
    if (_isSyncing) return true;
    var syncSucceeded = false;

    try {
      _isSyncing = true;
      notifyListeners();
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
      final response = await cartApiService.getCart(
        type: _cartType ?? _inferCartType(),
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
      );

      if (response.isSuccessful && response.body != null) {
        syncSucceeded = true;
        final cartData = response.body!['cart'];
        if (cartData != null && cartData['items'] != null) {
          _scheduleAvailability = _parseScheduleAvailability(
            cartData['scheduleAvailability'],
          );
          _fulfillmentMode = _normalizeFulfillmentMode(
            cartData['fulfillmentMode']?.toString(),
          );
          _cartItems.clear();
          _cartItemIdsByKey.clear();

          for (var item in cartData['items']) {
            // Extract the populated item (Food/Grocery/Pharmacy)
            final itemData =
                item['itemId'] ??
                item['food'] ??
                item['groceryItem'] ??
                item['pharmacyItem'] ??
                item['grabMartItem'];
            if (itemData == null) continue; // Skip if item was deleted

            String? itemType = item['itemType'];
            if (itemType == null) {
              if (item['food'] != null) itemType = 'Food';
              if (item['groceryItem'] != null) itemType = 'GroceryItem';
              if (item['pharmacyItem'] != null) itemType = 'PharmacyItem';
              if (item['grabMartItem'] != null) itemType = 'GrabMartItem';
            }

            CartItem? cartItem;

            if (itemType == 'Food') {
              final restaurantData = itemData['restaurant'];
              String? providerId;
              if (restaurantData is Map) {
                providerId =
                    restaurantData['_id']?.toString() ??
                    restaurantData['id']?.toString();
              }
              providerId ??=
                  itemData['restaurantId']?.toString() ??
                  itemData['restaurant']?.toString();
              providerId ??= item['restaurantId']?.toString();

              final fallbackOpen =
                  previousOpenById[itemData['_id']?.toString() ??
                      itemData['id']?.toString() ??
                      item['foodId']?.toString() ??
                      item['itemId']?.toString() ??
                      ''] ??
                  (providerId != null
                      ? previousOpenByProviderId[providerId]
                      : null);
              cartItem = _createFoodItemFromBackend(
                Map<String, dynamic>.from(itemData),
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
              continue; // Skip unknown types
            }

            _cartItems[cartItem] = item['quantity'] as int;

            final cartItemId = item['id']?.toString();
            final itemKey = _itemKeyFromBackend(itemType, itemData, item);
            if (cartItemId != null && itemKey != null) {
              _cartItemIdsByKey[itemKey] = cartItemId;
            }
          }

          _cartType = _inferCartType();
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
      } else {
        _scheduleAvailability = null;
        debugPrint('Error syncing cart from backend: ${response.error}');
      }
    } catch (e) {
      debugPrint('Error syncing cart from backend: $e');
      // Continue with local cache on error
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return syncSucceeded;
  }

  void _applyPricing(Map<String, dynamic>? pricing) {
    if (pricing == null) {
      _subtotal = null;
      _deliveryFee = 0.0;
      _serviceFee = 0.0;
      _tax = 0.0;
      _rainFee = 0.0;
      _creditsApplied = 0.0;
      _availableCredits = 0.0;
      _total = null;
      _estimatedDeliveryMin = null;
      _estimatedDeliveryMax = null;
      _hasPricingFromBackend = false;
      return;
    }

    _subtotal = (pricing['subtotal'] as num?)?.toDouble();
    _deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    _serviceFee = (pricing['serviceFee'] as num?)?.toDouble() ?? 0.0;
    _tax = (pricing['tax'] as num?)?.toDouble() ?? 0.0;
    _rainFee = (pricing['rainFee'] as num?)?.toDouble() ?? 0.0;
    _creditsApplied = (pricing['creditsApplied'] as num?)?.toDouble() ?? 0.0;
    _availableCredits =
        (pricing['availableBalance'] as num?)?.toDouble() ??
        (pricing['creditBalance'] as num?)?.toDouble() ??
        0.0;
    _total = (pricing['total'] as num?)?.toDouble();
    _estimatedDeliveryMin = (pricing['estimatedDeliveryMin'] as num?)?.toInt();
    _estimatedDeliveryMax = (pricing['estimatedDeliveryMax'] as num?)?.toInt();
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
    if (_cartItems.isNotEmpty) return;
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
    final id = item.id;
    if (id.isNotEmpty) {
      return '${item.itemType}:$id';
    }
    return '${item.itemType}:${item.name}:${item.providerId}';
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
    return '$itemType:$id';
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
    _cartType = null;
    _scheduleAvailability = null;
    _applyPricing(null);
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
    _cartType = null;
    _applyPricing(null);
    notifyListeners();

    try {
      await cartApiService.clearCart(
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
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
      price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
      image:
          itemData['food_image']?.toString() ??
          itemData['image']?.toString() ??
          itemData['foodImage']?.toString() ??
          '',
      rating: (itemData['rating'] as num?)?.toDouble() ?? 4.5,
      description: itemData['description']?.toString() ?? '',
      sellerName: restaurantName,
      sellerId: restaurantId.isNotEmpty ? restaurantId.hashCode % 1000000 : 0,
      restaurantId: restaurantId,
      restaurantImage: restaurantImage,
      prepTimeMinutes: (itemData['prepTimeMinutes'] as num?)?.toInt() ?? 15,
      calories: (itemData['calories'] as num?)?.toInt() ?? 300,
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
      'rating': itemData['rating'] ?? 0.0,
      'reviewCount': itemData['reviewCount'] ?? 0,
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
    return 'Could not add item to cart. Please try again.';
  }

  /// Update quantity on backend
  Future<void> _updateQuantityOnBackend(String itemId, int quantity) async {
    try {
      await cartApiService.updateCartItem(
        itemId,
        {'quantity': quantity},
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
      );
    } catch (e) {
      debugPrint('Error updating backend cart: $e');
    }
  }

  /// Remove from backend
  Future<void> _removeFromBackend(String itemId) async {
    try {
      debugPrint('🔄 Calling backend remove API for item: $itemId');
      await cartApiService.removeFromCart(
        itemId,
        fulfillmentMode: _fulfillmentMode,
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
        useCredits: _useCredits,
      );
      debugPrint('✅ Successfully removed from backend');
    } catch (e) {
      debugPrint('❌ Error removing from backend cart: $e');
    }
  }

  Future<void> addToCart(CartItem item, {BuildContext? context}) async {
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
    // Check for store/restaurant mismatch
    if (context != null && _cartItems.isNotEmpty) {
      final existingItem = _cartItems.keys.first;
      final existingProviderId = existingItem.providerId;
      final newProviderId = item.providerId;

      // Check if switching stores/restaurants
      if (existingProviderId != newProviderId) {
        final isGrocery = item.itemType == 'GroceryItem';
        final providerType = isGrocery ? 'store' : 'restaurant';

        // Show warning dialog
        final shouldReplace = await AppDialog.show(
          context: context,
          type: AppDialogType.warning,
          title: 'Replace Cart Items?',
          message:
              'You have items from a different $providerType in your cart. Adding this item will remove your current cart items. Do you want to continue?',
          primaryButtonText: 'Replace Cart',
          secondaryButtonText: 'Cancel',
        );

        if (shouldReplace != true) {
          _pendingItemOps.remove(key);
          return; // User cancelled
        }

        // Clear cart before adding new item
        _cartItems.clear();
        _cartItemIdsByKey.clear();
        _cartType = null;
        _saveCart();
      }
    }

    final previousQuantity = _cartItems[item] ?? 0;

    try {
      if (_cartItems.containsKey(item)) {
        _cartItems[item] = _cartItems[item]! + 1;
      } else {
        _cartItems[item] = 1;
      }

      _recalculateLocalPricing();
      _saveCart();
      notifyListeners();

      // Sync to backend async
      String? addError;
      if (previousQuantity == 0) {
        addError = await _addToBackend(item, 1);
      } else {
        final cartItemId = _cartItemIdsByKey[key];
        if (cartItemId != null) {
          await _updateQuantityOnBackend(cartItemId, _cartItems[item]!);
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
        _recalculateLocalPricing();
        _saveCart();
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
    _pendingItemOps.add(key);

    final cartItemId = _cartItemIdsByKey[key];
    if (cartItemId == null) {
      try {
        await syncFromBackend();
      } finally {
        _pendingItemOps.remove(key);
      }
      return;
    }

    try {
      if (_cartItems[item]! > 1) {
        _cartItems[item] = _cartItems[item]! - 1;
        _recalculateLocalPricing();
        _saveCart();
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        notifyListeners();
        await _updateQuantityOnBackend(cartItemId, _cartItems[item]!);
      } else {
        _cartItems.remove(item);
        if (_cartItems.isEmpty) {
          _cartType = null;
        }
        _recalculateLocalPricing();
        _saveCart();
        _resetGiftOrderDraftIfCartIsEmpty(notify: false);
        notifyListeners();
        await _removeFromBackend(cartItemId);
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
    _pendingItemOps.add(key);

    final cartItemId = _cartItemIdsByKey[key];
    if (cartItemId == null) {
      try {
        await syncFromBackend();
      } finally {
        _pendingItemOps.remove(key);
      }
      return;
    }

    try {
      _cartItems.remove(item);
      if (_cartItems.isEmpty) {
        _cartType = null;
      }
      _recalculateLocalPricing();
      _saveCart();
      _resetGiftOrderDraftIfCartIsEmpty(notify: false);
      notifyListeners();
      await _removeFromBackend(cartItemId);
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
