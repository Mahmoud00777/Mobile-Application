import 'dart:convert';
import '../models/warehouse.dart';
import 'api_client.dart';

class WarehouseService {
  static Future<List<Warehouse>> getWarehouses() async {
    final res = await ApiClient.get('/api/resource/Warehouse?fields=["name"]');
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return (data['data'] as List).map((e) => Warehouse.fromJson(e)).toList();
    } else {
      throw Exception('فشل في جلب المخازن');
    }
  }
}
