class BinReport {
  final String warehouse;
  final String itemCode;
  final double actualQty;
  final double projectedQty;

  BinReport({
    required this.warehouse,
    required this.itemCode,
    required this.actualQty,
    required this.projectedQty,
  });

  factory BinReport.fromJsonMap(Map<String, dynamic> json) {
    return BinReport(
      warehouse: json['warehouse'] as String? ?? '',
      itemCode: json['item_code'] as String? ?? '',
      actualQty: (json['actual_qty'] as num?)?.toDouble() ?? 0.0,
      projectedQty: (json['projected_qty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
