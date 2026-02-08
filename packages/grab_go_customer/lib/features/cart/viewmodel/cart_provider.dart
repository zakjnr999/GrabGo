import 'package:flutter/material.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class CartProvider extends ChangeNotifier {
  final Map<CartItem, int> _cartItems = {};
  bool _isSyncing = false;
  double? _subtotal;
  double _deliveryFee = 0.0;
  double _serviceFee = 0.0;
  double _tax = 0.0;
  double _rainFee = 0.0;
  double? _total;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  String? _cartType;
  final Map<String, String> _cartItemIdsByKey = {};
  final Set<String> _pendingItemOps = {};

  Map<CartItem, int> get cartItems => _cartItems;
  bool get isSyncing => _isSyncing;
  double get subtotal => _subtotal ?? totalPrice;
  double get deliveryFee => _deliveryFee;
  double get serviceFee => _serviceFee;
  double get tax => _tax;
  double get rainFee => _rainFee;
  double get total => _total ?? (subtotal + deliveryFee + serviceFee + tax + rainFee);

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

      for (var item in cartList) {
        final itemData = item['item'];
        final quantity = item['quantity'] as int;
        final cachedItemType = item['itemType'] as String?; // Get cached type

        // Detect item type from cached data
        CartItem? cartItem;

        // Use cached itemType if available, otherwise detect from fields
        if (cachedItemType == 'GroceryItem' || itemData['unit'] != null || itemData['brand'] != null) {
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
  Future<void> syncFromBackend() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      final response = await cartApiService.getCart(
        type: _cartType ?? _inferCartType(),
        lat: _deliveryLatitude,
        lng: _deliveryLongitude,
      );

      if (response.isSuccessful && response.body != null) {
        final cartData = response.body!['cart'];
        if (cartData != null && cartData['items'] != null) {
          _cartItems.clear();
          _cartItemIdsByKey.clear();

          for (var item in cartData['items']) {
            // Extract the populated item (Food/Grocery/Pharmacy)
            final itemData = item['itemId'] ?? item['food'] ?? item['groceryItem'] ?? item['pharmacyItem'];
            if (itemData == null) continue; // Skip if item was deleted

            String? itemType = item['itemType'];
            if (itemType == null) {
              if (item['food'] != null) itemType = 'Food';
              if (item['groceryItem'] != null) itemType = 'GroceryItem';
              if (item['pharmacyItem'] != null) itemType = 'PharmacyItem';
            }

            CartItem? cartItem;

            if (itemType == 'Food') {
              cartItem = _createFoodItemFromBackend(Map<String, dynamic>.from(itemData), item);
            } else if (itemType == 'GroceryItem') {
              cartItem = _createGroceryItemFromBackend(Map<String, dynamic>.from(itemData), item);
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
          await _saveCart();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error syncing cart from backend: $e');
      // Continue with local cache on error
    } finally {
      _isSyncing = false;
    }
  }

  void _applyPricing(Map<String, dynamic>? pricing) {
    if (pricing == null) {
      _subtotal = null;
      _deliveryFee = 0.0;
      _serviceFee = 0.0;
      _tax = 0.0;
      _rainFee = 0.0;
      _total = null;
      return;
    }

    _subtotal = (pricing['subtotal'] as num?)?.toDouble();
    _deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    _serviceFee = (pricing['serviceFee'] as num?)?.toDouble() ?? 0.0;
    _tax = (pricing['tax'] as num?)?.toDouble() ?? 0.0;
    _rainFee = (pricing['rainFee'] as num?)?.toDouble() ?? 0.0;
    _total = (pricing['total'] as num?)?.toDouble();
  }

  void _recalculateLocalPricing() {
    _subtotal = totalPrice;
    _total = _subtotal! + _deliveryFee + _serviceFee + _tax + _rainFee;
  }

  String _itemKey(CartItem item) {
    final id = item.id;
    if (id.isNotEmpty) {
      return '${item.itemType}:$id';
    }
    return '${item.itemType}:${item.name}:${item.providerId}';
  }

  String? _itemKeyFromBackend(String? itemType, Map<String, dynamic> itemData, Map<String, dynamic> cartItem) {
    if (itemType == null) return null;
    final id =
        itemData['_id']?.toString() ??
        itemData['id']?.toString() ??
        cartItem['foodId']?.toString() ??
        cartItem['groceryItemId']?.toString() ??
        cartItem['pharmacyItemId']?.toString() ??
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
    return _cartType;
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

  /// Create FoodItem from backend data
  FoodItem _createFoodItemFromBackend(Map<String, dynamic> itemData, Map<String, dynamic> cartItem) {
    // Extract restaurant data if available
    final restaurantData = itemData['restaurant'];
    String restaurantId = '';
    String restaurantName = '';
    String restaurantImage = '';

    if (restaurantData != null) {
      restaurantId = restaurantData['_id']?.toString() ?? restaurantData['id']?.toString() ?? '';
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
      final rawRestaurantId = itemData['restaurantId'] ?? itemData['restaurant'];
      if (rawRestaurantId != null) {
        restaurantId = rawRestaurantId.toString();
      }
    }

    if (restaurantName.isEmpty) {
      restaurantName = itemData['restaurantName']?.toString() ?? '';
    }

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
      deliveryTimeMinutes: (itemData['deliveryTimeMinutes'] as num?)?.toInt() ?? 30,
      isAvailable: itemData['isAvailable'] ?? true,
    );
  }

  /// Create GroceryItem from backend data
  GroceryItem _createGroceryItemFromBackend(Map<String, dynamic> itemData, Map<String, dynamic> cartItem) {
    // Extract store data if available
    final storeData = itemData['store'];
    String storeId = '';
    String? storeName;
    String? storeLogo;

    if (storeData != null) {
      storeId = storeData['_id']?.toString() ?? storeData['id']?.toString() ?? '';
      storeName = storeData['store_name']?.toString() ?? storeData['storeName']?.toString() ?? storeData['name']?.toString();
      storeLogo = storeData['logo']?.toString() ?? storeData['image']?.toString();
    }

    return GroceryItem.fromJson({
      '_id': itemData['_id'] ?? itemData['id'] ?? cartItem['itemId'] ?? cartItem['groceryItemId'],
      'name': itemData['name'] ?? '',
      'description': itemData['description'] ?? '',
      'image': itemData['image'] ?? itemData['imageUrl'] ?? '',
      'price': itemData['price'] ?? 0.0,
      'unit': itemData['unit'] ?? 'piece',
      'category': itemData['category'],
      'store': storeId.isNotEmpty ? storeId : itemData['storeId'],
      'brand': itemData['brand'] ?? '',
      'stock': itemData['stock'] ?? 0,
      'isAvailable': itemData['isAvailable'] ?? true,
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

  Future<void> _saveCart() async {
    try {
      final List<Map<String, dynamic>> cartList = _cartItems.entries.map((entry) {
        return {'item': entry.key.toJson(), 'quantity': entry.value, 'itemType': entry.key.itemType};
      }).toList();

      await CacheService.saveCartItems(cartList);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  /// Add item to backend
  Future<void> _addToBackend(CartItem item, int quantity) async {
    try {
      debugPrint('🛒 Adding to backend cart:');
      debugPrint('  Item ID: ${item.id}');
      debugPrint('  Item Type: ${item.itemType}');
      debugPrint('  Item Name: ${item.name}');
      debugPrint('  Provider ID: ${item.providerId}');

      final body = {'itemId': item.id, 'itemType': item.itemType, 'quantity': quantity};

      if (item.itemType == 'Food') {
        body['restaurantId'] = item.providerId;
      } else if (item.itemType == 'GroceryItem') {
        body['groceryStoreId'] = item.providerId;
      }

      debugPrint('  Request body: $body');
      await cartApiService.addToCart(body);
      debugPrint('✅ Successfully added to backend');
    } catch (e) {
      debugPrint('❌ Error adding to backend cart: $e');
    }
  }

  /// Update quantity on backend
  Future<void> _updateQuantityOnBackend(String itemId, int quantity) async {
    try {
      await cartApiService.updateCartItem(itemId, {'quantity': quantity});
    } catch (e) {
      debugPrint('Error updating backend cart: $e');
    }
  }

  /// Remove from backend
  Future<void> _removeFromBackend(String itemId) async {
    try {
      debugPrint('🔄 Calling backend remove API for item: $itemId');
      await cartApiService.removeFromCart(itemId);
      debugPrint('✅ Successfully removed from backend');
    } catch (e) {
      debugPrint('❌ Error removing from backend cart: $e');
    }
  }

  Future<void> addToCart(CartItem item, {BuildContext? context}) async {
    final key = _itemKey(item);
    if (_pendingItemOps.contains(key)) return;
    _pendingItemOps.add(key);

    _cartType = item.itemType == 'Food'
        ? 'food'
        : item.itemType == 'GroceryItem'
        ? 'grocery'
        : item.itemType == 'PharmacyItem'
        ? 'pharmacy'
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
      if (previousQuantity == 0) {
        await _addToBackend(item, 1);
      } else {
        final cartItemId = _cartItemIdsByKey[key];
        if (cartItemId != null) {
          await _updateQuantityOnBackend(cartItemId, _cartItems[item]!);
        } else {
          await _addToBackend(item, 1);
        }
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
        notifyListeners();
        await _updateQuantityOnBackend(cartItemId, _cartItems[item]!);
      } else {
        _cartItems.remove(item);
        if (_cartItems.isEmpty) {
          _cartType = null;
        }
        _recalculateLocalPricing();
        _saveCart();
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
    _saveCart();
    notifyListeners();

    // Clear backend cart async
    try {
      await cartApiService.clearCart();
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
