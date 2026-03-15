import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';

class ServiceDisplayItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final double discountPercentage;
  final double rating;
  final int orderCount;
  final bool isAvailable;
  final String unitLabel;
  final String storeName;
  final Object sourceItem;

  const ServiceDisplayItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.orderCount,
    required this.isAvailable,
    required this.unitLabel,
    required this.storeName,
    required this.sourceItem,
  });

  double get discountedPrice {
    if (discountPercentage <= 0) return price;
    return price * (1 - (discountPercentage / 100));
  }

  bool get hasDiscount => discountPercentage > 0;

  static ServiceDisplayItem fromGroceryItem(GroceryItem item) {
    return ServiceDisplayItem(
      id: item.id,
      name: item.name,
      description: item.description,
      imageUrl: item.catalogImage,
      price: item.price,
      discountPercentage: item.discountPercentage,
      rating: item.rating,
      orderCount: item.orderCount,
      isAvailable: item.isAvailable,
      unitLabel: item.unit,
      storeName: item.storeName ?? 'Grocery Store',
      sourceItem: item,
    );
  }

  static ServiceDisplayItem fromPharmacyItem(PharmacyItem item) {
    return ServiceDisplayItem(
      id: item.id,
      name: item.name,
      description: item.description,
      imageUrl: item.image,
      price: item.price,
      discountPercentage: item.discountPercentage,
      rating: item.rating,
      orderCount: item.orderCount,
      isAvailable: item.isAvailable,
      unitLabel: item.unit,
      storeName: item.storeName ?? 'Pharmacy',
      sourceItem: item,
    );
  }

  static ServiceDisplayItem fromGrabMartItem(GrabMartItem item) {
    return ServiceDisplayItem(
      id: item.id,
      name: item.name,
      description: item.description,
      imageUrl: item.image,
      price: item.price,
      discountPercentage: item.discountPercentage,
      rating: item.rating,
      orderCount: item.orderCount,
      isAvailable: item.isAvailable,
      unitLabel: item.unit,
      storeName: item.storeName ?? 'GrabMart',
      sourceItem: item,
    );
  }
}
