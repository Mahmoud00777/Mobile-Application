import 'dart:convert';
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
    final res = await ApiClient.get(
      '/api/resource/Customer?fields=["name","customer_name","customer_group"]',
    );

    print('GET customers => status: \${res.statusCode}, body: \${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['data'] as List;
      return data.map((e) => Customer.fromJson(e)).toList();
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في تحميل العملاء');
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
