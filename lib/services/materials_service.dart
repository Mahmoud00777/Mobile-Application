import 'dart:convert';

import '../models/materials_requestM.dart';
import 'api_client.dart';

class MaterialRequestService {
  static Future<void> submitMaterialRequest(MaterialRequest request) async {
    final response = await ApiClient.postJson(
      '/api/resource/Material Request',
      {
        'material_request_type': 'Purchase',
        'schedule_date': request.scheduleDate,
        'set_warehouse': request.warehouse,
        'reason': request.reason,
        'items':
            request.items
                .map(
                  (item) => {
                    'item_code': item.itemCode,
                    'qty': item.qty,
                    'schedule_date': request.scheduleDate,
                    'warehouse': request.warehouse,
                  },
                )
                .toList(),
      },
    );

    print(
      'Material Request => status: ${response.statusCode}, body: ${response.body}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 403 || response.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في إرسال طلب المواد');
    }
  }

  static Future<List<MaterialRequest>> getMaterialRequests() async {
    final res = await ApiClient.get(
      '/api/resource/Material Request?fields=["name","material_request_type","schedule_date","set_warehouse"]&limit_page_length=100&order_by=creation desc',
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
}
