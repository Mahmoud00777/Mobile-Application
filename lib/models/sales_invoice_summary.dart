class SalesInvoiceSummary {
  final String invoiceNumber;
  final DateTime postingDate;
  final String customer;
  final double grandTotal;
  final String customPosOpenShift;
  final int isReturn;

  SalesInvoiceSummary({
    required this.invoiceNumber,
    required this.postingDate,
    required this.customer,
    required this.grandTotal,
    required this.customPosOpenShift,
    required this.isReturn,
  });

  factory SalesInvoiceSummary.fromJsonMap(Map<String, dynamic> json) {
    return SalesInvoiceSummary(
      invoiceNumber: json['name'] as String? ?? '',
      postingDate: DateTime.parse(json['posting_date'] as String),
      customer: json['customer'] as String? ?? '',
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      customPosOpenShift: json['custom_pos_open_shift'] as String? ?? '',
      isReturn: (json['is_return'] as num?)?.toInt() ?? 0,
    );
  }
}
