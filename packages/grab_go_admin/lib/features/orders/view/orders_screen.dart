import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_admin/shared/app_colors.dart';
import 'package:grab_go_admin/features/orders/viewmodel/order_provider.dart';
import 'package:grab_go_admin/features/orders/model/order_response.dart';
import 'package:grab_go_admin/shared/utils/responsive.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late OrderProvider _orderProvider;

  final List<String> _tabs = [
    'Pending',
    'Confirmed', 
    'Preparing',
    'Ready',
    'Picked Up',
    'On The Way',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _orderProvider = Provider.of<OrderProvider>(context, listen: false);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    await _orderProvider.fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
      body: Column(
        children: [
          _buildHeader(isDark, isMobile),
          _buildTabBar(isDark, isMobile),
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: AppColors.errorRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${provider.error}',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            color: AppColors.errorRed,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrdersList(provider.pendingOrders, isDark, isMobile),
                    _buildOrdersList(provider.confirmedOrders, isDark, isMobile),
                    _buildOrdersList(provider.preparingOrders, isDark, isMobile),
                    _buildOrdersList(provider.readyOrders, isDark, isMobile),
                    _buildOrdersList(provider.pickedUpOrders, isDark, isMobile),
                    _buildOrdersList(provider.onTheWayOrders, isDark, isMobile),
                    _buildOrdersList(provider.deliveredOrders, isDark, isMobile),
                    _buildOrdersList(provider.cancelledOrders, isDark, isMobile),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders Management',
                style: GoogleFonts.lato(
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Consumer<OrderProvider>(
                builder: (context, provider, child) {
                  return Text(
                    'Total Orders: ${provider.allOrders.length}',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey,
                    ),
                  );
                },
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.primary,
        labelColor: isDark ? AppColors.white : AppColors.primary,
        unselectedLabelColor: isDark ? AppColors.white.withValues(alpha: 0.6) : AppColors.grey,
        labelStyle: GoogleFonts.lato(
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.lato(
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: _tabs.map((tab) {
          return Consumer<OrderProvider>(
            builder: (context, provider, child) {
              int count = 0;
              switch (tab) {
                case 'Pending':
                  count = provider.pendingOrders.length;
                  break;
                case 'Confirmed':
                  count = provider.confirmedOrders.length;
                  break;
                case 'Preparing':
                  count = provider.preparingOrders.length;
                  break;
                case 'Ready':
                  count = provider.readyOrders.length;
                  break;
                case 'Picked Up':
                  count = provider.pickedUpOrders.length;
                  break;
                case 'On The Way':
                  count = provider.onTheWayOrders.length;
                  break;
                case 'Delivered':
                  count = provider.deliveredOrders.length;
                  break;
                case 'Cancelled':
                  count = provider.cancelledOrders.length;
                  break;
              }
              
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrdersList(List<OrderData> orders, bool isDark, bool isMobile) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 60,
              color: isDark ? AppColors.white.withValues(alpha: 0.5) : AppColors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], isDark, isMobile);
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderData order, bool isDark, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.lato(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.white : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(order.orderDate)),
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: isDark ? AppColors.white.withValues(alpha: 0.6) : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(order.status, isDark),
              ],
            ),
            const SizedBox(height: 16),
            _buildOrderInfo('Customer', order.customer.username, isDark),
            const SizedBox(height: 8),
            _buildOrderInfo('Restaurant', order.restaurant.restaurantName, isDark),
            const SizedBox(height: 8),
            _buildOrderInfo(
              'Address', 
              '${order.deliveryAddress.street}, ${order.deliveryAddress.city}', 
              isDark,
            ),
            if (order.rider != null) ...[
              const SizedBox(height: 8),
              _buildOrderInfo('Rider', order.rider!.username, isDark),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GH₵ ${order.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.lato(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentOrange,
                  ),
                ),
                _buildActionButtons(order, isDark, isMobile),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color color;
    switch (status) {
      case 'pending':
        color = AppColors.accentOrange;
        break;
      case 'confirmed':
        color = AppColors.blueAccent;
        break;
      case 'preparing':
        color = AppColors.primary;
        break;
      case 'ready':
        color = Colors.green;
        break;
      case 'picked_up':
        color = Colors.purple;
        break;
      case 'on_the_way':
        color = Colors.blue;
        break;
      case 'delivered':
        color = Colors.green.shade700;
        break;
      case 'cancelled':
        color = AppColors.errorRed;
        break;
      default:
        color = AppColors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.lato(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildActionButtons(OrderData order, bool isDark, bool isMobile) {
    List<Widget> buttons = [];

    switch (order.status) {
      case 'pending':
        buttons.addAll([
          _buildActionButton(
            'Confirm',
            Colors.green,
            () => _updateOrderStatus(order.id, 'confirmed'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            'Cancel',
            AppColors.errorRed,
            () => _showCancelDialog(order.id),
          ),
        ]);
        break;
      case 'confirmed':
        buttons.add(_buildActionButton(
          'Preparing',
          AppColors.primary,
          () => _updateOrderStatus(order.id, 'preparing'),
        ));
        break;
      case 'preparing':
        buttons.add(_buildActionButton(
          'Ready',
          Colors.green,
          () => _updateOrderStatus(order.id, 'ready'),
        ));
        break;
      case 'ready':
        buttons.add(_buildActionButton(
          'Picked Up',
          Colors.purple,
          () => _updateOrderStatus(order.id, 'picked_up'),
        ));
        break;
      case 'picked_up':
        buttons.add(_buildActionButton(
          'On The Way',
          Colors.blue,
          () => _updateOrderStatus(order.id, 'on_the_way'),
        ));
        break;
      case 'on_the_way':
        buttons.add(_buildActionButton(
          'Delivered',
          Colors.green.shade700,
          () => _updateOrderStatus(order.id, 'delivered'),
        ));
        break;
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.white,
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(
        text,
        style: GoogleFonts.lato(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    final success = await _orderProvider.updateOrderStatus(orderId, newStatus);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _showCancelDialog(String orderId) {
    String cancellationReason = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to cancel this order?'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) => cancellationReason = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await _orderProvider.updateOrderStatus(
                  orderId, 
                  'cancelled',
                  cancellationReason: cancellationReason.isNotEmpty ? cancellationReason : null,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );
  }
}
