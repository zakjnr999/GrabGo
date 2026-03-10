import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';

class CatalogSearchSuggestion {
  final String value;
  final String type;
  final String subtitle;

  const CatalogSearchSuggestion({required this.value, required this.type, required this.subtitle});

  factory CatalogSearchSuggestion.fromJson(Map<String, dynamic> json) {
    return CatalogSearchSuggestion(
      value: json['value']?.toString() ?? '',
      type: json['type']?.toString() ?? 'item',
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }
}

class CatalogSearchCategory {
  final String id;
  final String name;
  final String emoji;
  final String serviceType;
  final bool isFood;
  final int itemCount;

  const CatalogSearchCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.serviceType,
    required this.isFood,
    required this.itemCount,
  });

  factory CatalogSearchCategory.fromJson(Map<String, dynamic> json) {
    return CatalogSearchCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      serviceType: json['serviceType']?.toString() ?? 'food',
      isFood: json['isFood'] == true,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }

  FoodCategoryModel toFilterCategory() {
    return FoodCategoryModel(id: id, name: name, description: '', emoji: emoji, isActive: true, items: const []);
  }
}

class CatalogSearchItemResult {
  final FoodItem displayItem;
  final Object sourceItem;
  final String serviceType;

  const CatalogSearchItemResult({required this.displayItem, required this.sourceItem, required this.serviceType});

  static CatalogSearchItemResult fromJson(Map<String, dynamic> json, {required String serviceType}) {
    switch (serviceType) {
      case 'groceries':
        final item = GroceryItem.fromJson(json);
        return CatalogSearchItemResult(displayItem: item.toFoodItem(), sourceItem: item, serviceType: serviceType);
      case 'pharmacy':
        final item = PharmacyItem.fromJson(json);
        return CatalogSearchItemResult(displayItem: item.toFoodItem(), sourceItem: item, serviceType: serviceType);
      case 'convenience':
        final item = GrabMartItem.fromJson(json);
        return CatalogSearchItemResult(displayItem: item.toFoodItem(), sourceItem: item, serviceType: serviceType);
      case 'food':
      default:
        final item = FoodItem.fromJson(json);
        return CatalogSearchItemResult(displayItem: item, sourceItem: item, serviceType: 'food');
    }
  }
}

class CatalogSearchResponse {
  final List<CatalogSearchCategory> categories;
  final List<VendorModel> vendors;
  final List<CatalogSearchItemResult> items;
  final List<CatalogSearchSuggestion> suggestions;
  final String sort;
  final DateTime? fetchedAt;

  const CatalogSearchResponse({
    required this.categories,
    required this.vendors,
    required this.items,
    required this.suggestions,
    required this.sort,
    this.fetchedAt,
  });

  factory CatalogSearchResponse.fromJson(Map<String, dynamic> json, {required String serviceType}) {
    final categoriesJson = (json['categories'] as List<dynamic>? ?? const []);
    final vendorsJson = (json['vendors'] as List<dynamic>? ?? const []);
    final itemsJson = (json['items'] as List<dynamic>? ?? const []);
    final suggestionsJson = (json['suggestions'] as List<dynamic>? ?? const []);

    return CatalogSearchResponse(
      categories: categoriesJson
          .whereType<Map>()
          .map((entry) => CatalogSearchCategory.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false),
      vendors: vendorsJson
          .whereType<Map>()
          .map((entry) => VendorModel.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false),
      items: itemsJson
          .whereType<Map>()
          .map((entry) => CatalogSearchItemResult.fromJson(Map<String, dynamic>.from(entry), serviceType: serviceType))
          .toList(growable: false),
      suggestions: suggestionsJson
          .whereType<Map>()
          .map((entry) => CatalogSearchSuggestion.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false),
      sort: json['sort']?.toString() ?? 'relevance',
      fetchedAt: json['fetchedAt'] != null ? DateTime.tryParse(json['fetchedAt'].toString()) : null,
    );
  }
}
