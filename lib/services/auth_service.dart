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

  static Future<String> getValidUserEmail() async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('المستخدم غير معروف أو غير مسجل الدخول');
    }

    if (_isValidEmail(user)) {
      return user;
    }

    try {
      final response = await ApiClient.get(
        '/api/resource/User?filters=[["username","=","$user"]]&fields=["name","email"]',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final users = data['data'] as List;

        if (users.isNotEmpty) {
          final userData = users[0];
          final email = userData['email']?.toString();
          print('email === $email');

          if (email != null && email.isNotEmpty && _isValidEmail(email)) {
            currentUser = email;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('currentUser', email);
            return email;
          } else {
            throw Exception('لم يتم العثور على email صحيح للمستخدم: $user');
          }
        } else {
          throw Exception('لم يتم العثور على المستخدم: $user');
        }
      } else {
        throw Exception('فشل في جلب بيانات المستخدم: $user');
      }
    } catch (e) {
      print('Error fetching user email: $e');
      throw Exception('فشل في جلب email المستخدم: ${e.toString()}');
    }
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('currentUser');
    await prefs.remove('session_cookie');
    await prefs.remove('selected_pos_profile');
    await prefs.remove('pos_time');
    await prefs.remove('pos_open');

    currentUser = null;
    ApiClient.clearCookie();
  }
}
