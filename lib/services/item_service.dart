import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';
import 'api_client.dart';

class ItemService {
  static Future<List<Item>> getItems({
    String priceList = 'البيع القياسية',
    bool includePrices = true,
    bool includeStock = true,
    bool includeUOMs = true,
  }) async {
    try {
      // 1. جلب إعدادات نقطة البيع من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      final posProfile = json.decode(posProfileJson);
      final posPriceList = posProfile['selling_price_list'];
      final warehouse = posProfile['warehouse'];

      // 2. جلب الأصناف الأساسية
      print('جلب الأصناف الأساسية...');
      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=["name","item_name","item_group","stock_uom","description","image","sales_uom"]'
        '&filters=[["disabled","=",0]]',
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في جلب الأصناف: ${itemsRes.statusCode}');
      }

      final itemsData = json.decode(itemsRes.body)['data'] as List;
      if (itemsData.isEmpty) return [];

      final List<Item> result = [];
      final itemNames =
          itemsData.map((item) => item['name'].toString()).toList();

      // 3. جلب الأسعار (إذا كان مطلوبًا)
      final Map<String, double> pricesMap = {};
      if (includePrices) {
        print('جلب أسعار الأصناف...');
        try {
          // بناء فلتر الأسعار بناءً على sales_uom أو stock_uom
          final priceFilters = [
            '["price_list","=","$posPriceList"]',
            '["selling","=",1]',
            '["item_code","in",${json.encode(itemNames)}]',
          ];

          final pricesRes = await ApiClient.get(
            '/api/resource/Item Price?fields=["item_code","price_list_rate","currency","uom"]'
            '&filters=[${priceFilters.join(',')}]',
          );

          if (pricesRes.statusCode == 200) {
            final pricesData = json.decode(pricesRes.body)['data'] as List;
            print('تم جلب ${pricesData.length} سعرًا');

            for (final item in itemsData) {
              final itemName = item['name'].toString();
              final salesUOM = item['sales_uom']?.toString();
              final stockUOM = item['stock_uom']?.toString();
              final uomToUse =
                  salesUOM?.isNotEmpty == true ? salesUOM : stockUOM;

              // البحث عن السعر المناسب للوحدة
              final price = pricesData.firstWhere(
                (p) => p['item_code'] == itemName && p['uom'] == uomToUse,
                orElse: () => null,
              );

              if (price != null) {
                final rate =
                    double.tryParse(
                      price['price_list_rate']?.toString() ?? '0',
                    ) ??
                    0;
                pricesMap[itemName] = rate;
                print('🔹 $itemName: $rate SAR (${price['uom']})');
              }
            }
          }
        } catch (e) {
          print('تحذير: فشل جلب الأسعار - $e');
        }
      }

      // 4. جلب المخزون (إذا كان مطلوبًا)
      final Map<String, double> stockMap = {};
      if (includeStock &&
          warehouse != null &&
          warehouse.toString().isNotEmpty) {
        print('جلب كميات المخزون للمستودع $warehouse...');
        try {
          final stockRes = await ApiClient.get(
            '/api/resource/Bin?fields=["item_code","actual_qty"]'
            '&filters=['
            '["item_code","in",${json.encode(itemNames)}],'
            '["warehouse","=","$warehouse"]'
            ']',
          );

          if (stockRes.statusCode == 200) {
            final stockData = json.decode(stockRes.body)['data'] as List;
            for (final stock in stockData) {
              final qty =
                  double.tryParse(stock['actual_qty']?.toString() ?? '0') ?? 0;
              stockMap[stock['item_code'].toString()] = qty;
            }
            print('تم جلب مخزون ${stockMap.length} صنف');
          }
        } catch (e) {
          print('تحذير: فشل جلب المخزون - $e');
        }
      }

      // 5. جلب وحدات القياس الإضافية (إذا كان مطلوبًا)
      final Map<String, List<Map<String, dynamic>>> uomsMap = {};
      if (includeUOMs) {
        print('جلب وحدات القياس الإضافية...');
        for (final itemName in itemNames) {
          try {
            final uomRes = await ApiClient.get(
              '/api/resource/Item/$itemName?fields=["uoms"]',
            );

            if (uomRes.statusCode == 200) {
              final itemData = json.decode(uomRes.body)['data'];
              if (itemData['uoms'] != null && itemData['uoms'] is List) {
                uomsMap[itemName] =
                    (itemData['uoms'] as List).map((uom) {
                      return {
                        'uom': uom['uom']?.toString() ?? '',
                        'conversion_factor':
                            double.tryParse(
                              uom['conversion_factor']?.toString() ?? '1',
                            ) ??
                            1.0,
                      };
                    }).toList();
              }
            }
          } catch (e) {
            print('تحذير: فشل جلب وحدات القياس للصنف $itemName - $e');
          }
        }
      }

      // 6. دمج البيانات وبناء النتيجة النهائية
      print('بناء قائمة الأصناف النهائية...');
      for (final item in itemsData) {
        try {
          final itemName = item['name'].toString();
          result.add(
            Item.fromJson({
              ...item,
              'rate': pricesMap[itemName] ?? 0.0,
              'currency': pricesMap.containsKey(itemName) ? 'SAR' : null,
              'stock_qty': stockMap[itemName] ?? 0.0,
              'additional_uoms': uomsMap[itemName] ?? [],
            }),
          );
        } catch (e, stack) {
          print('خطأ في معالجة الصنف ${item['name']}: $e');
          print('Stack trace: $stack');
        }
      }

      print('تم جلب ${result.length} صنف بنجاح');
      return result;
    } catch (e, stack) {
      print('!!!! خطأ رئيسي في getItems: $e');
      print('Stack trace: $stack');
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
