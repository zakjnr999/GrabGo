import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;
import 'food_service.dart';
import 'auth_service.dart';
import 'restaurant_service.dart';
import 'json_serializable_converter.dart' as local;

final chopperClient = ChopperClient(
  baseUrl: Uri.parse(AppConfig.apiBaseUrl),
  services: [FoodService.create(), AuthService.create(), RestaurantService.create()],
  converter: const local.JsonSerializableConverter(),
  interceptors: [HttpLoggingInterceptor()],
  client: http.Client(),
);

FoodService get foodService => chopperClient.getService<FoodService>();
AuthService get authService => chopperClient.getService<AuthService>();
RestaurantService get restaurantService => chopperClient.getService<RestaurantService>();
