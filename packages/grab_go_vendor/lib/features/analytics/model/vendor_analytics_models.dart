import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

enum VendorAnalyticsRange { today, sevenDays, thirtyDays }

class VendorServiceBreakdownMetric {
  final OrderServiceType serviceType;
  final int orders;
  final double revenue;
  final double share;

  const VendorServiceBreakdownMetric({
    required this.serviceType,
    required this.orders,
    required this.revenue,
    required this.share,
  });
}

class VendorTopItemMetric {
  final String itemName;
  final OrderServiceType serviceType;
  final int quantity;
  final double revenue;

  const VendorTopItemMetric({
    required this.itemName,
    required this.serviceType,
    required this.quantity,
    required this.revenue,
  });
}

class VendorAnalyticsSnapshot {
  final String label;
  final int totalOrders;
  final double totalRevenue;
  final int avgPrepMinutes;
  final double cancelRatePercent;
  final double slaWithinTargetPercent;
  final List<int> orderTrend;
  final List<VendorServiceBreakdownMetric> serviceBreakdown;
  final List<VendorTopItemMetric> topItems;

  const VendorAnalyticsSnapshot({
    required this.label,
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgPrepMinutes,
    required this.cancelRatePercent,
    required this.slaWithinTargetPercent,
    required this.orderTrend,
    required this.serviceBreakdown,
    required this.topItems,
  });
}

Map<VendorAnalyticsRange, VendorAnalyticsSnapshot> mockAnalyticsByRange() {
  return {
    VendorAnalyticsRange.today: const VendorAnalyticsSnapshot(
      label: 'Today',
      totalOrders: 42,
      totalRevenue: 1238.50,
      avgPrepMinutes: 17,
      cancelRatePercent: 1.4,
      slaWithinTargetPercent: 93.0,
      orderTrend: [3, 4, 6, 5, 7, 9, 8],
      serviceBreakdown: [
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.food,
          orders: 20,
          revenue: 560.0,
          share: 0.47,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.grocery,
          orders: 9,
          revenue: 320.0,
          share: 0.21,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.pharmacy,
          orders: 7,
          revenue: 210.5,
          share: 0.16,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.grabmart,
          orders: 6,
          revenue: 148.0,
          share: 0.16,
        ),
      ],
      topItems: [
        VendorTopItemMetric(
          itemName: 'Smoked Chicken Jollof',
          serviceType: OrderServiceType.food,
          quantity: 22,
          revenue: 990.0,
        ),
        VendorTopItemMetric(
          itemName: 'Vitamin C 1000mg',
          serviceType: OrderServiceType.pharmacy,
          quantity: 14,
          revenue: 252.0,
        ),
        VendorTopItemMetric(
          itemName: 'Basmati Rice 5kg',
          serviceType: OrderServiceType.grocery,
          quantity: 8,
          revenue: 736.0,
        ),
      ],
    ),
    VendorAnalyticsRange.sevenDays: const VendorAnalyticsSnapshot(
      label: 'Last 7 Days',
      totalOrders: 251,
      totalRevenue: 7184.20,
      avgPrepMinutes: 18,
      cancelRatePercent: 1.8,
      slaWithinTargetPercent: 91.4,
      orderTrend: [31, 27, 29, 35, 42, 46, 41],
      serviceBreakdown: [
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.food,
          orders: 118,
          revenue: 3280.0,
          share: 0.45,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.grocery,
          orders: 56,
          revenue: 1912.0,
          share: 0.24,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.pharmacy,
          orders: 38,
          revenue: 1026.2,
          share: 0.15,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.grabmart,
          orders: 39,
          revenue: 966.0,
          share: 0.16,
        ),
      ],
      topItems: [
        VendorTopItemMetric(
          itemName: 'Smoked Chicken Jollof',
          serviceType: OrderServiceType.food,
          quantity: 132,
          revenue: 5940.0,
        ),
        VendorTopItemMetric(
          itemName: 'Dishwashing Liquid',
          serviceType: OrderServiceType.grabmart,
          quantity: 61,
          revenue: 915.0,
        ),
        VendorTopItemMetric(
          itemName: 'Vitamin C 1000mg',
          serviceType: OrderServiceType.pharmacy,
          quantity: 57,
          revenue: 1026.0,
        ),
      ],
    ),
    VendorAnalyticsRange.thirtyDays: const VendorAnalyticsSnapshot(
      label: 'Last 30 Days',
      totalOrders: 1028,
      totalRevenue: 30188.70,
      avgPrepMinutes: 19,
      cancelRatePercent: 2.1,
      slaWithinTargetPercent: 90.2,
      orderTrend: [26, 30, 31, 29, 35, 37, 41, 44, 46, 47, 45, 49],
      serviceBreakdown: [
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.food,
          orders: 471,
          revenue: 13680.0,
          share: 0.44,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.grocery,
          orders: 222,
          revenue: 7760.0,
          share: 0.26,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.pharmacy,
          orders: 157,
          revenue: 4312.7,
          share: 0.14,
        ),
        VendorServiceBreakdownMetric(
          serviceType: OrderServiceType.grabmart,
          orders: 178,
          revenue: 4436.0,
          share: 0.16,
        ),
      ],
      topItems: [
        VendorTopItemMetric(
          itemName: 'Smoked Chicken Jollof',
          serviceType: OrderServiceType.food,
          quantity: 511,
          revenue: 22995.0,
        ),
        VendorTopItemMetric(
          itemName: 'Basmati Rice 5kg',
          serviceType: OrderServiceType.grocery,
          quantity: 133,
          revenue: 12236.0,
        ),
        VendorTopItemMetric(
          itemName: 'Vitamin C 1000mg',
          serviceType: OrderServiceType.pharmacy,
          quantity: 201,
          revenue: 3618.0,
        ),
      ],
    ),
  };
}
