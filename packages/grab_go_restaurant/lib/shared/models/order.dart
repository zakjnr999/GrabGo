class Order {
  final String id;
  final String number;
  final String date;
  final String customerName;
  final String location;
  final String amount;
  final String status;
  final String statusColor;

  const Order({
    required this.id,
    required this.number,
    required this.date,
    required this.customerName,
    required this.location,
    required this.amount,
    required this.status,
    required this.statusColor,
  });
}
