class TransactionModel {
  final String id;
  final String type;
  final String typeArabic;
  final String? customer;
  final double amount;
  final double? paidAmount;
  final String? date;
  final String? status;
  final String? paymentMethod;

  TransactionModel({
    required this.id,
    required this.type,
    required this.typeArabic,
    this.customer,
    required this.amount,
    this.paidAmount,
    this.date,
    this.status,
    this.paymentMethod,
  });
}
