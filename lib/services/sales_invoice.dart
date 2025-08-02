import 'dart:convert';

import 'package:drsaf/models/customer.dart';
import 'package:drsaf/models/sales_invoice_summary.dart';
import 'package:drsaf/services/api_client.dart';
import 'package:flutter/material.dart';
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
      final openShiftId = prefs.getString('pos_open');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      if (openShiftId == null) {
        throw Exception('لا يوجد وردية مفتوحة');
      }

      final posProfile = json.decode(posProfileJson);
      final currency = posProfile['currency'];
      final debitTo = posProfile['custom_debit_to'];
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
                    'conversion_factor': item['conversion_factor'] ?? 1,
                    'cost_center': item['cost_center'],
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
        'currency': currency,
        'conversion_rate': 1,
        'debit_to': debitTo,
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

  static Future<Map<String, dynamic>?> createDraftSalesInvoice({
    required Customer customer,
    required List<Map<String, dynamic>> items,
    required double total,
    double paidAmount = 0.0,
    double outstandingAmount = 0.0,
    String priceList = 'البيع القياسية',
    DateTime? postingDate,
    DateTime? dueDate,
    double? discountAmount,
    double? discountPercentage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    final openShiftId = prefs.getString('pos_open');
    if (posProfileJson == null || posProfileJson.isEmpty) {
      throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
    }

    if (openShiftId == null) {
      throw Exception('لا يوجد وردية مفتوحة');
    }
    final posProfile = json.decode(posProfileJson);
    final currency = posProfile['currency'];
    final debitTo = posProfile['custom_debit_to'];
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
                  'conversion_factor': item['conversion_factor'] ?? 1,
                  'cost_center': item['cost_center'],
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
      'currency': currency,
      'conversion_rate': 1,
      'debit_to': debitTo,
      'selling_price_list': posPriceList,
      'ignore_pricing_rule': 0,
      'do_not_submit': 0,
      'is_pos': 1,
      'pos_profile': posProfileName,
      'update_stock': 1,
      'payments': [],
      'advance_paid': paidAmount,
      'outstanding_amount': outstandingAmount > 0 ? outstandingAmount : 0,
      'custom_pos_open_shift': openShiftId,
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
      return {'success': true, 'invoice_name': invoiceName};
    }
    return null;
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
      final currency = posProfile['currency'];
      final debitTo = posProfile['custom_debit_to'];
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';
      final posPriceList = posProfile['selling_price_list'];
      final defaultModeOfPayment =
          posProfile['payments']?[0]['mode_of_payment'] ?? 'Cash';

      outstandingAmount = total - paidAmount;
      print(paymentMethod);
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
                    'conversion_factor': item['conversion_factor'],
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
        'currency': currency,
        'conversion_rate': 1,
        'debit_to': debitTo,
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
        final fullInvoice = await getSalesInvoiceByName(invoiceName);
        final customerOutstanding = await getCustomerOutstanding(customer.name);
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
        // final visitUpdateResponse = await updateVisitStatus(
        //   customerName: customer.name,
        //   shiftId: openShiftId,
        //   newStatus: 'فاتورة',
        //   invoiceNumber: invoiceName,
        // );

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
          // 'outstanding_amount': outstandingAmount,
          // 'visit_update_status': visitUpdateResponse['success'],
          // 'visit_message': visitUpdateResponse['message'],
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

  static Future<Map<String, dynamic>> updateVisitStatus({
    required String customerName,
    required String shiftId,
    required String newStatus,
    required String invoiceNumber,
  }) async {
    try {
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

          final updateResponse =
              await ApiClient.putJson('/api/resource/Visit/$visitName', {
                'select_state': newStatus,
                'data_time': DateTime.now().toIso8601String(),
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
      final invoices = await _getCustomerInvoices(customerName);
      final totalInvoices = invoices.fold(
        0.0,
        (sum, inv) => sum + (inv['outstanding_amount'] ?? 0.0),
      );

      final payments = await _getCustomerPayments(customerName);
      final totalPayments = payments.fold(
        0.0,
        (sum, payment) => sum + (payment['paid_amount'] ?? 0.0),
      );

      return totalInvoices - totalPayments;
    } catch (e, stack) {
      debugPrint('Error calculating outstanding: $e');
      debugPrint(stack.toString());
      return 0.0;
    }
  }

  static Future<List<Map<String, dynamic>>> _getCustomerInvoices(
    String customerName,
  ) async {
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
    final response = await ApiClient.get('/api/resource/Sales Invoice?$query');
    return (json.decode(response.body)['data'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
  }

  static Future<List<Map<String, dynamic>>> _getCustomerPayments(
    String customerName,
  ) async {
    final filters = {
      'party': customerName,
      'docstatus': 1,
      'payment_type': 'Receive',
    };
    final query =
        Uri(
          queryParameters: {
            'fields': json.encode(['paid_amount']),
            'filters': json.encode(filters),
          },
        ).query;
    final response = await ApiClient.get('/api/resource/Payment Entry?$query');
    return (json.decode(response.body)['data'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
  }

  static Future<List<SalesInvoiceSummary>?> getDraftSalesinvoice() async {
    final prefs = await SharedPreferences.getInstance();
    final openShiftId = prefs.getString('pos_open');
    final posName = prefs.getString('selected_pos_profile');
    final posProfile = json.decode(posName!);

    final filters = {
      'pos_profile': posProfile['name'],
      'custom_pos_open_shift': openShiftId,
      'status': 'Draft',
      'is_return': 0,
    };

    final query =
        Uri(
          queryParameters: {
            'fields': json.encode([
              'name',
              'posting_date',
              'customer',
              'grand_total',
              'custom_pos_open_shift',
              'is_return',
              'items',
              'creation',
            ]),
            'filters': json.encode(filters),
            'order_by': 'creation desc, posting_date desc',
          },
        ).query;

    final result = '/api/resource/Sales Invoice?$query';

    final res = await ApiClient.get(result);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => SalesInvoiceSummary.fromJsonMap(m))
          .toList();
    }
    return null;
  }
  static Future<List<SalesInvoiceSummary>?> getDraftSalesReturninvoice() async {
    final prefs = await SharedPreferences.getInstance();
    final openShiftId = prefs.getString('pos_open');
    final posName = prefs.getString('selected_pos_profile');
    final posProfile = json.decode(posName!);

    final filters = {
      'pos_profile': posProfile['name'],
      'custom_pos_open_shift': openShiftId,
      'status': 'Draft',
      'is_return': 1,
    };

    final query =
        Uri(
          queryParameters: {
            'fields': json.encode([
              'name',
              'posting_date',
              'customer',
              'grand_total',
              'custom_pos_open_shift',
              'is_return',
              'items',
              'creation',
            ]),
            'filters': json.encode(filters),
            'order_by': 'creation desc, posting_date desc',
          },
        ).query;

    final result = '/api/resource/Sales Invoice?$query';

    final res = await ApiClient.get(result);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => SalesInvoiceSummary.fromJsonMap(m))
          .toList();
    }
    return null;
  }

  static Future<Map<String, dynamic>> updateSalesInvoice({
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
    String? invoName,
  }) async {
    try {
      final invoiceExists = await validateInvoiceExists(invoName!);
      print('''invoiceExists ====>> $invoiceExists''');
      if (!invoiceExists) {
        throw Exception('الفاتورة $invoName غير موجودة');
      }
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString('pos_open');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      if (openShiftId == null) {
        throw Exception('لا يوجد وردية مفتوحة');
      }

      final posProfile = json.decode(posProfileJson);
      final company = posProfile['company'] ?? 'HR';
      final currency = posProfile['currency'];
      final debitTo = posProfile['custom_debit_to'];
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';
      final posPriceList = posProfile['selling_price_list'];
      final defaultModeOfPayment =
          posProfile['payments']?[0]['mode_of_payment'] ?? 'Cash';

      outstandingAmount = total - paidAmount;
      print('discountPercentage = > $discountPercentage');
      print('discountAmount = > $discountAmount');
      print('items = > $items');

      final invoiceData = {
        'customer': customer.name,
        'customer_name': customer.customerName,
        'price_list': priceList,
        'payment_terms_template': 'test',
        'items':
            items
                .map(
                  (item) => {
                    'name': item['id'],
                    'item_code': item['name'],
                    'item_name': item['item_name'],
                    'qty': item['quantity'],
                    'rate': item['price'],
                    'uom': item['uom'] ?? 'Nos',
                    'discount_amount': item['discount_amount'] ?? 0.0,
                    'discount_percentage': item['discount_percentage'] ?? 0.0,
                    'conversion_factor': item['conversion_factor'] ?? 1,
                    'cost_center': item['cost_center'],
                    'income_account': item['income_account'],
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
        'currency': currency,
        'conversion_rate': 1,
        'debit_to': debitTo,
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
      print('''before send to update =>$invoName''');
      final response = await ApiClient.putJson(
        '/api/resource/Sales Invoice/$invoName',
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
        // final visitUpdateResponse = await updateVisitStatus(
        //   customerName: customer.name,
        //   shiftId: openShiftId,
        //   newStatus: 'فاتورة',
        //   invoiceNumber: invoiceName,
        // );
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
          // 'visit_update_status': visitUpdateResponse['success'],
          // 'visit_message': visitUpdateResponse['message'],
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

  static Future<bool> validateInvoiceExists(String invoiceName) async {
    try {
      final response = await ApiClient.get(
        '/api/resource/Sales Invoice/$invoiceName',
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteInvoice(String invoiceName) async {
    try {
      final response = await ApiClient.delete(
        '/api/resource/Sales Invoice/$invoiceName',
      );

      if (response.statusCode == 202) {
        return true;
      }
      throw Exception('Failed to delete: ${response.statusCode}');
    } catch (e) {
      throw Exception('Delete error: $e');
    }
  }

  static Future<Map<String, dynamic>?> createReturnDraftSalesInvoice({
    required Customer customer,
    required List<Map<String, dynamic>> items,
    required double total,
    double paidAmount = 0.0,
    double outstandingAmount = 0.0,
    String priceList = 'البيع القياسية',
    DateTime? postingDate,
    DateTime? dueDate,
    double? discountAmount,
    double? discountPercentage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    final openShiftId = prefs.getString('pos_open');
    if (posProfileJson == null || posProfileJson.isEmpty) {
      throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
    }

    if (openShiftId == null) {
      throw Exception('لا يوجد وردية مفتوحة');
    }
    final posProfile = json.decode(posProfileJson);
    final company = posProfile['company'] ?? 'HR';
    final currency = posProfile['currency'];
    final debitTo = posProfile['custom_debit_to'];
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
                  'qty': -item['quantity'],
                  'rate': item['price'],
                  'uom': item['uom'] ?? 'Nos',
                  'discount_amount': item['discount_amount'] ?? 0.0,
                  'discount_percentage': item['discount_percentage'] ?? 0.0,
                  'conversion_factor': item['conversion_factor'] ?? 1,
                  'cost_center': item['cost_center'],
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
      'currency': currency,
      'conversion_rate': 1,
      'debit_to': debitTo,
      'selling_price_list': posPriceList,
      'ignore_pricing_rule': 0,
      'do_not_submit': 0,
      'is_pos': 1,
      'is_return': 1,
      'pos_profile': posProfileName,
      'update_stock': 1,
      'payments': [],
      'advance_paid': paidAmount,
      'outstanding_amount': outstandingAmount > 0 ? outstandingAmount : 0,
      'custom_pos_open_shift': openShiftId,
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
      return {'success': true, 'invoice_name': invoiceName};
    }
    return null;
  }

  static Future<List<SalesInvoiceSummary>?> getDraftReturnSalesinvoice() async {
    final prefs = await SharedPreferences.getInstance();
    final openShiftId = prefs.getString('pos_open');
    final posName = prefs.getString('selected_pos_profile');
    final posProfile = json.decode(posName!);

    final filters = {
      'pos_profile': posProfile['name'],
      'custom_pos_open_shift': openShiftId,
      'status': 'Draft',
      'is_return': 1,
    };

    final query =
        Uri(
          queryParameters: {
            'fields': json.encode([
              'name',
              'posting_date',
              'customer',
              'grand_total',
              'custom_pos_open_shift',
              'is_return',
              'items',
              'creation',
            ]),
            'filters': json.encode(filters),
            'order_by': 'creation desc, posting_date desc',
          },
        ).query;

    final result = '/api/resource/Sales Invoice?$query';

    final res = await ApiClient.get(result);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => SalesInvoiceSummary.fromJsonMap(m))
          .toList();
    }
    return null;
  }

  static Future<Map<String, dynamic>> updateReturnSalesInvoice({
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
    String? invoName,
  }) async {
    try {
      final invoiceExists = await validateInvoiceExists(invoName!);
      print('''invoiceExists ====>> $invoiceExists''');
      if (!invoiceExists) {
        throw Exception('الفاتورة $invoName غير موجودة');
      }
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString('pos_open');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      if (openShiftId == null) {
        throw Exception('لا يوجد وردية مفتوحة');
      }

      final posProfile = json.decode(posProfileJson);
      final currency = posProfile['currency'];
      final debitTo = posProfile['custom_debit_to'];
      final company = posProfile['company'] ?? 'HR';
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';
      final posPriceList = posProfile['selling_price_list'];
      final defaultModeOfPayment =
          posProfile['payments']?[0]['mode_of_payment'] ?? 'Cash';

      outstandingAmount = total - paidAmount;
      print('discountPercentage = > $discountPercentage');
      print('discountAmount = > $discountAmount');
      print('items = > $items');

      final invoiceData = {
        'customer': customer.name,
        'customer_name': customer.customerName,
        'price_list': priceList,
        'payment_terms_template': 'test',
        'items':
            items
                .map(
                  (item) => {
                    'name': item['id'],
                    'item_code': item['name'],
                    'item_name': item['item_name'],
                    'qty': item['quantity'] * -1,
                    'rate': item['price'],
                    'uom': item['uom'] ?? 'Nos',
                    'discount_amount': item['discount_amount'] ?? 0.0,
                    'discount_percentage': item['discount_percentage'] ?? 0.0,
                    'conversion_factor': item['conversion_factor'] ?? 1,
                    'cost_center': item['cost_center'],
                    'income_account': item['income_account'],
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
        'currency': currency,
        'is_return': 1,
        'conversion_rate': 1,
        'debit_to': debitTo,
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
            'amount': paidAmount * -1,
          },
        ],
        'advance_paid': paidAmount * -1,
        'outstanding_amount': outstandingAmount > 0 ? outstandingAmount : 0,
        'custom_pos_open_shift': openShiftId,
        'status': 'Paid',
        'additional_discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
      };
      print('''before send to update =>$invoName''');
      final response = await ApiClient.putJson(
        '/api/resource/Sales Invoice/$invoName',
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
        // final visitUpdateResponse = await updateVisitStatus(
        //   customerName: customer.name,
        //   shiftId: openShiftId,
        //   newStatus: 'فاتورة',
        //   invoiceNumber: invoiceName,
        // );
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
          // 'visit_update_status': visitUpdateResponse['success'],
          // 'visit_message': visitUpdateResponse['message'],
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
}
