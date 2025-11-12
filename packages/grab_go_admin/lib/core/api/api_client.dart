import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;
import 'package:grab_go_admin/core/api/json_serializable_converter.dart' as local;
import 'package:grab_go_admin/features/restaurants/services/restaurant_service.dart';
import 'package:grab_go_admin/features/auth/services/auth_service.dart' as admin_auth;
import 'package:grab_go_admin/features/orders/services/order_service.dart';

final chopperClient = ChopperClient(
  baseUrl: Uri.parse(AppConfig.apiBaseUrl),
  services: [
    RestaurantService.create(), 
    admin_auth.AuthService.create(),
    OrderService.create(),
  ],
  converter: const local.JsonSerializableConverter(),
  interceptors: [HttpLoggingInterceptor()],
  client: http.Client(),
);

RestaurantService get restaurantService => chopperClient.getService<RestaurantService>();
admin_auth.AuthService get authService => chopperClient.getService<admin_auth.AuthService>();
OrderService get orderService => chopperClient.getService<OrderService>();
