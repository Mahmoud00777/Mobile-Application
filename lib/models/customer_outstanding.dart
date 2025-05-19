class CustomerOutstanding {
  final String name;
  final double outstanding;

  CustomerOutstanding({required this.name, required this.outstanding});

  factory CustomerOutstanding.fromJson(Map<String, dynamic> json) {
    return CustomerOutstanding(
      name: json['name'] ?? '',
      outstanding: (json['outstanding'] ?? 0).toDouble(),
    );
  }
}
