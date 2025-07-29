import 'dart:convert';

import 'package:drsaf/models/customer.dart';
import 'package:drsaf/models/customer_ledger_summary.dart';
import 'package:drsaf/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerLedgerService {
  static Future<List<CustomerLedgerSummary>> fetchSummary({
    required String company,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final posCustomers = await getFilteredCustomers();
      if (posCustomers.isEmpty) {
        return [];
      }

      final customerNames = posCustomers.map((c) => c.name).toList();
      print('************************$customerNames');
      final filters = json.encode({'company': company});
      final encFilters = Uri.encodeComponent(filters);

      final endpoint =
          '/api/method/frappe.desk.query_report.run'
          '?report_name=Customer%20Ledger%20Summary'
          '&as_dict=1'
          '&filters=$encFilters';

      print('→ [CustomerLedgerService] GET $endpoint');
      final res = await ApiClient.get(endpoint);
      print('************************${res.body}');

      if (res.statusCode != 200) {
        throw Exception('فشل في جلب تقرير كشف حساب العملاء');
      }

      final decoded = json.decode(res.body);
      final message = decoded['message'];
      final result = message is Map ? message['result'] : null;

      if (result is List) {
        print('************************$result');
        return result
            .whereType<Map<String, dynamic>>()
            .where(
              (item) =>
                  customerNames.contains(item['party'] ?? item['customer']),
            )
            .map(CustomerLedgerSummary.fromJsonMap)
            .toList();
      }

      return [];
    } catch (e) {
      print('Error in fetchPosCustomersSummary: $e');
      throw Exception(
        'حدث خطأ أثناء جلب ديون عملاء ملف البيع: ${e.toString()}',
      );
    }
  }

  static Future<List<Customer>> getFilteredCustomers() async {
    try {
      // 1. جلب ملف البيع الحالي
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد ملف بيع (POS Profile)');
      }

      final posProfile = json.decode(posProfileJson) as Map<String, dynamic>;
      final posProfileName = posProfile['name'] as String?;

      if (posProfileName == null || posProfileName.isEmpty) {
        throw Exception('اسم ملف البيع غير صالح');
      }

      // 2. جلب قائمة العملاء من ملف البيع
      final posResponse = await ApiClient.get(
        '/api/resource/POS Profile/$posProfileName?fields=["custom_table_customer"]',
      );

      if (posResponse.statusCode != 200) {
        throw Exception(
          'فشل في جلب بيانات ملف البيع: ${posResponse.statusCode}',
        );
      }

      final posData =
          jsonDecode(posResponse.body)['data'] as Map<String, dynamic>;
      final posCustomers = _extractPosCustomers(posData);

      if (posCustomers.isEmpty) {
        return []; // لا يوجد عملاء في ملف البيع
      }

      // 3. جلب تفاصيل العملاء الموجودين في ملف البيع فقط
      final customersResponse = await ApiClient.get(
        '/api/resource/Customer?fields=["name", "customer_name", "mobile_no", "email_id"]'
        '&filters=[["name", "in", ${json.encode(posCustomers.toList())}]]',
      );

      if (customersResponse.statusCode != 200) {
        throw Exception('فشل في جلب العملاء: ${customersResponse.statusCode}');
      }

      final customersData = jsonDecode(customersResponse.body)['data'] as List;
      return customersData.map((e) => Customer.fromJson(e)).toList();
    } catch (e) {
      print('Error in getFilteredCustomers: $e');
      throw Exception('حدث خطأ أثناء جلب العملاء: ${e.toString()}');
    }
  }

  // دالة مساعدة لاستخراج أسماء العملاء من بيانات POS Profile
  static Set<String> _extractPosCustomers(Map<String, dynamic> posData) {
    try {
      return (posData['custom_table_customer'] as List? ?? [])
          .map((e) => e['customer']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
    } catch (e) {
      print('Error extracting POS customers: $e');
      return {};
    }
  }
}
