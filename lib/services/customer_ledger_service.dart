import 'dart:convert';

import 'package:drsaf/models/customer_ledger_summary.dart';
import 'package:drsaf/services/api_client.dart';

class CustomerLedgerService {
  static Future<List<CustomerLedgerSummary>> fetchSummary({
    required String company,
    required String fromDate,
    required String toDate,
  }) async {
    final filters = json.encode({
      'company': company,
      'from_date': fromDate,
      'to_date': toDate,
    });
    final encFilters = Uri.encodeComponent(filters);

    // NOTE the as_dict=1 parameter
    final endpoint =
        '/api/method/frappe.desk.query_report.run'
        '?report_name=Customer%20Ledger%20Summary'
        '&as_dict=1'
        '&filters=$encFilters';

    print('→ [CustomerLedgerService] GET $endpoint');
    final res = await ApiClient.get(endpoint);

    print('← [CustomerLedgerService] status: ${res.statusCode}');
    print('← [CustomerLedgerService] body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('فشل في جلب تقرير كشف حساب العملاء');
    }

    final decoded = json.decode(res.body);
    print(
      '← [CustomerLedgerService] decoded.runtimeType: ${decoded.runtimeType}',
    );
    print('← [CustomerLedgerService] decoded: $decoded');

    // Drill into message.result
    final message = decoded['message'];
    print('← message.runtimeType: ${message.runtimeType} → $message');

    final result = message is Map ? message['result'] : null;
    print('← result.runtimeType: ${result.runtimeType} → $result');

    if (result is List) {
      // Inspect first element if exists
      if (result.isNotEmpty) {
        print(
          '← first element type: ${result.first.runtimeType} → ${result.first}',
        );
      }
      // Now safely map only if each element is a Map
      return result
          .where((e) => e is Map<String, dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CustomerLedgerSummary.fromJsonMap)
          .toList();
    }

    throw Exception(
      'Unexpected response format: expected message.result as List',
    );
  }
}
