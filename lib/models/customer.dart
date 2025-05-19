class Customer {
  final String name;
  final String customerName;
  final String customerGroup;

  Customer({
    required this.name,
    required this.customerName,
    required this.customerGroup,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['name'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerGroup: json['customer_group'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'customer_group': customerGroup,
      'customer_type': 'Individual',
    };
  }
}
