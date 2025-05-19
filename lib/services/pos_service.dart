import 'dart:convert';

import 'package:drsaf/services/api_client.dart';
import 'package:drsaf/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PosService {
  static Future<bool> hasOpenPosEntry() async {
    final user = await AuthService.getCurrentUser();
    // if (user == null) throw Exception('المستخدم غير معروف أو غير مسجل الدخول');
    final res = await ApiClient.get(
      '/api/resource/POS Opening Entry?filters=[["docstatus", "=", 1], ["user", "=", "$user"], ["status", "=", "Open"]]&limit=1',
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['data'] as List).isNotEmpty;
    } else {
      throw Exception('فشل في التحقق من فتح نقطة البيع');
    }
  }

  static Future<void> createOpeningEntry(
    double cashAmount,
    Map<String, dynamic> posProfile,
  ) async {
    final user = await AuthService.getCurrentUser();
    print('the current user : $user');
    if (user == null) throw Exception('المستخدم غير معروف أو غير مسجل الدخول');

    final now = DateTime.now().toIso8601String();
    final payments = posProfile['payments'] as List<dynamic>? ?? [];
    final balanceDetails =
        payments.map((payment) {
          final mop = payment['mode_of_payment'];
          return {
            'mode_of_payment': mop,
            'opening_amount': mop == 'نقد' ? cashAmount : 0.0,
          };
        }).toList();

    final posData = {
      'pos_profile': posProfile['name'],
      'user': user,
      'opening_amount': cashAmount,
      'opening_entry_time': now,
      'period_start_date': now,
      'balance_details': balanceDetails,
    };

    final res = await ApiClient.postJson(
      '/api/resource/POS Opening Entry',
      posData,
    );

    print('POS Entry Insert Response: ${res.statusCode} - ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('فشل في إنشاء POS Opening Entry');
    }
    final name = jsonDecode(res.body)['data']['name'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_open', name);
    final submitRes = await ApiClient.putJson(
      '/api/resource/POS Opening Entry/$name',
      {'docstatus': 1},
    );
    print('Submit POS Entry: ${submitRes.statusCode} - ${submitRes.body}');
    final customers = await _getCustomersWithCoordinates(posProfile['name']);
    print('createOpeningEntry - customer: $customers');

    await _createVisitsForCustomers(
      customers: customers,
      posProfile: posProfile['name'],
      posOpeningShift: name,
      user: user,
    );
  }

  static Future<List<Map<String, dynamic>>> _getCustomersWithCoordinates(
    String posProfileName,
  ) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/POS Profile/$posProfileName?fields=["custom_table_customer"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final customers = data['custom_table_customer'] as List<dynamic>? ?? [];

        print('_getCustomersWithCoordinates - customers: $customers');

        // جلب بيانات كل عميل مع إحداثياته
        final customersWithCoords = <Map<String, dynamic>>[];
        for (final customerObj in customers) {
          final customerName = customerObj['customer']?.toString();
          if (customerName != null && customerName.isNotEmpty) {
            final customerData = await _getCustomerDetails(customerName);
            print('customersWithCoords - customers: $customerData');

            if (customerData != null) {
              customersWithCoords.add(customerData);
            }
          }
        }
        return customersWithCoords;
      }
      return [];
    } catch (e) {
      print('Error fetching customers with coordinates: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _getCustomerDetails(
    String customerName,
  ) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Customer/$customerName?fields=["name","customer_name","custom_latitude","custom_longitude"]',
      );
      print('Submit POS Entry: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        print('customer _getCustomerDetails: $data');

        return {
          'name': data['name'],
          'customer_name': data['customer_name'],
          'latitude': data['custom_latitude'],

          'longitude': data['custom_longitude'],
        };
      }
      return null;
    } catch (e) {
      print('Error fetching customer details: $e');
      return null;
    }
  }

  static Future<void> _createVisitsForCustomers({
    required List<Map<String, dynamic>> customers,
    required String posProfile,
    required String posOpeningShift,
    required String user,
  }) async {
    try {
      final now = DateTime.now();

      for (final customer in customers) {
        print('_createVisitsForCustomers - customer: $customers');

        final visitData = {
          'doctype': 'Visit',
          'customer': customer['name'],
          'pos_profile': posProfile,
          'pos_opening_shift': posOpeningShift,
          'date_time': now.toIso8601String(),
          'visit': false,
          'note': 'زيارة مخططة لفتح وردية البيع',
          'owner': user,
          'latitude': customer['latitude'],
          'longitude': customer['longitude'],
          'select_state': 'لم تتم زيارة',
        };

        final response = await ApiClient.postJson(
          '/api/resource/Visit',
          visitData,
        );

        if (response.statusCode == 200) {
          print(
            'تم إنشاء زيارة للعميل: ${customer['customer_name']} مع الإحداثيات',
          );
        } else {
          print('فشل إنشاء زيارة للعميل: ${customer['customer_name']}');
        }
      }
    } catch (e) {
      print('Error creating visits: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserPOSProfiles() async {
    try {
      // جلب جميع أسماء POS Profiles
      final res = await ApiClient.get(
        '/api/resource/POS Profile?fields=["name"]',
      );
      print('POS Profile names response: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final profileList = data['data'] as List;

        List<Map<String, dynamic>> fullProfiles = [];

        // جلب التفاصيل الكاملة لكل POS Profile بما في ذلك payments
        for (var item in profileList) {
          final profileName = item['name'];
          final detailRes = await ApiClient.get(
            '/api/resource/POS Profile/$profileName',
          );

          if (detailRes.statusCode == 200) {
            print('التفاصيل لـ POS Profile: ${detailRes.body}');

            final detailData = jsonDecode(detailRes.body);
            print('Payments: ${detailData['data']['payments']}');

            fullProfiles.add(detailData['data'] as Map<String, dynamic>);
          } else {
            print('فشل في جلب التفاصيل لـ POS Profile: $profileName');
          }
        }

        return fullProfiles;
      } else {
        throw Exception('فشل في جلب أسماء POS Profiles');
      }
    } catch (e) {
      print('خطأ أثناء جلب POS Profiles بالتفاصيل: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getSavedPOSProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_pos_profile');
    if (saved != null) {
      return jsonDecode(saved) as Map<String, dynamic>;
    }
    return null;
  }
}
