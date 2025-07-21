class SalesInvoiceSummary {
  final String invoiceNumber;
  final DateTime postingDate;
  final String customer;
  final double grandTotal;
  final String customPosOpenShift;
  final int isReturn;
  final List<SalesInvoiceItem> items;
  final DateTime creation;

  SalesInvoiceSummary({
    required this.invoiceNumber,
    required this.postingDate,
    required this.customer,
    required this.grandTotal,
    required this.customPosOpenShift,
    required this.isReturn,
    required this.items,
    required this.creation,
  });

  factory SalesInvoiceSummary.fromJsonMap(Map<String, dynamic> json) {
    return SalesInvoiceSummary(
      invoiceNumber: json['name'] as String? ?? '',
      postingDate: DateTime.parse(json['posting_date'] as String),
      customer: json['customer'] as String? ?? '',
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      customPosOpenShift: json['custom_pos_open_shift'] as String? ?? '',
      isReturn: (json['is_return'] as num?)?.toInt() ?? 0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => SalesInvoiceItem.fromJson(item))
              .toList() ??
          [],
      creation: DateTime.parse(
        json['creation'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class SalesInvoiceItem {
  final String itemCode;
  final String itemName;
  final int qty;
  final String uom;
  final double rate;

  SalesInvoiceItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.rate,
  });

  factory SalesInvoiceItem.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceItem(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      qty: (json['qty'] ?? 0).toInt(),
      uom: json['uom'] ?? '',
      rate: (json['rate'] ?? 0.0),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'qty': qty,
      'item_name': itemName,
      'uom': uom,
      'rate': rate,
    };
  }
}
