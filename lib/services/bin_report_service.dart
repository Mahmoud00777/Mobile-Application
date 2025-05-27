import 'dart:convert';
import '../models/bin_report.dart';
import 'api_client.dart';

class BinReportService {
  /// Fetches Bin entries via the Bin doctype with warehouse and item filters.
  static Future<List<BinReport>> fetchReport({
    required String warehouse,
    String? itemCode,
    int limitStart = 0,
    int limitPageLength = 20,
  }) async {
    final filters = {
      'warehouse': warehouse,
      if (itemCode != null && itemCode.isNotEmpty)
        'item_code': ['like', '%$itemCode%'],
    };

    print('→ [BinReportService] filters: $filters');

    final queryParams = {
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

    final uri = Uri(path: '/api/resource/Bin', queryParameters: queryParams);
    print('→ [BinReportService] GET $uri');

    final res = await ApiClient.get(uri.toString());
    print('← [BinReportService] status: ${res.statusCode}');
    print('← [BinReportService] raw body: ${res.body}');

    final decoded = json.decode(res.body);
    print('← [BinReportService] decoded type: ${decoded.runtimeType}');
    if (decoded is Map<String, dynamic>) {
      print('← [BinReportService] decoded keys: ${decoded.keys.toList()}');
      if (decoded.containsKey('data')) {
        final dataList = decoded['data'];
        print(
          '← [BinReportService] dataList type: ${dataList.runtimeType}, length: ${(dataList as List).length}',
        );
      }
    }

    if (res.statusCode == 200) {
      final body = decoded as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => BinReport.fromJsonMap(m))
          .toList();
    }

    if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    }

    throw Exception('فشل في جلب بيانات Bin');
  }
}
