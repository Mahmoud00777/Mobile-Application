import 'dart:convert';

import 'package:drsaf/models/customer.dart';
import 'package:drsaf/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesInvoice {
  static Future<Map<String, dynamic>> createSalesInvoice({
    required Customer customer,
    required List<Map<String, dynamic>> items,
    required double total,
    required Map<String, dynamic> paymentMethod,
    double paidAmount = 0.0,
    double outstandingAmount = 0.0,
    String priceList = 'البيع القياسية',
    DateTime? postingDate,
    DateTime? dueDate,
    double? discountAmount,
    double? discountPercentage,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString(
        'pos_open',
      ); // الحصول على رقم الوردية المفتوحة

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      if (openShiftId == null) {
        throw Exception('لا يوجد وردية مفتوحة');
      }

      final posProfile = json.decode(posProfileJson);
      final company = posProfile['company'] ?? 'HR';
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';
      final posPriceList = posProfile['selling_price_list'];
      final defaultModeOfPayment =
          posProfile['payments']?[0]['mode_of_payment'] ?? 'Cash';

      outstandingAmount = total - paidAmount;
      print('discountPercentage = > $discountPercentage');
      print('discountAmount = > $discountAmount');

      final invoiceData = {
        'customer': customer.name,
        'customer_name': customer.customerName,
        'price_list': priceList,
        'payment_terms_template': 'test',
        'items':
            items
                .map(
                  (item) => {
                    'item_code': item['name'],
                    'item_name': item['item_name'],
                    'qty': item['quantity'],
                    'rate': item['price'],
                    'uom': item['uom'] ?? 'Nos',
                    'discount_amount': item['discount_amount'] ?? 0.0,
                    'discount_percentage': item['discount_percentage'] ?? 0.0,
                    'conversion_factor': 1,
                  },
                )
                .toList(),
        'taxes_and_charges': '',
        'posting_date':
            postingDate?.toIso8601String().split('T')[0] ??
            DateTime.now().toIso8601String().split('T')[0],
        'due_date':
            dueDate?.toIso8601String().split('T')[0] ??
            DateTime.now()
                .add(Duration(days: 30))
                .toIso8601String()
                .split('T')[0],
        'company': company,
        'currency': 'LYD',
        'conversion_rate': 1,
        'debit_to': '1310 - مدينون - HR',
        'selling_price_list': posPriceList,
        'ignore_pricing_rule': 0,
        'do_not_submit': 0,
        'is_pos': 1,
        'pos_profile': posProfileName,
        'update_stock': 1,
        'payments': [
          {
            'mode_of_payment':
                paymentMethod['mode_of_payment'] ?? defaultModeOfPayment,
            'amount': paidAmount,
          },
        ],
        'advance_paid': paidAmount,
        'outstanding_amount': outstandingAmount > 0 ? outstandingAmount : 0,
        'custom_pos_open_shift': openShiftId,
        'status': 'Paid',
        'additional_discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
      };

      final response = await ApiClient.postJson(
        '/api/resource/Sales Invoice',
        invoiceData,
      );

      print(
        'Sales Invoice => status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final invoiceName = responseData['data']['name'];

        final result = await submitSalesInvoice(invoiceName);
        print('shiftId => shiftId: $openShiftId');
        final visitUpdateResponse = await updateVisitStatus(
          customerName: customer.name,
          shiftId: openShiftId,
          newStatus: 'فاتورة',
          invoiceNumber: invoiceName,
        );
        final fullInvoice = await getSalesInvoiceByName(invoiceName);
        final customerOutstanding = await getCustomerOutstanding(customer.name);
        return {
          'success': true,
          'result': result,
          'invoice_name': invoiceName,
          'full_invoice': fullInvoice,
          'customer_outstanding': customerOutstanding,
          'message':
              outstandingAmount > 0
                  ? 'تم إنشاء الفاتورة كمسودة مع وجود رصيد مستحق'
                  : 'تم إنشاء الفاتورة بنجاح',
          'outstanding_amount': outstandingAmount,
          'visit_update_status': visitUpdateResponse['success'],
          'visit_message': visitUpdateResponse['message'],
        };
      } else {
        return {
          'success': false,
          'error': 'فشل في إنشاء الفاتورة: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'حدث خطأ أثناء إنشاء الفاتورة: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createReturnSalesInvoice({
    required Customer customer,
    required List<Map<String, dynamic>> items,
    required double total,
    required Map<String, dynamic> paymentMethod,
    double paidAmount = 0.0,
    double outstandingAmount = 0.0,
    String priceList = 'البيع القياسية',
    DateTime? postingDate,
    DateTime? dueDate,
    String? notes,
    required List<String> attachedImages,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString(
        'pos_open',
      ); // الحصول على رقم الوردية المفتوحة

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      if (openShiftId == null) {
        throw Exception('لا يوجد وردية مفتوحة');
      }

      final posProfile = json.decode(posProfileJson);
      final company = posProfile['company'] ?? 'HR';
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';
      final posPriceList = posProfile['selling_price_list'];
      final defaultModeOfPayment =
          posProfile['payments']?[0]['mode_of_payment'] ?? 'Cash';

      // حساب المبلغ المتبقي
      outstandingAmount = total - paidAmount;

      // إعداد بيانات الفاتورة
      final invoiceData = {
        'customer': customer.name,
        'customer_name': customer.customerName,
        'price_list': priceList,
        'remarks': notes,
        'payment_terms_template': 'test',
        "is_return": 1,
        'items':
            items
                .map(
                  (item) => {
                    'item_code': item['name'],
                    'item_name': item['item_name'],
                    'qty': -item['quantity'],
                    'rate': item['price'],
                    'uom': item['uom'] ?? 'Nos',
                    'conversion_factor': 1,
                  },
                )
                .toList(),
        'taxes_and_charges': '',
        'posting_date':
            postingDate?.toIso8601String().split('T')[0] ??
            DateTime.now().toIso8601String().split('T')[0],
        'due_date':
            dueDate?.toIso8601String().split('T')[0] ??
            DateTime.now()
                .add(Duration(days: 30))
                .toIso8601String()
                .split('T')[0],
        'company': company,
        'currency': 'LYD',
        'conversion_rate': 1,
        'debit_to': '1310 - مدينون - HR',
        'selling_price_list': posPriceList,
        'ignore_pricing_rule': 0,
        'do_not_submit': 0,
        'is_pos': 1,
        'pos_profile': posProfileName,
        'update_stock': 1,
        'payments': [
          {
            'mode_of_payment':
                paymentMethod['mode_of_payment'] ?? defaultModeOfPayment,
            'amount': -paidAmount,
          },
        ],
        'advance_paid': -paidAmount,
        'outstanding_amount': outstandingAmount > 0 ? outstandingAmount : 0,
        'custom_pos_open_shift': openShiftId,
        'status': 'Paid',
      };

      final response = await ApiClient.postJson(
        '/api/resource/Sales Invoice',
        invoiceData,
      );

      print(
        'Sales Invoice => status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final invoiceName = responseData['data']['name'];
        Map<String, dynamic> File;
        print(attachedImages);
        for (var imageUrl in attachedImages) {
          File = {
            "file_url": imageUrl,
            "attached_to_name": invoiceName,
            "attached_to_doctype": "Sales Invoice",
            "is_private": 0,
          };
          await ApiClient.postJson('/api/resource/File', File);
        }

        final result = await submitSalesInvoice(invoiceName);
        print('shiftId => shiftId: $openShiftId');
        final visitUpdateResponse = await updateVisitStatus(
          customerName: customer.name,
          shiftId: openShiftId,
          newStatus: 'فاتورة',
          invoiceNumber: invoiceName,
        );

        return {
          'success': true,
          'result': result,
          'invoice_name': invoiceName,
          'message':
              outstandingAmount > 0
                  ? 'تم إنشاء الفاتورة كمسودة مع وجود رصيد مستحق'
                  : 'تم إنشاء الفاتورة بنجاح',
          'outstanding_amount': outstandingAmount,
          'visit_update_status': visitUpdateResponse['success'],
          'visit_message': visitUpdateResponse['message'],
        };
      } else {
        return {
          'success': false,
          'error': 'فشل في إنشاء الفاتورة: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'حدث خطأ أثناء إنشاء الفاتورة: ${e.toString()}',
      };
    }
  }

  // دالة مساعدة لتحديث حالة الزيارة
  static Future<Map<String, dynamic>> updateVisitStatus({
    required String customerName,
    required String shiftId,
    required String newStatus,
    required String invoiceNumber,
  }) async {
    try {
      // 1. البحث عن الزيارة المفتوحة لهذا الزبون والوردية
      final visitResponse = await ApiClient.get(
        '/api/resource/Visit?fields=["name"]'
        '&filters=['
        '["customer","=","$customerName"],'
        '["pos_opening_shift","=","$shiftId"],'
        '["select_state","=","لم تتم زيارة"]'
        ']',
      );

      if (visitResponse.statusCode == 200) {
        final visits = json.decode(visitResponse.body)['data'] as List;

        if (visits.isNotEmpty) {
          final visitName = visits.first['name'];

          // 2. تحديث حالة الزيارة
          final updateResponse =
              await ApiClient.putJson('/api/resource/Visit/$visitName', {
                'select_state': newStatus,
                'data_time': DateTime.now().toIso8601String().split('T')[0],
              });

          if (updateResponse.statusCode == 200) {
            return {
              'success': true,
              'message': 'تم تحديث حالة الزيارة بنجاح',
              'visit_name': visitName,
            };
          } else {
            return {
              'success': false,
              'error': 'فشل في تحديث الزيارة: ${updateResponse.statusCode}',
              'details': updateResponse.body,
            };
          }
        } else {
          return {
            'success': false,
            'error': 'لا توجد زيارة مفتوحة لهذا الزبون والوردية',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'فشل في البحث عن الزيارة: ${visitResponse.statusCode}',
          'details': visitResponse.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'حدث خطأ أثناء تحديث الزيارة: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> submitSalesInvoice(
    String invoiceName,
  ) async {
    try {
      final response = await ApiClient.putJson(
        '/api/resource/Sales Invoice/$invoiceName',
        {'docstatus': 1},
      );
      print(
        'submitSalesInvoice => status: ${response.statusCode}, body: ${response.body}',
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'تم إرسال الفاتورة بنجاح',
          'invoice_name': invoiceName,
          'status': 'Submitted',
        };
      } else {
        return {
          'success': false,
          'error': 'فشل في إرسال الفاتورة: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'حدث خطأ أثناء إرسال الفاتورة: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getSalesInvoiceByName(String name) async {
    final res = await ApiClient.get('/api/resource/Sales Invoice/$name');

    if (res.statusCode == 200) {
      return json.decode(res.body)['data'];
    } else {
      throw Exception('فشل في جلب بيانات الفاتورة');
    }
  }

  static Future<double> getCustomerOutstanding(String customerName) async {
    try {
      final filters = {
        'customer': customerName,
        'docstatus': '1',
        'outstanding_amount': ['>', 0],
      };
      final query =
          Uri(
            queryParameters: {
              'fields': json.encode(['name', 'outstanding_amount']),
              'filters': json.encode(filters),
            },
          ).query;
      final response = await ApiClient.get(
        '/api/resource/Sales Invoice?$query',
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في جلب فواتير الزبون');
      }

      final data = json.decode(response.body)['data'];
      print('getCustomerOutstanding*-*-*--*-*-*-*-*-*-*-*--*-*$data');

      // 2. جمع جميع القيم المتبقية
      double totalOutstanding = 0.0;
      for (final invoice in data) {
        final amount = invoice['outstanding_amount'] ?? 0.0;
        if (amount is num) {
          totalOutstanding += amount.toDouble();
        } else if (amount is String) {
          totalOutstanding += double.tryParse(amount) ?? 0.0;
        }
      }

      return totalOutstanding;
    } catch (e) {
      print('خطأ في حساب الرصيد المستحق: $e');
      return 0.0;
    }
  }
}
