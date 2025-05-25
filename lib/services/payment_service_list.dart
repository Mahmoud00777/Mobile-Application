import 'dart:convert';
import '../models/payment_entry_list.dart';
import 'api_client.dart';

class PaymentService {
  static Future<List<PaymentEntry>> getPaymentEntries({
    String? customer,
  }) async {
    // build filters as a JSON‐encoded string
    final filters =
        customer != null && customer.isNotEmpty
            ? '[["Payment Entry", "party", "like", "%$customer%"]]'
            : '[]';

    final path =
        '/api/resource/Payment Entry'
        '?fields=["name","party","mode_of_payment","posting_date","paid_amount"]'
        '&filters=$filters'
        '&limit_page_length=50'
        '&order_by=posting_date desc';

    final res = await ApiClient.get(path);
    print('GET Payment Entry ⇒ status: ${res.statusCode}, body: ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final List data = decoded['data'];
      return data.map((e) => PaymentEntry.fromJson(e)).toList();
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في جلب بيانات الدفع');
    }
  }
}
