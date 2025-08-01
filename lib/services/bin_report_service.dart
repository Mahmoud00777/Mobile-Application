import 'dart:convert';
import '../models/bin_report.dart';
import 'api_client.dart';

class BinReportService {
  static Future<List<BinReport>> fetchReport({
    required String warehouse,
    String? itemCode,
    int limitStart = 0,
    int limitPageLength = 20,
  }) async {
    print(
      '→ [BinReportService] searching for: $itemCode in warehouse: $warehouse',
    );

    if (itemCode == null || itemCode.isEmpty) {
      return _fetchSimpleReport(warehouse, limitStart, limitPageLength);
    }

    return _fetchAdvancedReport(
      warehouse,
      itemCode,
      limitStart,
      limitPageLength,
    );
  }

  static Future<List<BinReport>> _fetchSimpleReport(
    String warehouse,
    int limitStart,
    int limitPageLength,
  ) async {
    final filters = {'warehouse': warehouse};

    return _fetchBinData(filters, limitStart, limitPageLength);
  }

  static Future<List<BinReport>> _fetchAdvancedReport(
    String warehouse,
    String searchTerm,
    int limitStart,
    int limitPageLength,
  ) async {
    print('→ [BinReportService] advanced search for: $searchTerm');

    List<String> matchingItemCodes = [];
    try {
      final nameResults = await _searchItemsByName(searchTerm);
      final codeResults = await _searchItemsByCode(searchTerm);

      matchingItemCodes = {...nameResults, ...codeResults}.toList();

      print(
        '→ [BinReportService] Combined results: ${matchingItemCodes.length} items',
      );
    } catch (e) {
      print('Error searching in Item table: $e');
    }

    print('→ [BinReportService] matching item codes: $matchingItemCodes');

    if (matchingItemCodes.isEmpty) {
      print('→ [BinReportService] No items found, searching directly in Bin');
      final filters = {
        'warehouse': warehouse,
        'item_code': ['like', '%$searchTerm%'],
      };
      return _fetchBinData(filters, limitStart, limitPageLength);
    }

    final filters = {
      'warehouse': warehouse,
      'item_code': ['in', matchingItemCodes],
    };
    print('→ [BinReportService] Searching Bin with filters: $filters');
    return _fetchBinData(filters, limitStart, limitPageLength);
  }

  static Future<List<String>> _searchItemsByName(String searchTerm) async {
    print('→ [BinReportService] searching items by name: $searchTerm');
    try {
      final itemQueryParams = {
        'doctype': 'Item',
        'fields': json.encode(['name']),
        'filters': json.encode({
          'item_name': ['like', '%$searchTerm%'],
        }),
        'limit_page_length': '1000',
      };
      final itemUri = Uri(
        path: '/api/method/frappe.client.get_list',
        queryParameters: itemQueryParams,
      );
      print('→ [BinReportService] Item name search URI: $itemUri');
      final itemRes = await ApiClient.get(itemUri.toString());
      print(
        '← [BinReportService] Item name search status: ${itemRes.statusCode}',
      );

      if (itemRes.statusCode == 200) {
        final itemDecoded = json.decode(itemRes.body);
        final itemList = itemDecoded['message'] as List<dynamic>? ?? [];
        final codes =
            itemList
                .map(
                  (item) =>
                      (item as Map<String, dynamic>)['name'] as String? ?? '',
                )
                .where((name) => name.isNotEmpty)
                .toList();
        print('→ [BinReportService] Found ${codes.length} items by name');
        return codes;
      }
    } catch (e) {
      print('Error searching items by name: $e');
    }
    return [];
  }

  static Future<List<String>> _searchItemsByCode(String searchTerm) async {
    print('→ [BinReportService] searching items by code: $searchTerm');
    try {
      final itemQueryParams = {
        'doctype': 'Item',
        'fields': json.encode(['name']),
        'filters': json.encode({
          'name': ['like', '%$searchTerm%'],
        }),
        'limit_page_length': '1000',
      };
      final itemUri = Uri(
        path: '/api/method/frappe.client.get_list',
        queryParameters: itemQueryParams,
      );
      print('→ [BinReportService] Item code search URI: $itemUri');
      final itemRes = await ApiClient.get(itemUri.toString());
      print(
        '← [BinReportService] Item code search status: ${itemRes.statusCode}',
      );

      if (itemRes.statusCode == 200) {
        final itemDecoded = json.decode(itemRes.body);
        final itemList = itemDecoded['message'] as List<dynamic>? ?? [];
        final codes =
            itemList
                .map(
                  (item) =>
                      (item as Map<String, dynamic>)['name'] as String? ?? '',
                )
                .where((name) => name.isNotEmpty)
                .toList();
        print('→ [BinReportService] Found ${codes.length} items by code');
        return codes;
      }
    } catch (e) {
      print('Error searching items by code: $e');
    }
    return [];
  }

  static Future<List<BinReport>> _fetchBinData(
    Map<String, dynamic> filters,
    int limitStart,
    int limitPageLength,
  ) async {
    print('→ [BinReportService] filters: $filters');

    final queryParams = {
      'doctype': 'Bin',
      'fields': json.encode([
        'warehouse',
        'item_code',
        'actual_qty',
        'projected_qty',
      ]),
      'filters': json.encode(filters),
      'order_by': 'warehouse asc, item_code asc',
      'limit_start': limitStart.toString(),
      'limit_page_length': limitPageLength.toString(),
    };

    final uri = Uri(
      path: '/api/method/frappe.client.get_list',
      queryParameters: queryParams,
    );
    print('→ [BinReportService] GET $uri');

    final res = await ApiClient.get(uri.toString());
    print('← [BinReportService] status: ${res.statusCode}');
    print('← [BinReportService] raw body: ${res.body}');

    final decoded = json.decode(res.body);
    print('← [BinReportService] decoded type: ${decoded.runtimeType}');
    if (decoded is Map<String, dynamic>) {
      print('← [BinReportService] decoded keys: ${decoded.keys.toList()}');
      if (decoded.containsKey('message')) {
        final dataList = decoded['message'];
        print(
          '← [BinReportService] dataList type: ${dataList.runtimeType}, length: ${(dataList as List).length}',
        );
      }
    }

    if (res.statusCode == 200) {
      final body = decoded as Map<String, dynamic>;
      final data = body['message'] as List<dynamic>? ?? [];

      // استخراج جميع item_codes الفريدة
      final Set<String> uniqueItemCodes = {};
      for (final item in data) {
        final itemData = item as Map<String, dynamic>;
        final itemCodeValue = itemData['item_code'] as String? ?? '';
        if (itemCodeValue.isNotEmpty) {
          uniqueItemCodes.add(itemCodeValue);
        }
      }

      print('→ [BinReportService] unique item codes: $uniqueItemCodes');

      Map<String, String> itemNames = {};
      if (uniqueItemCodes.isNotEmpty) {
        try {
          final itemQueryParams = {
            'doctype': 'Item',
            'fields': json.encode(['name', 'item_name']),
            'filters': json.encode({
              'name': ['in', uniqueItemCodes.toList()],
            }),
          };
          final itemUri = Uri(
            path: '/api/method/frappe.client.get_list',
            queryParameters: itemQueryParams,
          );
          final itemRes = await ApiClient.get(itemUri.toString());
          if (itemRes.statusCode == 200) {
            final itemDecoded = json.decode(itemRes.body);
            final itemList = itemDecoded['message'] as List<dynamic>? ?? [];
            for (final item in itemList) {
              final itemInfo = item as Map<String, dynamic>;
              final name = itemInfo['name'] as String? ?? '';
              final itemName = itemInfo['item_name'] as String? ?? '';
              if (name.isNotEmpty) {
                itemNames[name] = itemName;
              }
            }
          }
        } catch (e) {
          print('Error fetching item_names: $e');
        }
      }

      print('→ [BinReportService] item names: $itemNames');

      return data.map((item) {
        final itemData = item as Map<String, dynamic>;
        final itemCodeValue = itemData['item_code'] as String? ?? '';
        return BinReport(
          warehouse: itemData['warehouse'] as String? ?? '',
          itemCode: itemCodeValue,
          itemName: itemNames[itemCodeValue] ?? '',
          actualQty: (itemData['actual_qty'] as num?)?.toDouble() ?? 0.0,
          projectedQty: (itemData['projected_qty'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    }

    if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    }

    throw Exception('فشل في جلب بيانات Bin');
  }
}
