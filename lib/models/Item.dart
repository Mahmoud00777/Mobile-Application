class Item {
  final String name;
  final String itemName;
  final String itemGroup;
  final String uom;
  final String? description;
  final double rate;
  final double qty;
  final double discount_amount;
  final double discount_percentage;
  final List<Map<String, dynamic>> additionalUOMs;
  final List<Map<String, dynamic>>? Item_Default;
  final String? imageUrl;

  Item({
    required this.name,
    required this.itemName,
    required this.itemGroup,
    required this.uom,
    required this.qty,
    required this.discount_amount,
    required this.discount_percentage,
    this.description,
    required this.rate,
    required this.additionalUOMs,
    this.imageUrl,
    this.Item_Default,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    try {
      final name = json['name']?.toString() ?? '';
      final itemName =
          json['item_name']?.toString() ?? json['itemName']?.toString() ?? '';
      final itemGroup =
          json['item_group']?.toString() ?? json['itemGroup']?.toString() ?? '';
      final uom =
          json['sales_uom']?.toString() ?? json['stock_uom']?.toString() ?? '';
      final description = json['description']?.toString();
      final qty = _parseDouble(json['stock_qty'] ?? json['qty']) ?? 0.0;
      final rate = _parseDouble(json['rate'] ?? json['price_list_rate']) ?? 0.0;

      return Item(
        name: name,
        itemName: itemName,
        itemGroup: itemGroup,
        uom: uom,
        qty: qty,
        description: description,
        rate: rate,
        additionalUOMs:
            (json['additional_uoms'] as List?)?.cast<Map<String, dynamic>>() ??
            [],
        Item_Default:
            (json['item_defaults'] as List?)?.cast<Map<String, dynamic>>() ??
            [],
        imageUrl: json['image'],
        discount_amount: 0.0,
        discount_percentage: 0.0,
      );
    } catch (e, stackTrace) {
      print('⚠️ خطأ في تحويل JSON إلى Item: $e');
      print('JSON المسبب للخطأ: $json');
      print('Stack trace: $stackTrace');
      throw FormatException('فشل في تحويل JSON إلى Item: ${e.toString()}');
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'item_name': itemName,
      'item_name_ar': itemName,
      'item_group': itemGroup,
      'stock_uom': uom,
      'description': description,
      'qty': qty,
      'rate': rate,
      'price_list_rate': rate,
      'item_code': name,
      'uoms': additionalUOMs,
      'discount_amount': discount_amount,
      'discount_percentage': discount_percentage,
    };
  }

  /// إنشاء نسخة جديدة من Item مع تحديث الكمية
  Item copyWith({double? qty}) {
    return Item(
      name: name,
      itemName: itemName,
      itemGroup: itemGroup,
      uom: uom,
      qty: qty ?? this.qty,
      description: description,
      rate: rate,
      additionalUOMs: additionalUOMs,
      Item_Default: Item_Default,
      imageUrl: imageUrl,
      discount_amount: discount_amount,
      discount_percentage: discount_percentage,
    );
  }
}
