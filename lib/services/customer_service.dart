import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../models/customer_group.dart';
import 'api_client.dart';

class CustomerService {
  static Future<void> addCustomer(Customer customer) async {
    final res = await ApiClient.postJson(
      '/api/resource/Customer',
      customer.toJson(),
    );

    print('Add customer => status: \${res.statusCode}, body: \${res.body}');

    if (res.statusCode == 200) {
      return;
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في إضافة العميل');
    }
  }

  static Future<List<Customer>> getCustomers() async {
    try {
      // 1. جلب بيانات POS Profile المحدد
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null) {
        throw Exception('لم يتم اختيار ملف POS');
      }

      final posProfile = json.decode(posProfileJson) as Map<String, dynamic>;
      final posProfileName = posProfile['name'] as String? ?? 'الملف الافتراضي';

      // 2. جلب قائمة العملاء في POS Profile
      final posResponse = await ApiClient.get(
        '/api/resource/POS Profile/$posProfileName?fields=["custom_table_customer"]',
      );

      if (posResponse.statusCode != 200) {
        throw Exception('فشل في جلب بيانات POS Profile');
      }

      final posData =
          jsonDecode(posResponse.body)['data'] as Map<String, dynamic>;
      final posCustomers =
          (posData['custom_table_customer'] as List? ?? [])
              .map((e) => e['customer']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet();

      // 3. جلب كل العملاء من النظام
      final customersResponse = await ApiClient.get(
        '/api/resource/Customer?fields=["name","customer_name","customer_group"]',
      );

      if (customersResponse.statusCode == 200) {
        final customersData =
            jsonDecode(customersResponse.body)['data'] as List;

        // 4. تصفية العملاء الموجودين في POS Profile فقط
        return customersData
            .where(
              (customer) => posCustomers.contains(
                customer['customer_name']?.toString() ?? '',
              ),
            )
            .map((e) => Customer.fromJson(e))
            .toList();
      } else {
        throw Exception('فشل في جلب قائمة العملاء');
      }
    } catch (e) {
      // debugPrint('حدث خطأ: $e');
      return [];
    }
  }

  static Future<List<CustomerGroup>> getCustomerGroups() async {
    final res = await ApiClient.get(
      '/api/resource/Customer Group?fields=["name"]',
    );
    final data = jsonDecode(res.body)['data'] as List;
    return data.map((e) => CustomerGroup.fromJson(e)).toList();
  }

  static Future<void> deleteCustomer(String name) async {
    await ApiClient.delete('/api/resource/Customer/$name');
  }

  static Future<void> updateCustomer(Customer customer) async {
    final res = await ApiClient.putJson(
      '/api/resource/Customer/${customer.name}',
      customer.toJson(),
    );

    print('Update customer => status: ${res.statusCode}, body: ${res.body}');

    if (res.statusCode == 200) {
      return;
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في تعديل العميل');
    }
  }
}
