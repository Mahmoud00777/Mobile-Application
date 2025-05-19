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
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }

      final posProfile = json.decode(posProfileJson);
      final company = posProfile['company'] ?? 'HR';
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';
      final posPriceList = posProfile['selling_price_list'];
      final defaultModeOfPayment =
          posProfile['payments']?[0]['mode_of_payment'] ?? 'Cash';
      // final defaultPaymentAccount =
      //     posProfile['payments']?[0]['account'] ?? 'Cash - HR';

      // حساب المبلغ المتبقي
      final outstandingAmount = total - paidAmount;

      // إعداد بيانات الفاتورة
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
            'amount': paidAmount > 0 ? paidAmount : total,
          },
        ],
        'advance_paid': paidAmount,
        'outstanding_amount': outstandingAmount > 0 ? outstandingAmount : 0,
      };

      // إذا كان الدفع جزئياً، نضبط حالة الفاتورة كمسودة أولاً
      // if (outstandingAmount > 0) {
      //   invoiceData['status'] = 'Draft';
      // }

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

        // إذا كان الدفع كاملاً، نقدم الفاتورة مباشرة
        await submitSalesInvoice(invoiceName);

        return {
          'success': true,
          'invoice_name': invoiceName,
          'message':
              outstandingAmount > 0
                  ? 'تم إنشاء الفاتورة كمسودة مع وجود رصيد مستحق'
                  : 'تم إنشاء الفاتورة بنجاح',
          'outstanding_amount': outstandingAmount,
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

  static Future<Map<String, dynamic>> submitSalesInvoice(
    String invoiceName,
  ) async {
    try {
      final response = await ApiClient.putJson(
        '/api/resource/Sales Invoice/$invoiceName',
        {'docstatus': 1},
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
}
