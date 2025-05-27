class CustomerLedgerSummary {
  final String customerName;
  final double closingBalance;

  CustomerLedgerSummary({
    required this.customerName,
    required this.closingBalance,
  });

  factory CustomerLedgerSummary.fromJsonMap(Map<String, dynamic> json) {
    return CustomerLedgerSummary(
      customerName: json['customer_name'] as String? ?? '',
      closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
