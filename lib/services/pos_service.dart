import 'dart:convert';

import 'package:drsaf/services/api_client.dart';
import 'package:drsaf/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PosService {
  static Future<bool> hasOpenPosEntry() async {
    final user = await AuthService.getCurrentUser();
    print(user);
    final res = await ApiClient.get(
      '/api/resource/POS Opening Entry?fields=["name","pos_profile","period_start_date"]&filters=[["docstatus","=",1],["user","=","$user"],["status","=","Open"]]&limit=1',
    );
    print('hasOpenPosEntry Response: ${res.statusCode} - ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final sessions = data['data'] as List;
      if (sessions.isEmpty) return false;
      // print(sessions);
      final name = sessions[0]['name'];
      final postime = sessions[0]['period_start_date'];
      final pos = sessions[0]['pos_profile'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pos_open', name);
      await prefs.setString('pos_time', postime);
      await _fetchAndSavePosProfile(pos);

      return true;
    } else {
      throw Exception('فشل في التحقق من فتح نقطة البيع');
    }
  }

  static Future<bool> checkStateOpenEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final posOpeningName = prefs.getString('pos_open');
    try {
      final res = await ApiClient.get(
        '/api/resource/POS Opening Entry/$posOpeningName?fields=["status"]',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        final status = data['status'];
        print('status: $status');
        if (status == 'Open') {
          return true;
        } else {
          await prefs.remove('pos_open');
          await prefs.remove('pos_time');
          await prefs.remove('selected_pos_profile');
          return false;
        }
      } else {
        // await prefs.remove('pos_open');
        return false;
      }
    } catch (e) {
      // await prefs.remove('pos_open');
      return false;
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
      for (final customer in customers) {
        print('_createVisitsForCustomers - customer: $customers');

        final visitData = {
          'doctype': 'Visit',
          'customer': customer['name'],
          'pos_profile': posProfile,
          'pos_opening_shift': posOpeningShift,
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

  static Future<void> createClosingEntry(
    double cashAmount,
    Map<String, dynamic> posProfile,
  ) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('المستخدم غير معروف أو غير مسجل الدخول');
      }

      final prefs = await SharedPreferences.getInstance();
      final posOpeningName = prefs.getString('pos_open');
      if (posOpeningName == null || posOpeningName.isEmpty) {
        throw Exception('لا يوجد وردية مفتوحة للإغلاق');
      }
      print('posOpeningName === $posOpeningName');

      final results = await Future.wait([
        _getShiftInvoices(posOpeningName),
        _getShiftPayment(posOpeningName),
        _getShiftVisit(posOpeningName),
        getPaymentMethodsWithPaidAmount(),
      ]);

      final invoices = results[0] as List<Map<String, dynamic>>;
      final payment = results[1] as List<Map<String, dynamic>>;
      final visits = results[2] as List<Map<String, dynamic>>;
      final paymentSummary = results[3] as Map<String, dynamic>;

      print('عدد الفواتير في الوردية: ${invoices.length}');
      print('عدد مدفوعات في الوردية: ${payment.length}');
      print('عدد زيارات في الوردية: ${visits.length}');

      final now = DateTime.now().toIso8601String();

      final paymentMethods = paymentSummary['payment_methods'] as List;

      final balanceDetails = <Map<String, dynamic>>[];
      final paymentMethodsMap = <String, double>{};

      for (final method in paymentMethods) {
        final methodName = method['method'] as String;
        final paidAmount = method['paid_amount'] as double;
        paymentMethodsMap[methodName] = paidAmount;
      }

      for (final pay in payment) {
        final method = pay['mode_of_payment']?.toString() ?? 'نقدي';
        final amount = (pay['paid_amount'] as num).toDouble();
        paymentMethodsMap[method] = (paymentMethodsMap[method] ?? 0.0) + amount;
      }

      for (final entry in paymentMethodsMap.entries) {
        balanceDetails.add({
          'mode_of_payment': entry.key,
          'closing_amount': entry.value,
          'opening_amount': 0.0,
          'expected_amount': entry.value,
          'difference': 0.0,
        });
      }

      final invoiceTransactions =
          invoices.map((invoice) {
            return {
              'sales_invoice': invoice['name'],
              'date': invoice['posting_date'],
              'amount': invoice['grand_total'],
              'customer': invoice['customer'],
            };
          }).toList();
      final paymentsTransactions =
          payment.map((pay) {
            return {'payment': pay['name'], 'customer': pay['party_name']};
          }).toList();

      final visitTransactions =
          visits.map((visit) {
            return {'visit': visit['name'], 'customer': visit['customer']};
          }).toList();
      final totalQty = invoices.fold(
        0.0,
        (sum, invoice) => sum + (invoice['total_qty'] as num).toDouble(),
      );

      print('إجمالي الكمية في جميع الفواتير: $totalQty');
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
      final sumInvoices = invoices.fold(
        0.0,
        (sum, invoice) => sum + (invoice['grand_total'] as num).toDouble(),
      );
      final sumPayments = payment.fold(
        0.0,
        (sum, pay) => sum + (pay['paid_amount'] as num).toDouble(),
      );
      final totalClosingAmount = balanceDetails.fold(
        0.0,
        (sum, detail) => sum + (detail['closing_amount'] as double),
      );
      print('مجموع closing_amount: $totalClosingAmount');
      final sumPaidAmount = totalClosingAmount;
      // final sumReturns = salesReturn.fold(
      //   0.0,
      //   (sum, ret) => sum + (ret['grand_total'] as num).toDouble(),
      // );
      final grandTotal = sumInvoices;
      final posClosingData = {
        'pos_profile': posProfile['name'],
        'user': user,
        'closing_amount': cashAmount,
        'closing_entry_time': now,
        'period_end_date': now,
        'payment_reconciliation': balanceDetails,
        'pos_opening_entry': posOpeningName,
        'custom_sales_invoce_transactions': invoiceTransactions,
        'custom_payment_transactions': paymentsTransactions,
        'custom_visit_transactions': visitTransactions,
        'custom_paid_amount': sumPaidAmount,
        'grand_total': grandTotal,
        'net_total': grandTotal,
        'total_quantity': totalQty,
        'docstatus': 1,
      };

      final res = await ApiClient.postJson(
        '/api/resource/POS Closing Entry',
        posClosingData,
      );
      print('POS Closing Entry Response: ${res.statusCode} - ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('فشل في إنشاء POS Closing Entry');
      }

      final closingEntryName = jsonDecode(res.body)['data']['name'];

      await _updateInvoicesWithClosingEntry(invoices, closingEntryName);

      // 9. تحديث حالة الوردية المفتوحة كمغلقة
      // await ApiClient.putJson(
      //   '/api/resource/POS Opening Entry/$posOpeningName',
      //   {'status': 'Closed'},
      // );

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
      final futures = invoices.map((invoice) async {
        return await ApiClient.putJson(
          '/api/resource/Sales Invoice/${invoice['name']}',
          {'posa_pos_closing': closingEntryName},
        );
      }).toList();

      await Future.wait(futures);
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
        '["status","in",["Paid","Partly Paid","Return","Unpaid"]]'
        ']&fields=["name","posting_date","grand_total","customer","status","total_qty","paid_amount"]',
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

  static Future<List<Map<String, dynamic>>> _getShiftReturnInvoices(
    String posOpeningName,
  ) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["custom_pos_open_shift","=","$posOpeningName"],'
        '["is_return","=","True"]'
        ']&fields=["name","posting_date","grand_total","customer","status","total_qty"]',
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

  static Future<List<Map<String, dynamic>>> _getShiftPayment(
    String posOpeningName,
  ) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Payment Entry?filters=['
        '["custom_pos_opening_shift","=","$posOpeningName"]'
        ']&fields=["name","party_name","paid_amount","mode_of_payment"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching shift payments: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getShiftVisit(
    String posOpeningName,
  ) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Visit?filters=['
        '["pos_opening_shift","=","$posOpeningName"]'
        ']&fields=["name","customer"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching shift payments: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getShiftPaymentEntries(
    String shiftName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final posOpeningName = prefs.getString('pos_open');
    final response = await ApiClient.get(
      '/api/resource/Payment Entry?filters=['
      '["custom_pos_opening_shift","=","$posOpeningName"],'
      '["docstatus","=",1]'
      ']&fields=["name","posting_date","paid_amount","mode_of_payment"]',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['data'] ?? [],
      );
    }
    return [];
  }
  // static Future<Map<String, dynamic>> getShiftPaymentEntries(
  //   String shiftName,
  // ) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final posOpeningName = prefs.getString('pos_open');

  //   final response = await ApiClient.get(
  //     '/api/resource/Payment Entry?filters=['
  //     '["custom_pos_opening_shift","=","$posOpeningName"],'
  //     '["docstatus","=",1]'
  //     ']&fields=["name","posting_date","paid_amount","mode_of_payment"]',
  //   );

  //   if (response.statusCode == 200) {
  //     final data = List<Map<String, dynamic>>.from(
  //       jsonDecode(response.body)['data'] ?? [],
  //     );

  //     // تجميع المدفوعات حسب طريقة الدفع
  //     final paymentSummary = <String, double>{};
  //     for (final entry in data) {
  //       final method = entry['mode_of_payment'] ?? 'غير محدد';
  //       final amount = (entry['paid_amount'] as num).toDouble();
  //       paymentSummary.update(
  //         method,
  //         (value) => value + amount,
  //         ifAbsent: () => amount,
  //       );
  //     }

  //     return {
  //       'payment_entries': data, // جميع مدفوعات الدخول
  //       'payment_summary': paymentSummary, // المجموع حسب طريقة الدفع
  //       'total_payments': paymentSummary.values.fold(
  //         0.0,
  //         (sum, amount) => sum + amount,
  //       ),
  //     };
  //   }

  //   return {
  //     'payment_entries': [],
  //     'payment_summary': {},
  //     'total_payments': 0.0,
  //   };
  // }

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
        '["docstatus","=",1]'
        ']&fields=["name"]',
      );

      if (invoicesResponse.statusCode != 200) {
        throw Exception('فشل في جلب الفواتير');
      }

      final invoices = List<Map<String, dynamic>>.from(
        jsonDecode(invoicesResponse.body)['data'] ?? [],
      );

      final paymentMap = <String, double>{};

      final futures = invoices.map((invoice) async {
        final invoiceName = invoice['name'];
        final invoiceDetail = await ApiClient.get(
          '/api/resource/Sales Invoice/$invoiceName',
        );

        if (invoiceDetail.statusCode == 200) {
          final invoiceData = jsonDecode(invoiceDetail.body)['data'];
          final payments = <Map<String, dynamic>>[];

          if (invoiceData['payments'] != null && invoiceData['payments'] is List) {
            payments.addAll(List<Map<String, dynamic>>.from(invoiceData['payments']));
          }
          else {
            final method = invoiceData['mode_of_payment']?.toString() ?? 'نقدي';
            final amount = (invoiceData['grand_total'] as num).toDouble();
            payments.add({
              'mode_of_payment': method,
              'amount': amount,
            });
          }
          
          return payments;
        }
        return <Map<String, dynamic>>[];
      }).toList();

      final results = await Future.wait(futures);

      for (final payments in results) {
        for (final payment in payments) {
          final method = payment['mode_of_payment']?.toString() ?? 'نقدي';
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
          paymentMap[method] = (paymentMap[method] ?? 0) + amount;
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
        '["status","in",["Paid","Partly Paid","Return","Unpaid"]],'
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
        '["creation","like","$todayStr%"],'
        '["select_state","!=","لم تتم زيارة"]'
        ']&fields=["name","select_state"]',
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

  static Future<int> getInvoiceCount(
    String posOpeningName,
    String posOpeningShift,
  ) async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      print('************-------------$posOpeningShift');
      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["pos_profile","=","$posOpeningName"],'
        '["custom_pos_open_shift","=","$posOpeningShift"],'
        '["docstatus","=",1],'
        '["is_return","=",0]'
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
        '["custom_pos_profile","=","$posOpeningName"],'
        '["status","=","Pending"]]'
        '&fields=["name"]',
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

  static Future<int> getReturnInvoiceCount(
    String posOpeningName,
    String posOpeningShift,
  ) async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["pos_profile","=","$posOpeningName"],'
        '["custom_pos_open_shift","=","$posOpeningShift"],'
        '["docstatus","=",1],'
        '["is_return","=",1]'
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

  static Future<void> _fetchAndSavePosProfile(String posProfileName) async {
    try {
      // 1. جلب بيانات POS Profile من API
      final response = await ApiClient.get(
        '/api/resource/POS Profile/$posProfileName',
      );

      if (response.statusCode == 200) {
        final posData =
            jsonDecode(response.body)['data'] as Map<String, dynamic>;

        // تحويل البيانات لتكون قابلة للتشفير
        final encodableData = _convertToEncodable(posData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'selected_pos_profile',
          json.encode(encodableData),
        );

        debugPrint('تم حفظ بيانات POS Profile بنجاح');
      } else {
        throw Exception('فشل في جلب بيانات نقطة البيع');
      }
    } catch (e) {
      debugPrint('Error fetching POS Profile: $e');
      throw Exception('تعذر حفظ إعدادات نقطة البيع');
    }
  }

  static Future<void> fetchAndUpdatePosProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    String? profileName;
    if (posProfileJson != null) {
      final posProfile = json.decode(posProfileJson);
      profileName = posProfile['name'];
    }
    print("profileName: $profileName");

    final response = await ApiClient.get(
      '/api/resource/POS Profile/$profileName',
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      print("data: $data");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_pos_profile', json.encode(data));
    } else {
      throw Exception('فشل في جلب POS Profile من السيرفر');
    }
  }

  static Map<String, dynamic> _convertToEncodable(Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Set) {
        result[key] = value.toList(); // تحويل Set إلى List
      } else if (value is DateTime) {
        result[key] = value.toIso8601String(); // تحويل التاريخ
      } else if (value is Map || value is List) {
        result[key] = value; // هذه الأنواع قابلة للتشفير
      } else if (value == null ||
          value is String ||
          value is num ||
          value is bool) {
        result[key] = value; // الأنواع الأساسية
      } else {
        result[key] = value.toString(); // التحويل الافتراضي
      }
    });

    return result;
  }

  static Future<Map<String, dynamic>> getPaymentMethodsWithPaidAmount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posOpeningName = prefs.getString('pos_open');

      if (posOpeningName == null) {
        throw Exception('لا توجد وردية مفتوحة');
      }

      final invoicesResponse = await ApiClient.get(
        '/api/resource/Sales Invoice?filters=['
        '["custom_pos_open_shift","=","$posOpeningName"],'
        '["docstatus","=",1],'
        '["status","in",["Paid","Partly Paid"]]'
        ']&fields=["name","grand_total","paid_amount"]',
      );

      if (invoicesResponse.statusCode != 200) {
        throw Exception('فشل في جلب الفواتير');
      }

      final invoices = List<Map<String, dynamic>>.from(
        jsonDecode(invoicesResponse.body)['data'] ?? [],
      );

      final paymentSummary = <String, Map<String, dynamic>>{};
      double totalPaidAmount = 0.0;
      double totalGrandTotal = 0.0;
      int totalInvoicesWithPayments = 0;

      for (final invoice in invoices) {
        final invoiceName = invoice['name'];
        final grandTotal = (invoice['grand_total'] as num).toDouble();
        final paidAmount = (invoice['paid_amount'] as num).toDouble();
        totalGrandTotal += grandTotal;

        final detailResponse = await ApiClient.get(
          '/api/resource/Sales Invoice/$invoiceName?fields=["payments"]',
        );
        if (detailResponse.statusCode != 200) continue;
        final detailData = jsonDecode(detailResponse.body)['data'];
        if (detailData['payments'] == null || detailData['payments'] is! List) {
          continue;
        }
        final payments = List<Map<String, dynamic>>.from(
          detailData['payments'],
        );
        if (payments.isEmpty) continue;
        totalInvoicesWithPayments++;

        for (final payment in payments) {
          final method = payment['mode_of_payment']?.toString() ?? 'نقدي';
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

          if (!paymentSummary.containsKey(method)) {
            paymentSummary[method] = {
              'method': method,
              'total_amount': 0.0,
              'paid_amount': 0.0,
              'invoice_count': 0,
              'invoices': <Map<String, dynamic>>[],
            };
          }

          paymentSummary[method]!['total_amount'] =
              (paymentSummary[method]!['total_amount'] as double) + amount;
          paymentSummary[method]!['paid_amount'] =
              (paymentSummary[method]!['paid_amount'] as double) + amount;
          paymentSummary[method]!['invoice_count'] =
              (paymentSummary[method]!['invoice_count'] as int) + 1;

          (paymentSummary[method]!['invoices'] as List<Map<String, dynamic>>).add({
            'invoice_number': invoiceName,
            'amount': amount,
            'payment_method': method,
          });
        }
      }

      totalPaidAmount = paymentSummary.values.fold(
        0.0,
        (sum, method) => sum + (method['paid_amount'] as double),
      );

      final paymentList = paymentSummary.values.toList();

      for (final method in paymentList) {
        method['percentage_of_total'] =
            totalGrandTotal > 0
                ? (method['total_amount'] as double) / totalGrandTotal * 100
                : 0.0;
        method['percentage_of_paid'] =
            totalPaidAmount > 0
                ? (method['paid_amount'] as double) / totalPaidAmount * 100
                : 0.0;
      }

      paymentList.sort(
        (a, b) =>
            (b['paid_amount'] as double).compareTo(a['paid_amount'] as double),
      );

      final result = {
        'payment_methods': paymentList,
        'summary': {
          'total_grand_total': totalGrandTotal,
          'total_paid_amount': totalPaidAmount,
          'total_invoices': invoices.length,
          'invoices_with_payments': totalInvoicesWithPayments,
          'payment_methods_count': paymentList.length,
        },
        'shift_name': posOpeningName,
        'summary_date': DateTime.now().toIso8601String(),
      };
      print('نتيجة getPaymentMethodsWithPaidAmount:');
      print(result);
      return result;
    } catch (e) {
      print('حدث خطأ في getPaymentMethodsWithPaidAmount: $e');
      throw Exception(
        'حدث خطأ أثناء تجميع طرق الدفع مع المبالغ المدفوعة: ${e.toString()}',
      );
    }
  }
}
