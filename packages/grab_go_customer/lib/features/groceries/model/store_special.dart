import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';

class StoreSpecial {
  final GroceryStore store;
  final List<GroceryItem> items;

  StoreSpecial({required this.store, required this.items});

  factory StoreSpecial.fromJson(Map<String, dynamic> json) {
    // Parse store data
    final storeData = {
      '_id': json['storeId'],
      'store_name': json['storeName'],
      'logo': json['storeLogo'],
      'rating': json['storeRating'],
      'isOpen': json['isOpen'],
      'deliveryFee': json['deliveryFee'],
      'minOrder': json['minOrder'],
      // Add defaults for required fields not in API response
      'description': '',
      'address': '',
      'phone': '',
      'email': '',
      'categories': [],
      'latitude': 0.0,
      'longitude': 0.0,
    };

    final store = GroceryStore.fromJson(storeData);

    // Parse items
    final itemsList =
        (json['items'] as List<dynamic>?)?.map((item) => GroceryItem.fromJson(item as Map<String, dynamic>)).toList() ??
        [];

    return StoreSpecial(store: store, items: itemsList);
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': store.id,
      'storeName': store.storeName,
      'storeLogo': store.logo,
      'storeRating': store.rating,
      'isOpen': store.isOpen,
      'deliveryFee': store.deliveryFee,
      'minOrder': store.minOrder,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
