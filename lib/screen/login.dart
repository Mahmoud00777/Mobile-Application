import 'package:drsaf/screen/PosOpeningPage.dart';
import 'package:drsaf/screen/home.dart';
import 'package:drsaf/services/auth_service.dart';
import 'package:drsaf/services/pos_service.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(primary: const Color(0xFFBDB395)),
      ),
      home: const Login(),
    );
  }
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formLoginKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBDB395), Color(0xFFBDB395)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(50),
                child: Image.asset('assets/images/45.png', fit: BoxFit.contain),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                ),
                child: Form(
                  key: _formLoginKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 30,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              labelText: 'رابط الخادم (HTTPS)',
                              prefixIcon: const Icon(Icons.link),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            cursorColor: primaryColor,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            cursorColor: primaryColor,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            cursorColor: primaryColor,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() => _rememberMe = value!);
                                    },
                                    activeColor: primaryColor,
                                  ),
                                  const Text('تذكرني'),
                                ],
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'نسيت كلمة المرور؟',
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child:
                                  _isLoading
                                      ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                      : const Text(
                                        'تسجيل الدخول',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (!_formLoginKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await AuthService.login(email, password);

      if (!mounted) return;

      Navigator.of(context).pop();

      if (success) {
        final hasOpenPOS = await PosService.hasOpenPosEntry();
        await Future.delayed(const Duration(milliseconds: 300));

        if (!hasOpenPOS) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PosOpeningPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomePage(showLoginSuccess: true),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بيانات الدخول غير صحيحة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الدخول: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
