import 'package:flutter/material.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class CartProvider extends ChangeNotifier {
  final Map<CartItem, int> _cartItems = {};
  bool _isSyncing = false;

  Map<CartItem, int> get cartItems => _cartItems;
  bool get isSyncing => _isSyncing;

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

        // Detect item type from cached data
        CartItem? cartItem;

        // Check if it's a grocery item (has 'unit' or 'brand' field)
        if (itemData['unit'] != null || itemData['brand'] != null) {
          cartItem = GroceryItem.fromJson(itemData);
        } else {
          // Default to FoodItem
          cartItem = FoodItem.fromJson(itemData);
        }

        _cartItems[cartItem] = quantity;
      }

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
      final response = await cartApiService.getCart();

      if (response.isSuccessful && response.body != null) {
        final cartData = response.body!['cart'];
        if (cartData != null && cartData['items'] != null && cartData['items'].isNotEmpty) {
          _cartItems.clear();

          for (var item in cartData['items']) {
            // Extract the populated itemId (Food or GroceryItem)
            final itemData = item['itemId'];
            if (itemData == null) continue; // Skip if item was deleted

            final itemType = item['itemType']; // Get type from backend
            CartItem? cartItem;

            if (itemType == 'Food') {
              cartItem = _createFoodItemFromBackend(itemData, item);
            } else if (itemType == 'GroceryItem') {
              cartItem = _createGroceryItemFromBackend(itemData, item);
            } else {
              debugPrint('Unknown item type: $itemType');
              continue; // Skip unknown types
            }

            if (cartItem != null) {
              _cartItems[cartItem] = item['quantity'] as int;
            }
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

  /// Create FoodItem from backend data
  FoodItem _createFoodItemFromBackend(Map<String, dynamic> itemData, Map<String, dynamic> cartItem) {
    // Extract restaurant data if available
    final restaurantData = itemData['restaurant'];
    String restaurantId = '';
    String restaurantName = '';
    String restaurantImage = '';

    if (restaurantData != null) {
      restaurantId = restaurantData['_id']?.toString() ?? '';
      restaurantName = restaurantData['name']?.toString() ?? restaurantData['restaurant_name']?.toString() ?? '';
      restaurantImage =
          restaurantData['logo']?.toString() ??
          restaurantData['image']?.toString() ??
          restaurantData['imageUrl']?.toString() ??
          '';
    }

    return FoodItem(
      id: itemData['_id']?.toString() ?? cartItem['itemId'],
      name: itemData['name']?.toString() ?? '',
      price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
      image: itemData['food_image']?.toString() ?? itemData['image']?.toString() ?? '',
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
      storeId = storeData['_id']?.toString() ?? '';
      storeName = storeData['store_name']?.toString() ?? storeData['name']?.toString();
      storeLogo = storeData['logo']?.toString() ?? storeData['image']?.toString();
    }

    return GroceryItem.fromJson({
      '_id': itemData['_id'] ?? cartItem['itemId'],
      'name': itemData['name'] ?? '',
      'description': itemData['description'] ?? '',
      'image': itemData['image'] ?? '',
      'price': itemData['price'] ?? 0.0,
      'unit': itemData['unit'] ?? 'piece',
      'category': itemData['category'],
      'store': storeId,
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
        return {'item': entry.key.toJson(), 'quantity': entry.value};
      }).toList();

      await CacheService.saveCartItems(cartList);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  /// Add item to backend
  Future<void> _addToBackend(CartItem item, int quantity) async {
    try {
      final body = {'itemId': item.id, 'itemType': item.itemType, 'quantity': quantity};

      // Add provider ID based on item type
      if (item.itemType == 'Food') {
        body['restaurantId'] = item.providerId;
      } else if (item.itemType == 'GroceryItem') {
        body['groceryStoreId'] = item.providerId;
      }

      await cartApiService.addToCart(body);
    } catch (e) {
      debugPrint('Error adding to backend cart: $e');
      // Local cart already updated, will retry on next sync
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
      await cartApiService.removeFromCart(itemId);
    } catch (e) {
      debugPrint('Error removing from backend cart: $e');
    }
  }

  void addToCart(CartItem item) {
    final previousQuantity = _cartItems[item] ?? 0;

    if (_cartItems.containsKey(item)) {
      _cartItems[item] = _cartItems[item]! + 1;
    } else {
      _cartItems[item] = 1;
    }

    _saveCart();
    notifyListeners();

    // Sync to backend async
    if (previousQuantity == 0) {
      _addToBackend(item, 1);
    } else {
      _updateQuantityOnBackend(item.id, _cartItems[item]!);
    }
  }

  void removeFromCart(CartItem item) {
    if (!_cartItems.containsKey(item)) return;

    if (_cartItems[item]! > 1) {
      _cartItems[item] = _cartItems[item]! - 1;
      _saveCart();
      notifyListeners();
      _updateQuantityOnBackend(item.id, _cartItems[item]!);
    } else {
      _cartItems.remove(item);
      _saveCart();
      notifyListeners();
      _removeFromBackend(item.id);
    }
  }

  void removeItemCompletely(CartItem item) {
    _cartItems.remove(item);
    _saveCart();
    notifyListeners();
    _removeFromBackend(item.id);
  }

  void clearCart() {
    _cartItems.clear();
    _saveCart();
    notifyListeners();

    // Clear backend cart async
    cartApiService.clearCart().catchError((e) {
      debugPrint('Error clearing backend cart: $e');
    });
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
