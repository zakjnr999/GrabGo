import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/promo_banner.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';

class RecommendedFeedSection {
  final List<FoodItem> items;
  final int page;
  final bool hasMore;

  const RecommendedFeedSection({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
  });

  factory RecommendedFeedSection.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => FoodItem.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);

    return RecommendedFeedSection(
      items: rawItems,
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'page': page,
    'hasMore': hasMore,
  };
}

class FoodHomeFeed {
  final List<FoodCategoryModel> categories;
  final List<FoodItem> deals;
  final List<FoodItem> orderHistory;
  final List<FoodItem> popular;
  final List<FoodItem> topRated;
  final RecommendedFeedSection recommended;
  final List<PromoBanner> promoBanners;
  final List<VendorModel> nearbyVendors;
  final List<VendorModel> freeDeliveryNearbyVendors;
  final List<VendorModel> exclusiveVendors;
  final DateTime? fetchedAt;

  const FoodHomeFeed({
    this.categories = const [],
    this.deals = const [],
    this.orderHistory = const [],
    this.popular = const [],
    this.topRated = const [],
    this.recommended = const RecommendedFeedSection(),
    this.promoBanners = const [],
    this.nearbyVendors = const [],
    this.freeDeliveryNearbyVendors = const [],
    this.exclusiveVendors = const [],
    this.fetchedAt,
  });

  factory FoodHomeFeed.fromJson(Map<String, dynamic> json) {
    List<FoodItem> parseFoodItems(dynamic value) {
      final items = (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>();
      return items
          .map((entry) => FoodItem.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
    }

    List<VendorModel> parseVendors(dynamic value) {
      final vendors = (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>();
      return vendors
          .map(
            (entry) => VendorModel.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false);
    }

    final categories =
        (json['categories'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (entry) =>
                  FoodCategoryModel.fromJson(Map<String, dynamic>.from(entry)),
            )
            .toList(growable: false);

    final recommendedJson = json['recommended'];

    return FoodHomeFeed(
      categories: categories,
      deals: parseFoodItems(json['deals']),
      orderHistory: parseFoodItems(json['orderHistory']),
      popular: parseFoodItems(json['popular']),
      topRated: parseFoodItems(json['topRated']),
      recommended: recommendedJson is Map<String, dynamic>
          ? RecommendedFeedSection.fromJson(recommendedJson)
          : recommendedJson is Map
          ? RecommendedFeedSection.fromJson(
              Map<String, dynamic>.from(recommendedJson),
            )
          : const RecommendedFeedSection(),
      promoBanners:
          (json['promoBanners'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (entry) =>
                    PromoBanner.fromJson(Map<String, dynamic>.from(entry)),
              )
              .toList(growable: false),
      nearbyVendors: parseVendors(json['nearbyVendors']),
      freeDeliveryNearbyVendors: parseVendors(
        json['freeDeliveryNearbyVendors'],
      ),
      exclusiveVendors: parseVendors(json['exclusiveVendors']),
      fetchedAt: json['fetchedAt'] == null
          ? null
          : DateTime.tryParse(json['fetchedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'categories': categories
        .map((category) => category.toJson())
        .toList(growable: false),
    'deals': deals.map((item) => item.toJson()).toList(growable: false),
    'orderHistory': orderHistory
        .map((item) => item.toJson())
        .toList(growable: false),
    'popular': popular.map((item) => item.toJson()).toList(growable: false),
    'topRated': topRated.map((item) => item.toJson()).toList(growable: false),
    'recommended': recommended.toJson(),
    'promoBanners': promoBanners
        .map((banner) => banner.toJson())
        .toList(growable: false),
    'nearbyVendors': nearbyVendors
        .map((vendor) => vendor.toJson())
        .toList(growable: false),
    'freeDeliveryNearbyVendors': freeDeliveryNearbyVendors
        .map((vendor) => vendor.toJson())
        .toList(growable: false),
    'exclusiveVendors': exclusiveVendors
        .map((vendor) => vendor.toJson())
        .toList(growable: false),
    'fetchedAt': fetchedAt?.toIso8601String(),
  };
}
