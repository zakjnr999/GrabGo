import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/grub_go_shared.dart' hide FoodService, AuthService;
import 'package:http/http.dart' as http;
import 'package:grab_go_customer/core/api/json_serializable_converter.dart' as local;
import 'package:grab_go_customer/core/api/auth_interceptor.dart';
import 'package:grab_go_customer/core/api/restaurant_service.dart';
import 'package:grab_go_customer/core/api/auth_service.dart';
import 'package:grab_go_customer/features/home/service/food_service.dart';
import 'package:grab_go_customer/features/cart/service/payment_service.dart';
import 'package:grab_go_customer/features/order/service/order_service_chopper.dart';
import 'package:grab_go_customer/features/status/service/status_service.dart';
import 'package:grab_go_customer/shared/services/notification_service_chopper.dart';

final chopperClient = ChopperClient(
  baseUrl: Uri.parse(AppConfig.apiBaseUrl),
  services: [
    FoodService.create(),
    AuthService.create(),
    RestaurantService.create(),
    PaymentService.create(),
    OrderServiceChopper.create(),
    StatusService.create(),
    NotificationServiceChopper.create(),
  ],
  converter: const local.JsonSerializableConverter(),
  interceptors: [AuthInterceptor(), HttpLoggingInterceptor()],
  client: http.Client(),
);

FoodService get foodService => chopperClient.getService<FoodService>();
AuthService get authService => chopperClient.getService<AuthService>();
RestaurantService get restaurantService => chopperClient.getService<RestaurantService>();
PaymentService get paymentService => chopperClient.getService<PaymentService>();
OrderServiceChopper get orderServiceChopper => chopperClient.getService<OrderServiceChopper>();
StatusService get statusService => chopperClient.getService<StatusService>();
NotificationServiceChopper get notificationServiceChopper => chopperClient.getService<NotificationServiceChopper>();
