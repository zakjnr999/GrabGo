import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/grub_go_shared.dart' hide FoodService, AuthService;
import 'package:http/http.dart' as http;
import 'package:grab_go_customer/core/api/json_serializable_converter.dart' as local;
import 'package:grab_go_customer/core/api/restaurant_service.dart';
import 'package:grab_go_customer/core/api/auth_service.dart';
import 'package:grab_go_customer/features/home/service/food_service.dart';

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
