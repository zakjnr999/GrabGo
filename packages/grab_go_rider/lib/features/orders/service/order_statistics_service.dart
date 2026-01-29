class OrderStatistics {
  final int totalOrders;
  final int totalDropPoints;
  final double totalEarnings;
  final double totalTips;
  final double totalDistance;
  final double averageEarningsPerOrder;
  final double averageDistance;
  final bool filterApplied;
  final double radius;
  final bool expandedRadius;

  OrderStatistics({
    required this.totalOrders,
    required this.totalDropPoints,
    required this.totalEarnings,
    required this.totalTips,
    required this.totalDistance,
    required this.averageEarningsPerOrder,
    required this.averageDistance,
    required this.filterApplied,
    required this.radius,
    required this.expandedRadius,
  });

  factory OrderStatistics.fromJson(Map<String, dynamic> json) {
    return OrderStatistics(
      totalOrders: json['totalOrders'] as int? ?? 0,
      totalDropPoints: json['totalDropPoints'] as int? ?? 0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      totalTips: (json['totalTips'] as num?)?.toDouble() ?? 0.0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
      averageEarningsPerOrder: (json['averageEarningsPerOrder'] as num?)?.toDouble() ?? 0.0,
      averageDistance: (json['averageDistance'] as num?)?.toDouble() ?? 0.0,
      filterApplied: json['filterApplied'] as bool? ?? false,
      radius: (json['radius'] as num?)?.toDouble() ?? 10.0,
      expandedRadius: json['expandedRadius'] as bool? ?? false,
    );
  }

  factory OrderStatistics.empty() {
    return OrderStatistics(
      totalOrders: 0,
      totalDropPoints: 0,
      totalEarnings: 0.0,
      totalTips: 0.0,
      totalDistance: 0.0,
      averageEarningsPerOrder: 0.0,
      averageDistance: 0.0,
      filterApplied: false,
      radius: 10.0,
      expandedRadius: false,
    );
  }
}
