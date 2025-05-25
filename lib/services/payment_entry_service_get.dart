//this for v2
import 'dart:convert';
import '../models/payment_entry_list.dart';
import 'api_client.dart';

class PaymentEntryServiceGet {
  // Fetch payment entries filtered by customer
  static Future<List<PaymentEntry>> fetchByCustomer(String customerName) async {
    final filters = [
      ["Payment Entry", "party", "=", customerName],
    ];

    final url =
        '/api/resource/Payment Entry?fields=["name","party","mode_of_payment","posting_date","paid_amount"]'
        '&filters=${Uri.encodeComponent(jsonEncode(filters))}'
        '&limit_page_length=50&order_by=posting_date desc';

    final res = await ApiClient.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'];
      return data.map((e) => PaymentEntry.fromJson(e)).toList();
    } else {
      throw Exception('فشل في جلب السجلات');
    }
  }

  // Fetch customer balance using server method
  static Future<double> fetchCustomerBalance(String customer) async {
    final now = DateTime.now().toIso8601String().split("T").first;

    final endpoint =
        '/api/method/erpnext.accounts.utils.get_balance_on'
        '?date=$now&party_type=Customer&party=$customer';

    final res = await ApiClient.get(endpoint);

    if (res.statusCode == 200) {
      final msg = jsonDecode(res.body)['message'];
      return double.tryParse(msg.toString()) ?? 0.0;
    } else {
      throw Exception('فشل في جلب الرصيد');
    }
  }

  /////
}
