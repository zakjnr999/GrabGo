import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/home/model/catalog_search_models.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';

class CatalogSearchRepository {
  Future<CatalogSearchResponse> search({
    required String serviceType,
    required FilterModel filter,
    required String sort,
    String query = '',
    double? userLat,
    double? userLng,
    int itemLimit = 18,
    int vendorLimit = 8,
    int categoryLimit = 8,
    int suggestionLimit = 8,
  }) async {
    final queryParameters = <String, String>{
      'serviceType': serviceType,
      'sort': sort,
      'itemLimit': '$itemLimit',
      'vendorLimit': '$vendorLimit',
      'categoryLimit': '$categoryLimit',
      'suggestionLimit': '$suggestionLimit',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (filter.minPrice > 0) 'minPrice': filter.minPrice.toString(),
      if (filter.maxPrice < 10000) 'maxPrice': filter.maxPrice.toString(),
      if (filter.minRating != null) 'minRating': filter.minRating.toString(),
      if (filter.selectedCategories.isNotEmpty)
        'categoryIds': filter.selectedCategories.join(','),
      if (filter.selectedRestaurants.isNotEmpty)
        'vendorNames': filter.selectedRestaurants.join(','),
      if (filter.onSale) 'onSale': 'true',
      if (filter.popular) 'popular': 'true',
      if (filter.isNew) 'isNew': 'true',
      if (filter.fast) 'fast': 'true',
      if (filter.dietary != null && filter.dietary!.trim().isNotEmpty)
        'dietary': filter.dietary!.trim(),
      if (filter.distance != null && filter.distance!.trim().isNotEmpty)
        'distance': filter.distance!.trim(),
      if (filter.deliveryTime != null && filter.deliveryTime!.trim().isNotEmpty)
        'deliveryTime': filter.deliveryTime!.trim(),
      if (userLat != null) 'userLat': userLat.toString(),
      if (userLng != null) 'userLng': userLng.toString(),
    };

    final Response response = await chopperClient.get(
      Uri(path: '/search/catalog', queryParameters: queryParameters),
    );

    if (response.isSuccessful && response.body != null) {
      final body = response.body as Map<String, dynamic>;
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return CatalogSearchResponse.fromJson(data, serviceType: serviceType);
      }
      if (data is Map) {
        return CatalogSearchResponse.fromJson(
          Map<String, dynamic>.from(data),
          serviceType: serviceType,
        );
      }
      throw Exception('Invalid catalog search payload');
    }

    final body = response.body;
    final message = body is Map<String, dynamic>
        ? body['message']?.toString() ?? 'Failed to search catalog'
        : 'Failed to search catalog';
    throw Exception(message);
  }
}
