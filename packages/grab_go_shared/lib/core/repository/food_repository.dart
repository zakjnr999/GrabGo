import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/core/api/food_service.dart';

class FoodRepository {
  final FoodService service;

  FoodRepository({required this.service});

  Future<List<dynamic>> fetchCategories() async {
    final Response response = await service.getCategories();
    if (response.isSuccessful) {
      final body = response.body;
      final data = (body['data'] as List<dynamic>?) ?? [];
      return data;
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }
}
