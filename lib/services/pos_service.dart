import 'dart:convert';

import 'package:drsaf/services/api_client.dart';
import 'package:drsaf/services/auth_service.dart';
import 'package:intl/intl.dart';
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
      'cashier': user,
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
    final posTime = jsonDecode(res.body)['data']['period_start_date'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_open', name);
    await prefs.setString('pos_time', posTime);

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
          'data_time': DateTime.now(),
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

  static Future<void> createClosingEntry(
    double cashAmount,
    Map<String, dynamic> posProfile,
  ) async {
    try {
      // 1. التحقق من المستخدم الحالي
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('المستخدم غير معروف أو غير مسجل الدخول');
      }

      // 2. الحصول على اسم الوردية المفتوحة
      final prefs = await SharedPreferences.getInstance();
      final posOpeningName = prefs.getString('pos_open');
      if (posOpeningName == null || posOpeningName.isEmpty) {
        throw Exception('لا يوجد وردية مفتوحة للإغلاق');
      }
      print('posOpeningName === $posOpeningName');

      // 3. جلب فواتير الوردية الحالية
      final invoices = await _getShiftInvoices(posOpeningName);
      print('عدد الفواتير في الوردية: ${invoices.length}');

      // 4. إعداد بيانات الإغلاق
      final now = DateTime.now().toIso8601String();
      final payments = posProfile['payments'] as List<dynamic>? ?? [];

      final balanceDetails =
          payments.map((payment) {
            final mop = payment['mode_of_payment'];
            return {
              'mode_of_payment': mop,
              'closing_amount': mop == 'نقد' ? cashAmount : 0.0,
              'opening_amount': mop == 'نقد' ? cashAmount : 0.0,
              'expected_amount': mop == 'نقد' ? cashAmount : 0.0,
              'difference': mop == 'نقد' ? cashAmount : 0.0,
            };
          }).toList();

      // 5. تحضير بيانات فواتير المبيعات
      final invoiceTransactions =
          invoices.map((invoice) {
            return {
              'sales_invoice': invoice['name'],
              'date': invoice['posting_date'],
              'amount': invoice['grand_total'],
              'customer': invoice['customer'],
            };
          }).toList();
      print('════════ فواتير الوردية ════════');
      print('عدد الفواتير: ${invoiceTransactions.length}');
      print('──────────────────────────────');

      for (var i = 0; i < invoiceTransactions.length; i++) {
        final invoice = invoiceTransactions[i];
        print('''
📌 الفاتورة #${i + 1}
   - الرقم: ${invoice['sales_invoice']}
   - التاريخ: ${invoice['date']}
   - المبلغ: ${invoice['amount']}
   - العميل: ${invoice['customer']}
  ''');
      }

      print('════════ نهاية القائمة ════════');
      // 6. إنشاء بيانات إغلاق الوردية
      final posClosingData = {
        'pos_profile': posProfile['name'],
        'user': user,
        'closing_amount': cashAmount,
        'closing_entry_time': now,
        'period_end_date': now,
        'payment_reconciliation': balanceDetails,
        'pos_opening_entry': posOpeningName,
        'custom_sales_invoce_transactions': invoiceTransactions,
        'total_sales': invoices.fold(
          0.0,
          (sum, invoice) => sum + (invoice['grand_total'] as num).toDouble(),
        ),
      };

      // 7. إرسال طلب إنشاء إغلاق الوردية
      final res = await ApiClient.postJson(
        '/api/resource/POS Closing Entry',
        posClosingData,
      );
      print('POS Closing Entry Response: ${res.statusCode} - ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('فشل في إنشاء POS Closing Entry');
      }

      final closingEntryName = jsonDecode(res.body)['data']['name'];

      // 8. تحديث حالة الفواتير بربطها بإغلاق الوردية
      await _updateInvoicesWithClosingEntry(invoices, closingEntryName);

      // 9. تحديث حالة الوردية المفتوحة كمغلقة
      await ApiClient.putJson(
        '/api/resource/POS Opening Entry/$posOpeningName',
        {'status': 'Closed'},
      );

      // 10. حذف الوردية المفتوحة من SharedPreferences
      await prefs.remove('pos_open');

      print('تم إنشاء وإغلاق POS Closing Entry بنجاح: $closingEntryName');
    } catch (e) {
      print('حدث خطأ أثناء إنشاء POS Closing Entry: $e');
      throw Exception('حدث خطأ أثناء إنشاء إغلاق الوردية: ${e.toString()}');
    }
  }

  static Future<void> _updateInvoicesWithClosingEntry(
    List<Map<String, dynamic>> invoices,
    String closingEntryName,
  ) async {
    try {
      for (final invoice in invoices) {
        await ApiClient.putJson(
          '/api/resource/Sales Invoice/${invoice['name']}',
          {'posa_pos_closing': closingEntryName},
        );
      }
    } catch (e) {
      print('Error updating invoices with closing entry: $e');
      throw Exception('فشل في تحديث الفواتير بإغلاق الوردية');
    }
  }

  static Future<List<Map<String, dynamic>>> _getShiftInvoices(
    String posOpeningName,
  ) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["custom_pos_open_shift","=","$posOpeningName"],'
        '["status","in",["Paid","Partly Paid"]]'
        ']&fields=["name","posting_date","grand_total","customer","status"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching shift invoices: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posOpeningName = prefs.getString('pos_open');

      if (posOpeningName == null) {
        throw Exception('لا توجد وردية مفتوحة');
      }

      // الخطوة 1: جلب جميع الفواتير أولاً
      final invoicesResponse = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["custom_pos_open_shift","=","$posOpeningName"],'
        '["docstatus","=",1],'
        '["posting_date",">=","${DateFormat('yyyy-MM-dd').format(DateTime.now())}"]'
        ']&fields=["name"]',
      );

      if (invoicesResponse.statusCode != 200) {
        throw Exception('فشل في جلب الفواتير');
      }

      final invoices = List<Map<String, dynamic>>.from(
        jsonDecode(invoicesResponse.body)['data'] ?? [],
      );

      final paymentMap = <String, double>{};

      // الخطوة 2: جلب تفاصيل كل فاتورة على حدة للحصول على payments
      for (final invoice in invoices) {
        final invoiceName = invoice['name'];
        final invoiceDetail = await ApiClient.get(
          '/api/resource/Sales Invoice/$invoiceName',
        );

        if (invoiceDetail.statusCode == 200) {
          final invoiceData = jsonDecode(invoiceDetail.body)['data'];

          // الحالة 1: وجود جدول payments
          if (invoiceData['payments'] != null &&
              invoiceData['payments'] is List) {
            final payments = List<Map<String, dynamic>>.from(
              invoiceData['payments'],
            );
            for (final payment in payments) {
              final method = payment['mode_of_payment']?.toString() ?? 'نقدي';
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
              paymentMap[method] = (paymentMap[method] ?? 0) + amount;
            }
          }
          // الحالة 2: استخدام mode_of_payment الرئيسي
          else {
            final method = invoiceData['mode_of_payment']?.toString() ?? 'نقدي';
            final amount = (invoiceData['grand_total'] as num).toDouble();
            paymentMap[method] = (paymentMap[method] ?? 0) + amount;
          }
        }
      }

      return paymentMap.entries
          .map((e) => {'method': e.key, 'amount': e.value})
          .toList();
    } catch (e) {
      print('حدث خطأ في getPaymentMethods: $e');
      throw Exception('حدث خطأ أثناء جلب طرق الدفع');
    }
  }

  static Future<List<Map<String, dynamic>>> getShiftInvoices(
    String posOpeningName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final posOpeningName = prefs.getString('pos_open');
    try {
      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["custom_pos_open_shift","=","$posOpeningName"],'
        '["status","in",["Paid","Partly Paid"]],'
        '["docstatus","=",1]'
        ']&fields=["name","posting_date","grand_total","customer"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load invoices: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching invoices: $e');
      throw Exception('حدث خطأ أثناء جلب الفواتير');
    }
  }

  static Future<int> getVisitCount(String posOpeningName) async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final response = await ApiClient.get(
        '/api/resource/Visit?filters=['
        '["pos_profile","=","$posOpeningName"],'
        '["creation","like","$todayStr%"]'
        ']&fields=["name"]',
      );
      print('getVisitCount: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).length;
      }
      return 0;
    } catch (e) {
      print('Error fetching visit count: $e');
      return 0;
    }
  }

  static Future<int> getInvoiceCount(String posOpeningName) async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["pos_profile","=","$posOpeningName"],'
        '["docstatus","=",1],'
        '["is_return","=",0],'
        '["posting_date","=","$todayStr"]'
        ']&fields=["name"]',
      );
      print('getInvoiceCount: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).length;
      }
      return 0;
    } catch (e) {
      print('Error fetching invoice count: $e');
      return 0;
    }
  }

  static Future<int> getOrderCount(String posOpeningName) async {
    print('posOpeningName:$posOpeningName');
    try {
      final response = await ApiClient.get(
        '/api/resource/Material Request?filters=['
        '["custom_pos_profile","=","$posOpeningName"]]&fields=["name"]',
      );
      print('getOrderCount: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).length;
      }
      return 0;
    } catch (e) {
      print('Error fetching order count: $e');
      return 0;
    }
  }

  static Future<int> getItemCount() async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Item?filters=['
        '["is_stock_item","=",1]'
        ']&fields=["name"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).length;
      }
      return 0;
    } catch (e) {
      print('Error fetching item count: $e');
      return 0;
    }
  }

  static Future<int> getReturnInvoiceCount(String posOpeningName) async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["pos_profile","=","$posOpeningName"],'
        '["docstatus","=",1],'
        '["is_return","=",1],'
        '["posting_date","=","$todayStr"]'
        ']&fields=["name"]',
      );
      print('getInvoiceCount: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).length;
      }
      return 0;
    } catch (e) {
      print('Error fetching invoice count: $e');
      return 0;
    }
  }
}
