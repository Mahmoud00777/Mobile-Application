//2nd
// models/payment_entry.dart
class PaymentEntry {
  final String name;
  final String party;
  final String modeOfPayment;
  final String postingDate;
  final double paidAmount;

  PaymentEntry({
    required this.name,
    required this.party,
    required this.modeOfPayment,
    required this.postingDate,
    required this.paidAmount,
  });

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      name: json['name'] ?? '',
      party: json['party'] ?? '',
      modeOfPayment: json['mode_of_payment'] ?? '',
      postingDate: json['posting_date'] ?? '',
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
    );
  }
}
