import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drsaf/screen/login.dart';
import 'package:drsaf/screen/home.dart'; // شاشتك الرئيسية
import 'package:drsaf/services/api_client.dart'; // تأكد من استيراد ApiClient

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.loadCookieFromStorage();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('session_cookie');
  }

  @override
  Widget build(BuildContext context) {
    final routeObserver = RouteObserver<PageRoute>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      home: FutureBuilder<bool>(
        future: isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return const HomePage();
          } else {
            return const Login();
          }
        },
      ),
    );
  }
}
