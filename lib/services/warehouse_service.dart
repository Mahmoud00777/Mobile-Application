import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/warehouse.dart';
import 'api_client.dart';

class WarehouseService {
  static Future<Warehouse?> getWarehouses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null) return null;

      final posProfile = json.decode(posProfileJson) as Map<String, dynamic>;
      final warehouseName = posProfile['warehouse'] as String?;

      if (warehouseName == null) return null;

      final response = await ApiClient.get(
        '/api/resource/Warehouse?filters=[["name","=","$warehouseName"]]&fields=["name"]',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          return Warehouse.fromJson(data['data'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error getting warehouse from POS: $e');
      throw Exception('فشل في جلب مخزن ملف البيع');
    }
  }
}
