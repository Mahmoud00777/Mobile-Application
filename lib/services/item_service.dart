import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';
import 'api_client.dart';

class ItemService {
  static Future<List<Item>> getItems({
    String priceList = 'البيع القياسية',
    bool includePrices = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');

    if (posProfileJson == null || posProfileJson.isEmpty) {
      throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
    }
    final posProfile = json.decode(posProfileJson);

    final posPriceList = posProfile['selling_price_list'];

    try {
      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=["name","item_name","item_group","stock_uom","description"]'
        '&filters=[["disabled","=",0]]',
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في جلب الأصناف: ${itemsRes.statusCode}');
      }

      final itemsData = json.decode(itemsRes.body)['data'] as List;
      if (itemsData.isEmpty) return [];

      if (!includePrices) {
        return itemsData.map((item) => Item.fromJson(item)).toList();
      }

      final itemNames = itemsData.map((item) => item['name']).toList();
      final pricesRes = await ApiClient.get(
        '/api/resource/Item Price?fields=["item_code","price_list_rate","currency"]'
        '&filters=['
        '["item_code","in",${json.encode(itemNames)}],'
        '["price_list","=","$posPriceList"],'
        '["selling","=",1]'
        ']',
      );

      final Map<String, double> pricesMap = {};
      if (pricesRes.statusCode == 200) {
        final pricesData = json.decode(pricesRes.body)['data'] as List;
        for (final price in pricesData) {
          final rate =
              double.tryParse(price['price_list_rate']?.toString() ?? '0') ?? 0;
          pricesMap[price['item_code']] = rate;
        }
      }

      return itemsData.map((item) {
        final rate = pricesMap[item['name']] ?? 0.0;
        return Item.fromJson({
          ...item,
          'rate': rate,
          'currency': pricesMap.containsKey(item['name']) ? 'SAR' : null,
        });
      }).toList();
    } catch (e) {
      throw Exception('فشل في جلب الأصناف: ${e.toString()}');
    }
  }

  static Future<List<String>> getItemGroups() async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Item Group?fields=["name"]',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((group) => group['name'].toString())
            .toList();
      }
      throw Exception('Failed to load item groups');
    } catch (e) {
      throw Exception('Error fetching item groups: $e');
    }
  }
}
