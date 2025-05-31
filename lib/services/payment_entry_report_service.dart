import 'dart:convert';
import 'package:drsaf/models/payment_entry_report';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class PaymentEntryReportService {
  /// Fetch paginated payment entries by POS profile and date range
  static Future<List<PaymentEntryReport>> fetchReport({
    required String posProfile,
    DateTime? fromDate,
    DateTime? toDate,
    int offset = 0,
    int limit = 20,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    final posProfile = json.decode(posProfileJson!);
    final posProfileName = posProfile['name'] ?? 'Default POS Profile';
    final filters = <List<dynamic>>[
      ['custom_pos_profile', '=', posProfileName],
      if (fromDate != null)
        ['posting_date', '>=', fromDate.toIso8601String().split('T').first],
      if (toDate != null)
        ['posting_date', '<=', toDate.toIso8601String().split('T').first],
    ];
    final query =
        Uri(
          queryParameters: {
            'fields': jsonEncode([
              'name',
              'party',
              'mode_of_payment',
              'posting_date',
              'paid_amount',
            ]),
            'filters': jsonEncode(filters),
            'limit_start': offset.toString(),
            'limit_page_length': limit.toString(),
            'order_by': 'posting_date desc',
          },
        ).query;

    final endpoint = '/api/resource/Payment Entry?$query';
    final res = await ApiClient.get(endpoint);
    if (res.statusCode != 200) {
      throw Exception('Failed to load report: HTTP \${res.statusCode}');
    }

    final data = jsonDecode(res.body)['data'] as List<dynamic>;
    return data
        .map((e) => PaymentEntryReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
