import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';

class CartProvider extends ChangeNotifier {
  final Map<FoodItem, int> _cartItems = {};

  Map<FoodItem, int> get cartItems => _cartItems;

  CartProvider() {
    // Load cart data asynchronously without blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCart();
    });
  }

  Future<void> _loadCart() async {
    try {
      final cartList = CacheService.getCartItems();
      _cartItems.clear();

      for (var item in cartList) {
        final foodItem = FoodItem.fromJson(item['item']);
        final quantity = item['quantity'] as int;
        _cartItems[foodItem] = quantity;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final List<Map<String, dynamic>> cartList = _cartItems.entries.map((
        entry,
      ) {
        return {'item': entry.key.toJson(), 'quantity': entry.value};
      }).toList();

      await CacheService.saveCartItems(cartList);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  void addToCart(FoodItem item) {
    if (_cartItems.containsKey(item)) {
      _cartItems[item] = _cartItems[item]! + 1;
    } else {
      _cartItems[item] = 1;
    }
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(FoodItem item) {
    if (!_cartItems.containsKey(item)) return;

    if (_cartItems[item]! > 1) {
      _cartItems[item] = _cartItems[item]! - 1;
    } else {
      _cartItems.remove(item);
    }
    _saveCart();
    notifyListeners();
  }

  void removeItemCompletely(FoodItem item) {
    _cartItems.remove(item);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _saveCart();
    notifyListeners();
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

