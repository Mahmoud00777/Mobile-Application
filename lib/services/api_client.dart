import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://demo2.ababeel.ly';
  static String? _cookie;

  static Map<String, String> get headers => {
    if (_cookie != null) 'Cookie': _cookie!,
    'Content-Type': 'application/json',
  };

  static Future<http.Response> postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    saveAndStoreCookie(res.headers['set-cookie']);
    return res;
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.get(url, headers: headers);
  }

  static Future<http.Response> postJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final res = await http.post(url, headers: headers, body: jsonEncode(body));
    saveAndStoreCookie(res.headers['set-cookie']);
    return res;
  }

  static void saveCookie(String? cookieHeader) {
    if (cookieHeader != null) {
      _cookie = cookieHeader.split(';').first;
    }
  }

  static Future<void> saveAndStoreCookie(String? cookieHeader) async {
    if (cookieHeader != null) {
      _cookie = cookieHeader.split(';').first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', _cookie!);
    }
  }

  static Future<void> loadCookieFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('session_cookie');
  }

  static Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.delete(url, headers: headers);
  }

  static Future<http.Response> putJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final res = await http.put(url, headers: headers, body: jsonEncode(body));
    saveAndStoreCookie(res.headers['set-cookie']);
    return res;
  }

  static Future<http.Response> uploadFile(File file, {String? fileName}) async {
    final uri = Uri.parse('$baseUrl/api/method/upload_file');

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName ?? file.path.split('/').last,
      ),
    );

    request.headers.addAll(headers);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      saveAndStoreCookie(response.headers['set-cookie']);
      return response;
    } catch (e) {
      throw Exception('فشل رفع الملف: $e');
    }
  }

  static void clearCookie() {
    _cookie = null;
  }
}
