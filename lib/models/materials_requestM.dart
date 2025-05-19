class MaterialRequest {
  final String name;
  final String reason;
  final String scheduleDate;
  final String warehouse;
  final List<MaterialRequestItem> items;

  MaterialRequest({
    required this.name,
    required this.reason,
    required this.scheduleDate,
    required this.warehouse,
    required this.items,
  });
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'material_request_type': reason,
      'schedule_date': scheduleDate,
      'set_warehouse': warehouse,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    return MaterialRequest(
      name: json['name'] ?? '',
      reason: json['material_request_type'] ?? '',
      scheduleDate: json['schedule_date'] ?? '',
      warehouse: json['set_warehouse'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => MaterialRequestItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class MaterialRequestItem {
  final String itemCode;
  final String itemName;
  final int qty;
  final String uom;

  MaterialRequestItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
  });

  factory MaterialRequestItem.fromJson(Map<String, dynamic> json) {
    return MaterialRequestItem(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      qty: (json['qty'] ?? 0).toInt(),
      uom: json['uom'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'qty': qty,
      'item_name': itemName,
      'uom': uom,
    };
  }
}
