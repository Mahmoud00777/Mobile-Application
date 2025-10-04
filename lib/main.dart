import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alkhair_daem/services/api_client.dart';
import 'package:alkhair_daem/splash_screen.dart';

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
      home: SplashScreen(),
    );
  }
}
