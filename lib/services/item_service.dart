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
      // 1. جلب إعدادات نقطة البيع مرة واحدة
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      final posProfile = json.decode(posProfileJson);
      final posPriceList = posProfile['selling_price_list'];
      final warehouse = posProfile['warehouse'];

      // 2. جلب الأصناف الأساسية مع الحقول الضرورية فقط
      final fields = [
        '"name"',
        '"item_name"',
        '"item_group"',
        '"stock_uom"',
        '"description"',
        '"image"',
        '"sales_uom"',
      ];

      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=[${fields.join(',')}]'
        '&filters=[["disabled","=",0]]'
        '&limit_page_length=1000', // زيادة الحد إذا كان هناك الكثير من الأصناف
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في جلب الأصناف: ${itemsRes.statusCode}');
      }

      final itemsData = json.decode(itemsRes.body)['data'] as List;
      if (itemsData.isEmpty) return [];

      // 3. معالجة متوازية للبيانات
      final result = await _processItemsData(
        itemsData,
        posPriceList: posPriceList,
        warehouse: warehouse,
        includePrices: includePrices,
        includeStock: includeStock,
        includeUOMs: includeUOMs,
      );

      return result;
    } catch (e, stack) {
      print('!!!! خطأ رئيسي في getItems: $e');
      print('Stack trace: $stack');
      throw Exception('فشل في جلب الأصناف: ${e.toString()}');
    }
  }

  static Future<List<Item>> _processItemsData(
    List<dynamic> itemsData, {
    required dynamic posPriceList,
    required dynamic warehouse,
    required bool includePrices,
    required bool includeStock,
    required bool includeUOMs,
  }) async {
    final itemNames = itemsData.map((item) => item['name'].toString()).toList();
    final result = <Item>[];

    // 1. جلب الأسعار والمخزون بشكل متوازي إذا كان مطلوباً
    final futures = <Future>[];

    final pricesMap = <String, double>{};
    if (includePrices) {
      futures.add(_fetchPrices(itemNames, posPriceList, pricesMap));
    }

    final stockMap = <String, double>{};
    if (includeStock && warehouse != null && warehouse.toString().isNotEmpty) {
      futures.add(_fetchStock(itemNames, warehouse.toString(), stockMap));
    }

    await Future.wait(futures);

    // 2. جلب وحدات القياس الإضافية إذا كان مطلوباً
    final uomsMap = <String, List<Map<String, dynamic>>>{};
    if (includeUOMs) {
      await _fetchAdditionalUOMs(itemNames, uomsMap);
    }

    // 3. بناء النتيجة النهائية
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

    return result;
  }

  static Future<void> _fetchPrices(
    List<String> itemNames,
    dynamic posPriceList,
    Map<String, double> pricesMap,
  ) async {
    try {
      final priceFilters = [
        '["price_list","=","$posPriceList"]',
        '["selling","=",1]',
        '["item_code","in",${json.encode(itemNames)}]',
      ];

      final pricesRes = await ApiClient.get(
        '/api/resource/Item Price?fields=["item_code","price_list_rate","currency","uom"]'
        '&filters=[${priceFilters.join(',')}]'
        '&limit_page_length=1000',
      );

      if (pricesRes.statusCode == 200) {
        final pricesData = json.decode(pricesRes.body)['data'] as List;
        for (final price in pricesData) {
          final rate =
              double.tryParse(price['price_list_rate']?.toString() ?? '0') ?? 0;
          pricesMap[price['item_code'].toString()] = rate;
        }
      }
    } catch (e) {
      print('تحذير: فشل جلب الأسعار - $e');
    }
  }

  static Future<void> _fetchStock(
    List<String> itemNames,
    String warehouse,
    Map<String, double> stockMap,
  ) async {
    try {
      final stockRes = await ApiClient.get(
        '/api/resource/Bin?fields=["item_code","actual_qty"]'
        '&filters=['
        '["item_code","in",${json.encode(itemNames)}],'
        '["actual_qty",">","0"],'
        '["warehouse","=","$warehouse"]'
        ']'
        '&limit_page_length=1000',
      );

      if (stockRes.statusCode == 200) {
        final stockData = json.decode(stockRes.body)['data'] as List;
        for (final stock in stockData) {
          final qty =
              double.tryParse(stock['actual_qty']?.toString() ?? '0') ?? 0;
          stockMap[stock['item_code'].toString()] = qty;
        }
      }
    } catch (e) {
      print('تحذير: فشل جلب المخزون - $e');
    }
  }

  static Future<void> _fetchAdditionalUOMs(
    List<String> itemNames,
    Map<String, List<Map<String, dynamic>>> uomsMap,
  ) async {
    try {
      // جلب دفعات من الأصناف بدلاً من كل صنف على حدة
      const batchSize = 20;
      for (var i = 0; i < itemNames.length; i += batchSize) {
        final batch = itemNames.sublist(
          i,
          i + batchSize > itemNames.length ? itemNames.length : i + batchSize,
        );

        await Future.wait(
          batch.map((itemName) async {
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
          }),
        );
      }
    } catch (e) {
      print('تحذير: فشل جلب وحدات القياس الإضافية - $e');
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
