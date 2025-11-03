import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';

class FoodRepository {
  final FoodService service;

  FoodRepository({FoodService? service}) : service = service ?? foodService;

  Future<List<FoodCategoryModel>> fetchCategories() async {
    final Response response = await service.getCategories();
    if (response.isSuccessful) {
      final body = response.body;
      final data = (body['data'] as List<dynamic>?) ?? [];
      return data.map((e) => FoodCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }
}
