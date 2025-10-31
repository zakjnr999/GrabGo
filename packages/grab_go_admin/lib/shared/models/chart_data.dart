class ChartData {
  final double x;
  final double y;
  final String? label;

  const ChartData({
    required this.x,
    required this.y,
    this.label,
  });
}

class RevenueData {
  final List<ChartData> income;
  final List<ChartData> expenses;

  const RevenueData({
    required this.income,
    required this.expenses,
  });
}

class OrderData {
  final String date;
  final double total;
  final double completed;
  final double pending;

  const OrderData({
    required this.date,
    required this.total,
    required this.completed,
    required this.pending,
  });
}
