import 'dart:convert';
import 'package:drsaf/models/customer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_entry_list.dart';
import 'api_client.dart';

class PaymentService {
  static Future<List<PaymentEntry>> getPaymentEntries({
    String? customer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    final openShiftId = prefs.getString('pos_open');
    final posProfile = json.decode(posProfileJson!);
    final posProfileName = posProfile['name'] ?? 'Default POS Profile';
    // build filters as a JSON‐encoded string
    final List<List<dynamic>> filterList = [];

    if (customer != null && customer.isNotEmpty) {
      filterList.add(["party", "like", "%$customer%"]);
    }

    if (posProfileName != 'Default POS Profile') {
      filterList.add(["custom_pos_profile", "=", posProfileName]);
    }

    if (openShiftId != null && openShiftId.isNotEmpty) {
      filterList.add(["custom_pos_opening_shift", "=", openShiftId]);
    }

    // تحويل القائمة إلى سلسلة JSON
    final filters = json.encode(filterList);

    // استخدام الفلاتر في الاستعلام
    final res = await ApiClient.get(
      '/api/resource/Payment Entry?fields=["name","party","paid_amount","posting_date"]&filters=$filters',
    );
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

  static Future<List<Object>> getCustomerPayment() async {
    try {
      // الحصول على بيانات POS Profile من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null) {
        throw Exception('No POS Profile selected');
      }

      final posProfile = json.decode(posProfileJson);
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';

      // جلب بيانات الزبائن من API
      final response = await ApiClient.get(
        '/api/resource/POS Profile/$posProfileName?fields=["custom_table_customer"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final customers = data['custom_table_customer'] as List<dynamic>? ?? [];

        print(
          'Customer Names: ${customers.map((c) => c['customer']).toList()}',
        );

        // استخراج أسماء الزبائن فقط
        return customers
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load customers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching customer names: $e');
      return []; // إرجاع قائمة فارغة في حالة حدوث خطأ
    }
  }

  static Future<List<Map<String, dynamic>>> getPosPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع');
      }

      final posProfile = json.decode(posProfileJson) as Map<String, dynamic>;
      final paymentMethods = List<Map<String, dynamic>>.from(
        posProfile['payments'] ?? [],
      );

      for (final method in paymentMethods) {
        if (method['mode_of_payment'] == null) {
          debugPrint('تحذير: طريقة دفع بدون حقل mode_of_payment: $method');
        }
      }

      return paymentMethods;
    } catch (e) {
      debugPrint('خطأ في جلب طرق الدفع: $e');
      rethrow;
    }
  }

  static Future<String?> getDefaultAccount(String modeName) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Mode%20of%20Payment/$modeName?fields=["accounts"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
        final accounts = data['accounts'] as List<dynamic>? ?? [];

        if (accounts.isNotEmpty) {
          // جلب أول حساب كحساب افتراضي
          final firstAccount = accounts.first as Map<String, dynamic>;
          return firstAccount['default_account']?.toString();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching default account: $e');
      return null;
    }
  }
}
