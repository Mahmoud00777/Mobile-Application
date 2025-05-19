class Visit {
  final String name;
  final String? latitude;
  final String? longitude;
  final String image;
  final String note;
  final bool visit;
  final String select_state;
  final String customer;
  final String posProfile;
  final String posOpeningShift;
  final DateTime dateTime;
  final String? customerName;
  final String? posProfileName;

  Visit({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.image,
    required this.note,
    required this.visit,
    required this.select_state,
    required this.customer,
    required this.posProfile,
    required this.posOpeningShift,
    required this.dateTime,
    this.customerName,
    this.posProfileName,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null || value == '') return null;
      return double.tryParse(value.toString());
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null || value == '') return DateTime.now();
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    return Visit(
      name: json['name'] ?? '',
      note: json['note'] ?? '',
      latitude: json['latitude'],
      longitude: json['longitude'],
      image:
          json['image'] != null && json['image'].toString().isNotEmpty
              ? 'https://demo2.ababeel.ly${json['image']}'
              : '',
      visit: json['visit'] == 1 || json['visit'] == true,
      select_state: json['select_state'],
      customer: json['customer']?.toString() ?? '',
      posProfile: json['pos_profile']?.toString() ?? '',
      posOpeningShift: json['pos_opening_shift']?.toString() ?? '',
      dateTime: parseDateTime(json['date_time']),
      customerName: json['customer_name']?.toString(),
      posProfileName: json['pos_profile']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'image': image,
      'note': note,
      'visit': visit,
      'select_state': select_state,
      'customer': customer,
      'pos_profile': posProfile,
      'pos_opening_shift': posOpeningShift,
      'date_time': dateTime.toIso8601String(),
      'customer_name': customerName,
      // ignore: equal_keys_in_map
      'pos_profile': posProfileName,
      'doctype': 'Visit',
    };
  }

  Visit copyWith({
    String? name,
    String? latitude,
    String? longitude,
    String? image,
    String? note,
    bool? visit,
    String? select_state,
    String? customer,
    String? posProfile,
    String? posOpeningShift,
    DateTime? dateTime,
    String? customerName,
    String? posProfileName,
  }) {
    return Visit(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      image: image ?? this.image,
      note: note ?? this.note,
      visit: visit ?? this.visit,
      select_state: select_state ?? this.select_state,
      customer: customer ?? this.customer,
      posProfile: posProfile ?? this.posProfile,
      posOpeningShift: posOpeningShift ?? this.posOpeningShift,
      dateTime: dateTime ?? this.dateTime,
      customerName: customerName ?? this.customerName,
      posProfileName: posProfileName ?? this.posProfileName,
      name: name ?? this.name,
    );
  }
}
