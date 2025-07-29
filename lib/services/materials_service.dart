import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/materials_requestM.dart';
import 'api_client.dart';

class MaterialRequestService {
  static Future<Map<String, dynamic>> submitMaterialRequest(
    MaterialRequest request,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final posProfile = json.decode(posProfileJson!);
      final posProfileName = posProfile['name'] ?? 'Default POS Profile';

      print('إنشاء طلب مواد بحالة "مقدمة" مباشرة');
      print('بيانات الطلب المرسلة: ${request.toJson()}');
      final createResponse = await ApiClient.postJson(
        '/api/resource/Material Request',
        {
          'material_request_type': 'Material Transfer',
          'schedule_date': request.scheduleDate,
          'set_warehouse': request.warehouse,
          'reason': request.reason,
          'custom_pos_profile': posProfileName,
          'docstatus': 0,
          'items':
              items
                  .map(
                    (item) => {
                      'item_code': item['name'],
                      'item_name': item['item_name'],
                      'qty': item['quantity'],
                      'uom': item['uom'] ?? 'Nos',
                    },
                  )
                  .toList(),
        },
      );

      if (createResponse.statusCode != 200) {
        throw Exception('فشل في إنشاء طلب المواد: ${createResponse.body}');
      }

      final requestName = json.decode(createResponse.body)['data']['name'];
      print('تم إنشاء طلب المواد كمسودة: $requestName');

      final submitResponse = await ApiClient.putJson(
        '/api/resource/Material Request/$requestName',
        {'docstatus': 1},
      );

      if (submitResponse.statusCode != 200) {
        throw Exception('فشل في تقديم طلب المواد: ${submitResponse.body}');
      }

      print('تم تقديم طلب المواد بنجاح: $requestName');
      return {
        'success': true,
        'name': requestName,
        'message': 'تم إنشاء وتقديم طلب المواد بنجاح',
      };
    } catch (e, stackTrace) {
      print('حدث خطأ في إنشاء طلب المواد: $e');
      print('تفاصيل الخطأ: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }

  static Future<List<MaterialRequest>> getMaterialRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    final posProfile = json.decode(posProfileJson!);
    final posProfileName = posProfile['name'];
    final res = await ApiClient.get(
      '/api/resource/Material Request?fields=["name","status","transaction_date","schedule_date","material_request_type","schedule_date","set_warehouse"]&'
      'filters=[["custom_pos_profile","=","$posProfileName"]]&order_by=name desc',
    );
    print(
      'GET Material Request => status: ${res.statusCode}, body: ${res.body}',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List requests = data['data'];

      return requests.map((item) => MaterialRequest.fromJson(item)).toList();
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في جلب طلبات المواد');
    }
  }

  static Future<List<MaterialRequest>> getMaterialStoreRequests() async {
    // final prefs = await SharedPreferences.getInstance();
    // final posProfileJson = prefs.getString('selected_pos_profile');
    // final posProfile = json.decode(posProfileJson!);
    // final posProfileName = posProfile['name'];
    final res = await ApiClient.get(
      '/api/resource/Material Request?fields=["name","status","transaction_date","schedule_date","material_request_type","schedule_date","set_warehouse"]&'
      'order_by=name desc',
    );
    print(
      'GET Material Request => status: ${res.statusCode}, body: ${res.body}',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List requests = data['data'];

      return requests.map((item) => MaterialRequest.fromJson(item)).toList();
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في جلب طلبات المواد');
    }
  }

  static Future<MaterialRequest> getMaterialRequestByName(String name) async {
    final res = await ApiClient.get('/api/resource/Material Request/$name');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return MaterialRequest.fromJson(data['data']);
    } else {
      throw Exception('فشل في جلب تفاصيل الطلب');
    }
  }

  static Future<Map<String, dynamic>> approveRequest(String requestName) async {
    try {
      print('بدأت عملية الموافقة على طلب المواد: $requestName');

      print('جاري جلب بيانات طلب المواد...');
      final request = await getMaterialRequestByName(requestName);
      print('تم جلب بيانات الطلب بنجاح. الحالة الحالية: ${request.status}');

      if (request.status == 'Transferred') {
        print('تحذير: الطلب ${request.name} تم نقله مسبقاً');
        return {'success': false, 'error': 'تم نقل المواد مسبقاً'};
      }

      print('جاري تحضير الأصناف للنقل...');
      final List<Map<String, dynamic>> items =
          request.items.map((item) {
            print(
              'إضافة صنف: ${item.itemCode} - الكمية: ${item.qty} ${item.uom}',
            );
            return {
              'item_code': item.itemCode,
              'qty': item.qty,
              'uom': item.uom,
              'rate': item.rate ?? 0.0,
              'warehouse': request.warehouse,
              'target_warehouse': request.warehouse,
            };
          }).toList();
      print('تم تحضير ${items.length} صنف للنقل');

      print('جاري إنشاء سند النقل...');
      final stockEntry = {
        'stock_entry_type': 'Material Transfer',
        'docstatus': 1,
        'from_warehouse': request.warehouse,
        'to_warehouse': request.warehouse,
        'items': items,
        'material_request': requestName,
        'posting_date': DateTime.now().toIso8601String(),
      };
      print('بيانات سند النقل: ${jsonEncode(stockEntry)}');

      final stockEntryResult = await ApiClient.postJson(
        '/api/resource/Stock Entry',
        stockEntry,
      );
      print('استجابة إنشاء سند النقل: ${stockEntryResult.statusCode}');

      if (stockEntryResult.statusCode != 200) {
        print('فشل إنشاء سند النقل. التفاصيل: ${stockEntryResult.body}');
        throw Exception('فشل في إنشاء سند النقل');
      }
      print('تم إنشاء سند النقل بنجاح: ${stockEntryResult.body}');

      print('جاري تحديث حالة طلب المواد...');
      final materialRequest = {
        'status': 'Transferred',
        'transfer_status': 'Completed',
        'per_ordered': 100,
        'per_received': 100,
      };
      print('بيانات التحديث: ${jsonEncode(materialRequest)}');

      final updateResult = await ApiClient.putJson(
        '/api/resource/Material Request/$requestName',
        materialRequest,
      );
      print('استجابة تحديث الطلب: ${updateResult.statusCode}');

      if (updateResult.statusCode != 200) {
        print('فشل تحديث حالة الطلب. التفاصيل: ${updateResult.body}');
        throw Exception('فشل في تحديث حالة الطلب');
      }
      print('تم تحديث حالة الطلب بنجاح إلى Transferred');

      print('تمت عملية الموافقة ونقل المواد بنجاح');
      return {
        'success': true,
        'stock_entry': stockEntryResult.body,
        'message': 'تم نقل المواد بنجاح',
      };
    } catch (e, stackTrace) {
      print('حدث خطأ في عملية الموافقة: $e');
      print('تفاصيل الخطأ: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }
}
