import 'dart:convert';
import 'api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? currentUser;

  static Future<bool> login(String email, String password) async {
    final response = await ApiClient.postForm('/api/method/login', {
      'usr': email.trim(),
      'pwd': password,
    });

    print('Response: ${response.body}');
    print('Status Code: ${response.statusCode}');
    print('Headers: ${response.headers}');

    if (response.statusCode == 200 &&
        jsonDecode(response.body)['message'] == 'Logged In') {
      currentUser = email.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', currentUser!);

      ApiClient.saveCookie(response.headers['set-cookie']);

      return true;
    }

    return false;
  }

  static Future<String?> getCurrentUser() async {
    if (currentUser != null) return currentUser;
    final prefs = await SharedPreferences.getInstance();
    currentUser = prefs.getString('currentUser');
    return currentUser;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // حذف بيانات الجلسة
    await prefs.remove('currentUser');
    await prefs.remove('session_cookie');
    await prefs.remove('selected_pos_profile');
    await prefs.remove('pos_time');
    await prefs.remove('pos_open');

    currentUser = null;
    ApiClient.clearCookie();
  }
}
