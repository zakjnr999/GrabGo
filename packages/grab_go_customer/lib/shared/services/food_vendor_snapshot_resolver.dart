import 'package:flutter/widgets.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';
import 'package:provider/provider.dart';

import 'restaurant_detail_service.dart';

class FoodVendorSnapshotResolver {
  static const String _homeNearbyVendorsCacheKey = 'home_nearby_food';
  static const String _homeExclusiveVendorsCacheKey = 'home_exclusive_food';

  const FoodVendorSnapshotResolver._();

  static VendorModel resolve(BuildContext context, FoodItem foodItem) {
    final vendorId = foodItem.restaurantId.trim();
    if (vendorId.isEmpty) {
      return _buildFallback(foodItem);
    }

    final foodProvider = context.read<FoodProvider>();
    final inMemoryMatches = <VendorModel>[
      ...foodProvider.exclusiveVendors,
      ...foodProvider.nearbyVendors,
    ];

    for (final vendor in inMemoryMatches) {
      if (vendor.id != vendorId) continue;
      return _mergeWithFoodItem(vendor, foodItem);
    }

    final cachedMatches = [
      ...CacheService.getVendorsByType(_homeExclusiveVendorsCacheKey),
      ...CacheService.getVendorsByType(_homeNearbyVendorsCacheKey),
    ].map(VendorModel.fromJson);

    for (final vendor in cachedMatches) {
      if (vendor.id != vendorId) continue;
      return _mergeWithFoodItem(vendor, foodItem);
    }

    final cachedRestaurant = RestaurantDetailService.getCachedRestaurantDetails(
      vendorId,
    );
    if (cachedRestaurant != null) {
      final locationData = <String, dynamic>{
        'lat': 0.0,
        'lng': 0.0,
        'address': cachedRestaurant['address']?.toString() ?? '',
        'city': cachedRestaurant['city']?.toString() ?? '',
        'area': cachedRestaurant['area']?.toString(),
      };

      return VendorModel.fromJson({
        'id': vendorId,
        'restaurant_name': cachedRestaurant['restaurant_name'],
        'logo':
            (cachedRestaurant['logo']?.toString().trim().isNotEmpty ?? false)
            ? cachedRestaurant['logo']
            : foodItem.restaurantImage,
        'description': cachedRestaurant['description'],
        'phone': cachedRestaurant['phone'],
        'email': '',
        'rating': cachedRestaurant['rating'],
        'totalReviews': cachedRestaurant['totalReviews'],
        'isOpen': foodItem.isRestaurantOpen,
        'deliveryTime': foodItem.estimatedDeliveryTime,
        'location': locationData,
        'vendorType': VendorType.food.id,
      }).copyWith(vendorTypeEnum: VendorType.food);
    }

    return _buildFallback(foodItem);
  }

  static VendorModel _mergeWithFoodItem(VendorModel vendor, FoodItem foodItem) {
    return vendor.copyWith(
      restaurantName: vendor.displayName.trim().isEmpty
          ? foodItem.sellerName.trim()
          : vendor.restaurantName,
      logo: (vendor.logo?.trim().isNotEmpty ?? false)
          ? vendor.logo
          : (foodItem.restaurantImage.trim().isEmpty
                ? vendor.logo
                : foodItem.restaurantImage.trim()),
      isOpen: vendor.isOpen,
      deliveryTime: vendor.deliveryTime ?? foodItem.estimatedDeliveryTime,
      vendorType: VendorType.food.id,
      vendorTypeEnum: VendorType.food,
    );
  }

  static VendorModel _buildFallback(FoodItem foodItem) {
    return VendorModel(
      id: foodItem.restaurantId.trim(),
      restaurantName: foodItem.sellerName.trim(),
      logo: foodItem.restaurantImage.trim().isEmpty
          ? null
          : foodItem.restaurantImage.trim(),
      phone: '',
      email: '',
      isOpen: foodItem.isRestaurantOpen,
      deliveryFee: 0,
      minOrder: 0,
      deliveryTime: foodItem.estimatedDeliveryTime,
      vendorType: VendorType.food.id,
      vendorTypeEnum: VendorType.food,
    );
  }
}
