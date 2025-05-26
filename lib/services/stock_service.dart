import 'dart:convert';
import '../models/total_stock_summary.dart';
import 'api_client.dart';

class StockService {
  static Future<List<TotalStockSummary>> fetchSummary({
    required String warehouse,
    String company = 'HR',
    String groupBy = 'Warehouse',
  }) async {
    final filters = json.encode({'warehouse': warehouse, 'company': company});
    final encFilters = Uri.encodeComponent(filters);

    final endpoint =
        '/api/method/frappe.desk.query_report.run'
        '?report_name=Total%20Stock%20Summary'
        '&filters=$encFilters'
        '&group_by=$groupBy';

    print('→ [StockService] GET $endpoint');
    final res = await ApiClient.get(endpoint);
    print('← [StockService] status: ${res.statusCode}');
    print('← [StockService] body: ${res.body}');

    if (res.statusCode == 200) {
      // result is a List of Maps, not List<List>
      final message = json.decode(res.body)['message'] as Map<String, dynamic>;
      final rows = (message['result'] as List).cast<Map<String, dynamic>>();
      return rows.map((r) => TotalStockSummary.fromJsonMap(r)).toList();
    }

    if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    }

    throw Exception('فشل في جلب تقرير المخزون لمخزن $warehouse');
  }
}
