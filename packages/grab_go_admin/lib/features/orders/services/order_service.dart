import 'package:chopper/chopper.dart';
import 'package:grab_go_admin/features/orders/model/order_response.dart';

part 'order_service.chopper.dart';

@ChopperApi(baseUrl: '/orders')
abstract class OrderService extends ChopperService {
  @Get()
  Future<Response<OrderResponse>> getOrders();

  @Get(path: '/{orderId}')
  Future<Response<Map<String, dynamic>>> getOrderById(@Path('orderId') String orderId);

  @Put(path: '/{orderId}/status')
  Future<Response<Map<String, dynamic>>> updateOrderStatus(
    @Path('orderId') String orderId,
    @Body() Map<String, dynamic> body,
  );

  @Put(path: '/{orderId}/assign-rider')
  Future<Response<Map<String, dynamic>>> assignRider(
    @Path('orderId') String orderId,
    @Body() Map<String, dynamic> body,
  );

  static OrderService create([ChopperClient? client]) => _$OrderService(client);
}