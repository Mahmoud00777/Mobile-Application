class Item {
  final String name;
  final String itemName;
  final String itemGroup;
  final String uom;
  final String? description;
  final double rate;

  Item({
    required this.name,
    required this.itemName,
    required this.itemGroup,
    required this.uom,
    this.description,
    required this.rate,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] ?? '',
      itemName: json['item_name'] ?? json['itemName'] ?? '',
      itemGroup: json['item_group'] ?? json['itemGroup'] ?? '',
      uom: json['stock_uom'] ?? json['uom'] ?? '',
      description: json['description'],
      rate:
          double.tryParse(
            json['rate']?.toString() ??
                json['price_list_rate']?.toString() ??
                '0',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'item_name': itemName,
      'item_name_ar': itemName,
      'item_group': itemGroup,
      'stock_uom': uom,
      'description': description,
      'rate': rate,
      'price_list_rate': rate,
      'item_code': name,
    };
  }
}
