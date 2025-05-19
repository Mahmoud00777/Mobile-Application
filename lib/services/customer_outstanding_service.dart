// lib/services/customer_outstanding_service.dart

import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/customer_outstanding.dart';
import 'api_client.dart';

class CustomerOutstandingService {
  /// 1. Fetch all customer names
  static Future<List<String>> _fetchCustomerNames() async {
    const endpoint =
        '/api/resource/Customer?fields=["name"]&limit_page_length=1000';
    print('→ [Service] GET $endpoint');
    final res = await ApiClient.get(endpoint);
    print('← [Service] status: ${res.statusCode}');
    print('← [Service] body: ${res.body}');

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'];
      return data.map<String>((e) => e['name'] as String).toList();
    }
    if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    }
    throw Exception('فشل في جلب قائمة العملاء');
  }

  /// 2. Fetch outstanding via server method get_balance_on
  static Future<CustomerOutstanding> _fetchBalance(
    String customer,
    String date,
  ) async {
    final endpoint =
        '/api/method/erpnext.accounts.utils.get_balance_on'
        '?date=$date&party_type=Customer&party=$customer';
    print('→ [Service] GET $endpoint');
    final res = await ApiClient.get(endpoint);
    print('← [Service] status: ${res.statusCode}');
    print('← [Service] body: ${res.body}');

    if (res.statusCode == 200) {
      final msg = jsonDecode(res.body)['message'];
      final balance = double.tryParse(msg.toString()) ?? 0.0;
      return CustomerOutstanding(name: customer, outstanding: balance);
    }
    if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    }
    throw Exception('فشل في جلب ملخص العميل $customer');
  }

  /// 3. Fetch all customers’ outstanding balances as of today,
  ///    then drop any with zero balance
  static Future<List<CustomerOutstanding>> fetchAll({String? asOfDate}) async {
    final names = await _fetchCustomerNames();
    final date =
        asOfDate ??
        DateFormat('yyyy-MM-dd').format(DateTime.now()); // e.g. "2025-05-11"
    final List<CustomerOutstanding> results = [];

    for (var name in names) {
      try {
        final bal = await _fetchBalance(name, date);
        results.add(bal);
      } catch (e) {
        print('Error for $name: $e');
      }
    }

    // Filter out zero‐balance customers
    final nonZero = results.where((c) => c.outstanding != 0).toList();
    print('Filtered out zeros, remaining: ${nonZero.length}');
    return nonZero;
  }
}
