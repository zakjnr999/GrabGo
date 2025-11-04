class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime dateTime;
  final TransactionStatus status;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.dateTime,
    this.status = TransactionStatus.completed,
  });
}

enum TransactionType { delivery, tip, bonus, withdrawal, penalty }

enum TransactionStatus { pending, completed, failed }
