class TotalStockSummary {
  final String item;
  final String description;
  final double currentQty;

  TotalStockSummary({
    required this.item,
    required this.description,
    required this.currentQty,
  });

  factory TotalStockSummary.fromJsonMap(Map<String, dynamic> json) {
    return TotalStockSummary(
      item: json['item'] as String,
      description: json['description'] as String,
      currentQty: (json['current_qty'] as num).toDouble(),
    );
  }
}
