import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/Item.dart';
import 'api_client.dart';

class ItemService {
  // تحسين التخزين المؤقت - زيادة المدة
  static List<Item>? _cachedFullItems;
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(
    minutes: 30,
  ); // تحسين من 10 إلى 30 دقيقة

  // إضافة تخزين مؤقت للأصناف الأساسية
  static List<Item>? _cachedEssentialItems;
  static DateTime? _lastEssentialCacheTime;
  static const Duration _essentialCacheDuration = Duration(minutes: 15);

  // إضافة تخزين مؤقت للبحث المحلي
  static List<Item>? _cachedSearchResults;
  static String? _lastSearchQuery;
  static DateTime? _lastSearchTime;
  static const Duration _searchCacheDuration = Duration(minutes: 5);

  // تحسين جلب الأصناف الأساسية
  static Future<List<Item>> getEssentialItems({
    String priceList = 'البيع القياسية',
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    try {
      // التحقق من التخزين المؤقت
      if (!forceRefresh &&
          _cachedEssentialItems != null &&
          _lastEssentialCacheTime != null) {
        final timeSinceLastCache = DateTime.now().difference(
          _lastEssentialCacheTime!,
        );
        if (timeSinceLastCache < _essentialCacheDuration) {
          print('📦 استخدام الأصناف الأساسية من التخزين المؤقت');
          return _cachedEssentialItems!;
        }
      }

      print('🔄 جلب الأصناف الأساسية...');

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

      // جلب الأصناف الأساسية مرتبة حسب التعديل الأخير
      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=[${fields.join(',')}]'
        '&filters=[["disabled","=",0],["is_stock_item","=",1]]'
        '&limit_page_length=$limit'
        '&order_by=modified desc', // ترتيب حسب التعديل الأخير
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في جلب الأصناف الأساسية: ${itemsRes.statusCode}');
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

      // ترتيب حسب الكمية تنازلياً
      final sortedResult =
          result.toList()..sort((a, b) => b.qty.compareTo(a.qty));

      // حفظ في التخزين المؤقت
      _cachedEssentialItems = sortedResult;
      _lastEssentialCacheTime = DateTime.now();

      print('✅ تم جلب ${sortedResult.length} صنف أساسي');
      return sortedResult;
    } catch (e, stack) {
      print('❌ خطأ في جلب الأصناف الأساسية: $e');
      print('Stack trace: $stack');
      throw Exception('فشل في جلب الأصناف الأساسية: ${e.toString()}');
    }
  }

  // تحسين البحث المحلي
  static List<Item> searchItemsLocally({
    required String query,
    required List<Item> items,
    String? itemGroup,
  }) {
    if (query.isEmpty && itemGroup == null) {
      return items;
    }

    final lowercaseQuery = query.toLowerCase();

    return items.where((item) {
      // البحث في الاسم
      final matchesName =
          item.itemName.toLowerCase().contains(lowercaseQuery) ||
          item.name.toLowerCase().contains(lowercaseQuery);

      // البحث في الوصف
      final matchesDescription =
          item.description?.toLowerCase().contains(lowercaseQuery) ?? false;

      // فلتر المجموعة
      final matchesGroup = itemGroup == null || item.itemGroup == itemGroup;

      return (matchesName || matchesDescription) && matchesGroup;
    }).toList();
  }

  // تحسين جلب الأصناف حسب المجموعة
  static Future<List<Item>> getItemsByGroup({
    required String itemGroup,
    String priceList = 'البيع القياسية',
    bool forceRefresh = false,
  }) async {
    try {
      print('🔄 جلب الأصناف لمجموعة: $itemGroup');

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
        '&filters=[["disabled","=",0],["is_stock_item","=",1],["item_group","=","$itemGroup"]]'
        '&limit_page_length=1000'
        '&order_by=modified desc',
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في جلب الأصناف للمجموعة: ${itemsRes.statusCode}');
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

      // ترتيب حسب الكمية تنازلياً
      final sortedResult =
          result.toList()..sort((a, b) => b.qty.compareTo(a.qty));

      print('✅ تم جلب ${sortedResult.length} صنف لمجموعة $itemGroup');
      return sortedResult;
    } catch (e, stack) {
      print('❌ خطأ في جلب الأصناف للمجموعة: $e');
      print('Stack trace: $stack');
      throw Exception('فشل في جلب الأصناف للمجموعة: ${e.toString()}');
    }
  }

  //     print('📄 جلب الأصناف - الصفحة ${page + 1} (${pageSize} صنف)');

  //     final prefs = await SharedPreferences.getInstance();
  //     final posProfileJson = prefs.getString('selected_pos_profile');

  //     if (posProfileJson == null || posProfileJson.isEmpty) {
  //       throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
  //     }

  //     final posProfile = json.decode(posProfileJson);
  //     final posPriceList = posProfile['selling_price_list'];
  //     final warehouse = posProfile['warehouse'];

  //     final fields = [
  //       '"name"',
  //       '"item_name"',
  //       '"item_group"',
  //       '"stock_uom"',
  //       '"description"',
  //       '"image"',
  //       '"sales_uom"',
  //       '"item_defaults"',
  //     ];

  //     // بناء الفلاتر
  //     final filters = [
  //       '["disabled","=",0]',
  //       '["is_stock_item","=",1]',
  //     ];

  //     if (query != null && query.isNotEmpty) {
  //       filters.add('["item_name","like","%$query%"]');
  //     }

  //     if (itemGroup != null) {
  //       filters.add('["item_group","=","$itemGroup"]');
  //     }

  //     final start = page * pageSize;

  //     final itemsRes = await ApiClient.get(
  //       '/api/resource/Item?fields=[${fields.join(',')}]'
  //       '&filters=[${filters.join(',')}]'
  //       '&limit_page_length=$pageSize'
  //       '&limit_start=$start'
  //       '&order_by=modified desc',
  //     );

  //     if (itemsRes.statusCode != 200) {
  //       throw Exception('فشل في جلب الأصناف: ${itemsRes.statusCode}');
  //     }

  //     final itemsData = json.decode(itemsRes.body)['data'] as List;
  //     if (itemsData.isEmpty) return [];

  //     final result = await _processItemsData(
  //       itemsData,
  //       posPriceList: posPriceList,
  //       warehouse: warehouse,
  //       includePrices: true,
  //       includeStock: true,
  //       includeUOMs: true,
  //     );

  //     // ترتيب حسب الكمية تنازلياً
  //     final sortedResult = result.toList()
  //       ..sort((a, b) => b.qty.compareTo(a.qty));

  //     print('✅ تم جلب ${sortedResult.length} صنف للصفحة ${page + 1}');
  //     return sortedResult;
  //   } catch (e, stack) {
  //     print('❌ خطأ في جلب الأصناف: $e');
  //     print('Stack trace: $stack');
  //     throw Exception('فشل في جلب الأصناف: ${e.toString()}');
  //   }
  // }

  // تحسين التخزين المؤقت - مسح محدد
  // static void clearEssentialCache() {
  //   _cachedEssentialItems = null;
  //   _lastEssentialCacheTime = null;
  //   print('📦 تم مسح تخزين الأصناف الأساسية');
  // }

  // static void clearSearchCache() {
  //   _cachedSearchResults = null;
  //   _lastSearchQuery = null;
  //   _lastSearchTime = null;
  //   print('🔍 تم مسح تخزين البحث');
  // }

  // تحسين مسح التخزين المؤقت الشامل
  // static void clearCache() {
  //   _cachedFullItems = null;
  //   _lastCacheTime = null;
  //   _cachedEssentialItems = null;
  //   _lastEssentialCacheTime = null;
  //   _cachedSearchResults = null;
  //   _lastSearchQuery = null;
  //   _lastSearchTime = null;
  //   print('🧹 تم مسح جميع التخزين المؤقت');
  // }

  static Future<List<Item>> _getFullItems({
    String priceList = 'البيع القياسية',
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && _cachedFullItems != null && _lastCacheTime != null) {
        final timeSinceLastCache = DateTime.now().difference(_lastCacheTime!);
        if (timeSinceLastCache < _cacheDuration) {
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
    print('items: ${items.length}');
    print('items: ${items.first.toJson()}');

    final sortedItems = items.toList()..sort((a, b) => b.qty.compareTo(a.qty));

    return sortedItems;
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
            imageUrl: item.imageUrl,
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

    // تم إلغاء _fetchItemDefaults

    for (final item in itemsData) {
      try {
        final itemName = item['name'].toString();
        final itemObj = Item.fromJson({
          ...item,
          'rate': pricesMap[itemName] ?? 0.0,
          'currency': pricesMap.containsKey(itemName) ? 'SAR' : null,
          'stock_qty': stockMap[itemName] ?? 0.0,
          'additional_uoms': uomsMap[itemName] ?? [],
          'item_defaults': [], // تم إلغاء _fetchItemDefaults
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
      print('🔍 بدء جلب الأسعار...');
      print('📋 عدد الأصناف: ${itemNames.length}');
      print('💰 قائمة الأسعار: $posPriceList');

      final preferredUOMs = <String, String>{};
      final stockUOMs = <String, String>{};

      for (final item in itemsData) {
        final itemName = item['name'].toString();
        preferredUOMs[itemName] =
            item['sales_uom']?.toString() ?? item['stock_uom'].toString();
        stockUOMs[itemName] = item['stock_uom'].toString();
      }

      print('📏 وحدات القياس المفضلة: $preferredUOMs');
      print('📦 وحدات القياس الأساسية: $stockUOMs');

      const batchSize = 25;
      final allPricesByItem = <String, List<Map<String, dynamic>>>{};

      for (var i = 0; i < itemNames.length; i += batchSize) {
        final batch = itemNames.sublist(
          i,
          i + batchSize > itemNames.length ? itemNames.length : i + batchSize,
        );

        print(
          '🔄 معالجة مجموعة ${(i ~/ batchSize) + 1} من ${(itemNames.length / batchSize).ceil()}',
        );
        print('📋 عدد الأصناف في هذه المجموعة: ${batch.length}');

        final priceFilters = [
          '["price_list","=","$posPriceList"]',
          '["selling","=",1]',
          '["item_code","in",${json.encode(batch)}]',
          '["uom","in",${json.encode(preferredUOMs.values.toSet().toList() + stockUOMs.values.toSet().toList())}]',
        ];

        print('🔍 فلاتر الأسعار للمجموعة: $priceFilters');

        final pricesRes = await ApiClient.get(
          '/api/resource/Item Price?fields=["item_code","price_list_rate","currency","uom"]'
          '&filters=[${priceFilters.join(',')}]'
          '&limit_page_length=1000',
        );

        print('📡 استجابة الأسعار للمجموعة - Status: ${pricesRes.statusCode}');
        print('📄 محتوى الاستجابة: ${pricesRes.body}');

        if (pricesRes.statusCode == 200) {
          final pricesData = json.decode(pricesRes.body)['data'] as List;
          print('📊 عدد أسعار المستلمة للمجموعة: ${pricesData.length}');

          for (final price in pricesData) {
            final itemCode = price['item_code'].toString();
            allPricesByItem.putIfAbsent(itemCode, () => []).add({
              'rate':
                  double.tryParse(
                    price['price_list_rate']?.toString() ?? '0',
                  ) ??
                  0,
              'uom': price['uom']?.toString(),
            });
          }
        } else {
          print('❌ فشل في جلب الأسعار للمجموعة: ${pricesRes.statusCode}');
        }
      }

      print('📋 أسعار مجمعة حسب الصنف: $allPricesByItem');

      for (final itemName in itemNames) {
        final preferredUOM = preferredUOMs[itemName];
        final stockUOM = stockUOMs[itemName];

        print('🔍 معالجة الصنف: $itemName');
        print('   - الوحدة المفضلة: $preferredUOM');
        print('   - الوحدة الأساسية: $stockUOM');

        if (allPricesByItem.containsKey(itemName)) {
          print('   - يوجد أسعار لهذا الصنف: ${allPricesByItem[itemName]}');

          final preferredPrice = allPricesByItem[itemName]!.firstWhere(
            (price) => price['uom'] == preferredUOM,
            orElse: () => {'rate': 0.0, 'uom': null},
          );

          print('   - السعر المفضل: $preferredPrice');

          if (preferredPrice['rate'] > 0) {
            pricesMap[itemName] = preferredPrice['rate'];
            print('   ✅ تم تعيين السعر: ${preferredPrice['rate']}');
          } else {
            pricesMap[itemName] = 0.0;
            print('   ⚠️ السعر صفر، تم تعيين 0.0');
          }
        } else {
          pricesMap[itemName] = 0.0;
          print('   ❌ لا يوجد أسعار لهذا الصنف، تم تعيين 0.0');
        }
      }

      print('💰 النتيجة النهائية للأسعار: $pricesMap');
    } catch (e) {
      print('❌ تحذير: فشل جلب الأسعار - $e');
    }
  }

  static Future<void> _fetchStock(
    List<String> itemNames,
    String warehouse,
    Map<String, double> stockMap,
  ) async {
    try {
      print('📦 بدء جلب المخزون...');
      print('🏪 المستودع: $warehouse');
      print('📋 عدد الأصناف: ${itemNames.length}');
      print('📋 الأصناف: $itemNames');

      const batchSize = 25;
      for (var i = 0; i < itemNames.length; i += batchSize) {
        final batch = itemNames.sublist(
          i,
          i + batchSize > itemNames.length ? itemNames.length : i + batchSize,
        );

        print(
          '🔄 معالجة مجموعة ${(i ~/ batchSize) + 1} من ${(itemNames.length / batchSize).ceil()}',
        );
        print('📋 عدد الأصناف في هذه المجموعة: ${batch.length}');

        final stockRes = await ApiClient.get(
          '/api/resource/Bin?fields=["item_code","actual_qty"]'
          '&filters=['
          '["item_code","in",${json.encode(batch)}],'
          '["actual_qty",">","0"],'
          '["warehouse","=","$warehouse"]'
          ']'
          '&limit_page_length=1000',
        );

        print('📡 استجابة المخزون للمجموعة - Status: ${stockRes.statusCode}');
        print('📄 محتوى استجابة المخزون: ${stockRes.body}');

        if (stockRes.statusCode == 200) {
          final stockData = json.decode(stockRes.body)['data'] as List;
          print('📊 عدد سجلات المخزون المستلمة للمجموعة: ${stockData.length}');

          for (final stock in stockData) {
            print('📦 معالجة سجل مخزون: $stock');
            final itemCode = stock['item_code'].toString();
            final qty =
                double.tryParse(stock['actual_qty']?.toString() ?? '0') ?? 0;
            stockMap[itemCode] = qty;
            print('   ✅ الصنف: $itemCode, الكمية: $qty');
          }
        } else {
          print('❌ فشل في جلب المخزون للمجموعة: ${stockRes.statusCode}');
        }
      }

      print('📦 النتيجة النهائية للمخزون: $stockMap');
    } catch (e) {
      print('❌ تحذير: فشل جلب المخزون - $e');
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
      print('🔄 بدء تحديث كميات الأصناف...');
      print('📋 عدد الأصناف: ${itemNames.length}');
      print('🏪 المستودع: $warehouse');
      print('📋 الأصناف: $itemNames');

      const batchSize = 25;
      final quantitiesMap = <String, double>{};

      for (var i = 0; i < itemNames.length; i += batchSize) {
        final batch = itemNames.sublist(
          i,
          i + batchSize > itemNames.length ? itemNames.length : i + batchSize,
        );

        print(
          '🔄 معالجة مجموعة ${(i ~/ batchSize) + 1} من ${(itemNames.length / batchSize).ceil()}',
        );
        print('📋 عدد الأصناف في هذه المجموعة: ${batch.length}');

        final stockRes = await ApiClient.get(
          '/api/resource/Bin?fields=["item_code","actual_qty"]'
          '&filters=['
          '["item_code","in",${json.encode(batch)}],'
          '["actual_qty",">=","0"],'
          '["warehouse","=","$warehouse"]'
          ']'
          '&limit_page_length=1000',
        );

        print(
          '📡 استجابة تحديث المخزون للمجموعة - Status: ${stockRes.statusCode}',
        );
        print('📄 محتوى استجابة تحديث المخزون: ${stockRes.body}');

        if (stockRes.statusCode == 200) {
          final stockData = json.decode(stockRes.body)['data'] as List;
          print('📊 عدد سجلات المخزون المستلمة للمجموعة: ${stockData.length}');

          for (final stock in stockData) {
            print('📦 معالجة سجل مخزون: $stock');
            final itemCode = stock['item_code'].toString();
            final qty =
                double.tryParse(stock['actual_qty']?.toString() ?? '0') ?? 0;
            quantitiesMap[itemCode] = qty;
            print('   ✅ الصنف: $itemCode, الكمية: $qty');
          }
        } else {
          print('❌ فشل في جلب كميات الأصناف للمجموعة: ${stockRes.statusCode}');
        }
      }

      print('📦 النتيجة النهائية لتحديث الكميات: $quantitiesMap');
      return quantitiesMap;
    } catch (e) {
      print('❌ خطأ في تحديث كميات الأصناف: $e');
      throw Exception('فشل في تحديث كميات الأصناف: ${e.toString()}');
    }
  }

  // تحسين جلب الأصناف مع البحث
  static Future<List<Item>> getItemsWithSearch({
    required String query,
    String? itemGroup,
    String priceList = 'البيع القياسية',
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    try {
      print(
        '🔍 البحث عن الأصناف: "$query" ${itemGroup != null ? 'في مجموعة $itemGroup' : ''}',
      );

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

      // بناء الفلاتر
      final filters = ['["disabled","=",0]', '["is_stock_item","=",1]'];

      if (query.isNotEmpty) {
        filters.add('["item_name","like","%$query%"]');
      }

      if (itemGroup != null) {
        filters.add('["item_group","=","$itemGroup"]');
      }

      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=[${fields.join(',')}]'
        '&filters=[${filters.join(',')}]'
        '&limit_page_length=$limit'
        '&order_by=modified desc',
      );

      if (itemsRes.statusCode != 200) {
        throw Exception('فشل في البحث عن الأصناف: ${itemsRes.statusCode}');
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

      // ترتيب حسب الكمية تنازلياً
      final sortedResult =
          result.toList()..sort((a, b) => b.qty.compareTo(a.qty));

      print('✅ تم العثور على ${sortedResult.length} صنف');
      return sortedResult;
    } catch (e, stack) {
      print('❌ خطأ في البحث عن الأصناف: $e');
      print('Stack trace: $stack');
      throw Exception('فشل في البحث عن الأصناف: ${e.toString()}');
    }
  }

  // تحسين التحميل التدريجي
  static Future<List<Item>> getItemsPaginated({
    String? query,
    String? itemGroup,
    String priceList = 'البيع القياسية',
    int page = 0,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    try {
      print('📄 جلب الأصناف - الصفحة ${page + 1} ($pageSize صنف)');

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

      // بناء الفلاتر
      final filters = ['["disabled","=",0]', '["is_stock_item","=",1]'];

      if (query != null && query.isNotEmpty) {
        filters.add('["item_name","like","%$query%"]');
      }

      if (itemGroup != null) {
        filters.add('["item_group","=","$itemGroup"]');
      }

      final start = page * pageSize;

      final itemsRes = await ApiClient.get(
        '/api/resource/Item?fields=[${fields.join(',')}]'
        '&filters=[${filters.join(',')}]'
        '&limit_page_length=$pageSize'
        '&limit_start=$start'
        '&order_by=modified desc',
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

      // ترتيب حسب الكمية تنازلياً
      final sortedResult =
          result.toList()..sort((a, b) => b.qty.compareTo(a.qty));

      print('✅ تم جلب ${sortedResult.length} صنف للصفحة ${page + 1}');
      return sortedResult;
    } catch (e, stack) {
      print('❌ خطأ في جلب الأصناف: $e');
      print('Stack trace: $stack');
      throw Exception('فشل في جلب الأصناف: ${e.toString()}');
    }
  }

  // تحسين التخزين المؤقت - مسح محدد
  static void clearEssentialCache() {
    _cachedEssentialItems = null;
    _lastEssentialCacheTime = null;
    print('📦 تم مسح تخزين الأصناف الأساسية');
  }

  static void clearSearchCache() {
    _cachedSearchResults = null;
    _lastSearchQuery = null;
    _lastSearchTime = null;
    print('🔍 تم مسح تخزين البحث');
  }

  // تحسين مسح التخزين المؤقت الشامل
  static void clearCache() {
    _cachedFullItems = null;
    _lastCacheTime = null;
    _cachedEssentialItems = null;
    _lastEssentialCacheTime = null;
    _cachedSearchResults = null;
    _lastSearchQuery = null;
    _lastSearchTime = null;
    print('🧹 تم مسح جميع التخزين المؤقت');
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
