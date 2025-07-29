import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/Item.dart';
import 'api_client.dart';

class ItemService {
  static List<Item>? _cachedFullItems;
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  static Future<List<Item>> _getFullItems({
    String priceList = 'البيع القياسية',
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && _cachedFullItems != null && _lastCacheTime != null) {
        final timeSinceLastCache = DateTime.now().difference(_lastCacheTime!);
        if (timeSinceLastCache < _cacheDuration) {
          print('استخدام البيانات المخزنة مؤقتاً');
          return _cachedFullItems!;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      final posProfile = json.decode(posProfileJson);
      final posPriceList = posProfile['selling_price_list'];
      final warehouse = posProfile['warehouse'];

      final fields = [
        '"name"',
        '"item_name"',
        '"item_group"',
        '"stock_uom"',
        '"description"',
        '"image"',
        '"sales_uom"',
        '"item_defaults"',
      ];

      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=[${fields.join(',')}]'
        '&filters=[["disabled","=",0],["is_stock_item","=",1]]'
        '&limit_page_length=1000',
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في جلب الأصناف: ${itemsRes.statusCode}');
      }

      final itemsData = json.decode(itemsRes.body)['data'] as List;
      if (itemsData.isEmpty) return [];

      final result = await _processItemsData(
        itemsData,
        posPriceList: posPriceList,
        warehouse: warehouse, 
        includePrices: true, 
        includeStock: true, 
        includeUOMs: true, 
      );

      _cachedFullItems = result;
      _lastCacheTime = DateTime.now();

      return result;
    } catch (e, stack) {
      print('!!!! خطأ رئيسي في _getFullItems: $e');
      print('Stack trace: $stack');
      throw Exception('فشل في جلب الأصناف:  ${e.toString()}');
    }
  }

  static Future<List<Item>> getItems({
    String priceList = 'البيع القياسية',
    bool includePrices = true,
    bool includeStock = true,
    bool includeUOMs = true,
    bool forceRefresh = false,
  }) async {
    final fullItems = await _getFullItems(
      priceList: priceList,
      forceRefresh: forceRefresh,
    );

    return fullItems
        .where((item) {
          if (includeStock) {
            return item.qty > 0;
          }
          return true;
        })
        .map((item) {
          return Item(
            name: item.name,
            itemName: item.itemName,
            itemGroup: item.itemGroup,
            uom: item.uom,
            additionalUOMs: item.additionalUOMs,
            Item_Default: item.Item_Default,
            rate: includePrices ? item.rate : 0.0,
            qty: includeStock ? item.qty : 0.0,
            discount_amount: 0,
            discount_percentage: 0,
          );
        })
        .toList();
  }

  static Future<List<Item>> getItemsForPOS({
    String priceList = 'البيع القياسية',
    bool forceRefresh = false,
  }) async {
    final items = await _getFullItems(
      priceList: priceList,
      forceRefresh: forceRefresh,
    );
    return items.where((item) => item.qty > 0).toList(); 
  }

  static Future<List<Item>> getItemsForReturn({
    String priceList = 'البيع القياسية',
    bool forceRefresh = false,
  }) async {
    final items = await _getFullItems(
      priceList: priceList,
      forceRefresh: forceRefresh,
    );
    return items; 
  }

  static Future<List<Item>> getItemsForMaterialRequest({
    bool forceRefresh = false,
  }) async {
    final items = await _getFullItems(forceRefresh: forceRefresh);
    return items
        .map(
          (item) => Item(
            name: item.name,
            itemName: item.itemName,
            itemGroup: item.itemGroup,
            uom: item.uom,
            additionalUOMs: item.additionalUOMs,
            Item_Default: item.Item_Default,
            rate: 0.0, 
            qty: 0.0, 
            discount_amount: 0,
            discount_percentage: 0,
          ),
        )
        .toList();
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

    final futures = <Future>[];

    final pricesMap = <String, double>{};
    if (includePrices) {
      futures.add(_fetchPrices(itemNames, posPriceList, pricesMap, itemsData));
    }

    final stockMap = <String, double>{};
    if (includeStock && warehouse != null && warehouse.toString().isNotEmpty) {
      futures.add(_fetchStock(itemNames, warehouse.toString(), stockMap));
    }

    await Future.wait(futures);

    final uomsMap = <String, List<Map<String, dynamic>>>{};
    if (includeUOMs) {
      final itemsWithoutUOMs =
          itemNames.where((name) => !uomsMap.containsKey(name)).toList();
      if (itemsWithoutUOMs.isNotEmpty) {
        await _fetchAdditionalUOMs(itemsWithoutUOMs, uomsMap);
      }
    }

    final itemDefaultsMap = <String, List<Map<String, dynamic>>>{};
    await _fetchItemDefaults(itemNames, itemDefaultsMap);

    for (final item in itemsData) {
      try {
        final itemName = item['name'].toString();
        final itemObj = Item.fromJson({
          ...item,
          'rate': pricesMap[itemName] ?? 0.0,
          'currency': pricesMap.containsKey(itemName) ? 'SAR' : null,
          'stock_qty': stockMap[itemName] ?? 0.0,
          'additional_uoms': uomsMap[itemName] ?? [],
          'item_defaults': itemDefaultsMap[itemName] ?? [],
        });
        result.add(itemObj);
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
    List<dynamic> itemsData,
  ) async {
    try {
      final preferredUOMs = <String, String>{};
      final stockUOMs = <String, String>{};

      for (final item in itemsData) {
        final itemName = item['name'].toString();
        preferredUOMs[itemName] =
            item['sales_uom']?.toString() ?? item['stock_uom'].toString();
        stockUOMs[itemName] = item['stock_uom'].toString();
      }

      final priceFilters = [
        '["price_list","=","$posPriceList"]',
        '["selling","=",1]',
        '["item_code","in",${json.encode(itemNames)}]',
        '["uom","in",${json.encode(preferredUOMs.values.toSet().toList() + stockUOMs.values.toSet().toList())}]',
      ];

      final pricesRes = await ApiClient.get(
        '/api/resource/Item Price?fields=["item_code","price_list_rate","currency","uom"]'
        '&filters=[${priceFilters.join(',')}]'
        '&limit_page_length=1000',
      );

      if (pricesRes.statusCode == 200) {
        final pricesData = json.decode(pricesRes.body)['data'] as List;

        final pricesByItem = <String, List<Map<String, dynamic>>>{};
        for (final price in pricesData) {
          final itemCode = price['item_code'].toString();
          pricesByItem.putIfAbsent(itemCode, () => []).add({
            'rate':
                double.tryParse(price['price_list_rate']?.toString() ?? '0') ??
                0,
            'uom': price['uom']?.toString(),
          });
        }

        for (final itemName in itemNames) {
          final preferredUOM = preferredUOMs[itemName];
          final stockUOM = stockUOMs[itemName];

          if (pricesByItem.containsKey(itemName)) {
            final preferredPrice = pricesByItem[itemName]!.firstWhere(
              (price) => price['uom'] == preferredUOM,
              orElse: () => {'rate': 0.0, 'uom': null},
            );

            if (preferredPrice['rate'] > 0) {
              pricesMap[itemName] = preferredPrice['rate'];
            } else {
              // final stockPrice = pricesByItem[itemName]!.firstWhere(
              //   (price) => price['uom'] == stockUOM,
              //   orElse: () => {'rate': 0.0, 'uom': null},
              // );
              pricesMap[itemName] = 0.0;
              // if (stockPrice['rate'] > 0) {
              //   pricesMap[itemName] = stockPrice['rate'];
              // } else {
              //   pricesMap[itemName] = 0.0;
              // }
            }
          } else {
            pricesMap[itemName] = 0.0;
          }
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

  static Future<void> _fetchItemDefaults(
    List<String> itemNames,
    Map<String, List<Map<String, dynamic>>> itemDefaultsMap,
  ) async {
    try {
      const batchSize = 20;
      for (var i = 0; i < itemNames.length; i += batchSize) {
        final batch = itemNames.sublist(
          i,
          i + batchSize > itemNames.length ? itemNames.length : i + batchSize,
        );

        await Future.wait(
          batch.map((itemName) async {
            try {
              final res = await ApiClient.get(
                '/api/resource/Item/$itemName?fields=["item_defaults"]',
              );
              if (res.statusCode == 200) {
                final itemData = json.decode(res.body)['data'];
                if (itemData['item_defaults'] != null &&
                    itemData['item_defaults'] is List) {
                  itemDefaultsMap[itemName] =
                      (itemData['item_defaults'] as List)
                          .cast<Map<String, dynamic>>();
                }
              }
            } catch (e) {
              print('تحذير: فشل جلب item_defaults للصنف $itemName - $e');
            }
          }),
        );
      }
    } catch (e) {
      print('تحذير: فشل جلب item_defaults - $e');
    }
  }

  static Future<List<String>> getItemGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    final posProfile = json.decode(posProfileJson!) as Map<String, dynamic>;
    final itemGroups = posProfile['item_groups'];
    if (itemGroups is List) {
      if (itemGroups.isNotEmpty && itemGroups.first is Map) {
        return itemGroups.map((e) => e['item_group'].toString()).toList();
      } else {
        return itemGroups.map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  static Future<Map<String, double>> updateItemsQuantities({
    required List<String> itemNames,
    required String warehouse,
  }) async {
    try {
      final stockRes = await ApiClient.get(
        '/api/resource/Bin?fields=["item_code","actual_qty"]'
        '&filters=['
        '["item_code","in",${json.encode(itemNames)}],'
        '["actual_qty",">=","0"],'
        '["warehouse","=","$warehouse"]'
        ']'
        '&limit_page_length=1000',
      );

      if (stockRes.statusCode == 200) {
        final stockData = json.decode(stockRes.body)['data'] as List;
        final quantitiesMap = <String, double>{};

        for (final stock in stockData) {
          final itemCode = stock['item_code'].toString();
          final qty =
              double.tryParse(stock['actual_qty']?.toString() ?? '0') ?? 0;
          quantitiesMap[itemCode] = qty;
        }

        return quantitiesMap;
      } else {
        throw Exception('فشل في جلب كميات الأصناف: ${stockRes.statusCode}');
      }
    } catch (e) {
      print('خطأ في تحديث كميات الأصناف: $e');
      throw Exception('فشل في تحديث كميات الأصناف: ${e.toString()}');
    }
  }

  static void clearCache() {
    _cachedFullItems = null;
    _lastCacheTime = null;
    print('تم مسح Cache الشامل');
  }

  static Future<List<Item>> refreshItems({
    String priceList = 'البيع القياسية',
    bool includePrices = true,
    bool includeStock = true,
    bool includeUOMs = true,
  }) async {
    return getItems(
      priceList: priceList,
      includePrices: includePrices,
      includeStock: includeStock,
      includeUOMs: includeUOMs,
      forceRefresh: true,
    );
  }
}
