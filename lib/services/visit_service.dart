import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visit.dart';
import 'package:drsaf/services/api_client.dart';

class VisitService {
  static String _getErrorReason(int statusCode, String body) {
    try {
      final json = jsonDecode(body);
      return json['message'] ?? json['error'] ?? 'سبب غير معروف';
    } catch (e) {
      return body.isNotEmpty ? body : 'لا توجد تفاصيل إضافية';
    }
  }

  static Future<List<Visit>> getVisits() async {
    final prefs = await SharedPreferences.getInstance();
    final posOpeningShift = prefs.getString('pos_open');

    final res = await ApiClient.get(
      '/api/resource/Visit?filters=['
      '["pos_opening_shift","=","$posOpeningShift"]'
      ']&&fields=["name","note","latitude","longitude","image","visit","select_state","customer","pos_profile","pos_opening_shift","data_time"]',
    );

    print('GET visits => status: ${res.statusCode}, body: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['data'] as List;
      return data.map((e) => Visit.fromJson(e)).toList();
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else {
      throw Exception('فشل في تحميل الزيارات');
    }
  }

  static Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/method/upload_file');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(ApiClient.headers);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);

    if (response.statusCode == 200 && data['message'] != null) {
      return data['message']['file_url'];
    } else {
      throw Exception('فشل رفع الصورة');
    }
  }

  static Future<void> saveVisit(Visit visit) async {
    final res = await ApiClient.postJson('/api/resource/Visit', visit.toJson());
    if (res.statusCode != 200) {
      throw Exception('فشل في حفظ بيانات الزيارة');
    }
  }

  static Future<void> updateVisit(Visit visit) async {
    print('Update visit => visit: ${visit.name}');

    final res = await ApiClient.putJson(
      '/api/resource/Visit/${visit.name}',
      visit.toJson(),
    );

    print('Update visit => status: ${res.statusCode}, body: ${res.body}');

    if (res.statusCode == 200) {
      return;
    } else if (res.statusCode == 403 || res.body.contains('login')) {
      throw Exception('انتهت الجلسة. الرجاء تسجيل الدخول من جديد');
    } else if (res.statusCode == 404) {
      throw Exception('الزيارة غير موجودة أو تم حذفها');
    } else if (res.statusCode == 400) {
      throw Exception('بيانات غير صالحة: ${res.body}');
    } else {
      throw Exception(
        'فشل في تعديل الزيارة (كود الخطأ: ${res.statusCode})\n'
        'السبب المحتمل: ${_getErrorReason(res.statusCode, res.body)}',
      );
    }
  }
}
