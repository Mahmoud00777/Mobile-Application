class Warehouse {
  final String name;

  Warehouse({required this.name});

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'name': name};
  }

  @override
  String toString() => name;
}
