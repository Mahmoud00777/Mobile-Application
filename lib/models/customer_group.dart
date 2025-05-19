class CustomerGroup {
  final String name;

  CustomerGroup({required this.name});

  factory CustomerGroup.fromJson(Map<String, dynamic> json) {
    return CustomerGroup(name: json['name']);
  }
}
