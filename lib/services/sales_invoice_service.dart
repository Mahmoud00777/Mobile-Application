import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sales_invoice_summary.dart';
import 'api_client.dart';

class SalesInvoiceService {
  /// Fetch Sales Invoices with optional customer search, return filter, and pagination.
  static Future<List<SalesInvoiceSummary>> fetchInvoices({
    required String company,
    required String fromDate,
    required String toDate,
    String? customer,
    int? isReturn, // 1 for returns, 0 for non-returns
    int limitStart = 0,
    int limitPageLength = 20,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final openShiftId = prefs.getString('pos_open');
    final filters = {
      'company': company,
      'custom_pos_open_shift': openShiftId,
      'posting_date': [
        'between',
        [fromDate, toDate],
      ],
      if (customer != null && customer.isNotEmpty)
        'customer': ['like', '%$customer%'],
      if (isReturn != null) 'is_return': isReturn,
    };

    final query =
        Uri(
          queryParameters: {
            'fields': json.encode([
              'name',
              'posting_date',
              'customer',
              'grand_total',
              'custom_pos_open_shift',
              'is_return',
            ]),
            'filters': json.encode(filters),
            'order_by': 'posting_date desc',
            'limit_start': limitStart.toString(),
            'limit_page_length': limitPageLength.toString(),
          },
        ).query;

    final endpoint = '/api/resource/Sales Invoice?$query';
    print('→ [SalesInvoiceService] GET $endpoint');

    final res = await ApiClient.get(endpoint);
    print('← [SalesInvoiceService] status: ${res.statusCode}');
    print('← [SalesInvoiceService] body: ${res.body}');

    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => SalesInvoiceSummary.fromJsonMap(m))
          .toList();
    }

    if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    }

    throw Exception('فشل في جلب فواتير المبيعات');
  }
}
