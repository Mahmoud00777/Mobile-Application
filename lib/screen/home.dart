import 'package:drsaf/screen/customer_outstanding_page.dart';
import 'package:drsaf/screen/login.dart';
import 'package:drsaf/screen/materials_request.dart';
import 'package:drsaf/screen/pos.dart';
import 'package:drsaf/screen/visit.dart';
import 'package:drsaf/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  final bool showLoginSuccess;

  const HomePage({super.key, this.showLoginSuccess = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color primaryRed = const Color.fromARGB(255, 156, 20, 20);
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);

  final List<Map<String, dynamic>> buttons = [
    {'label': 'POS', 'icon': Icons.point_of_sale},
    {'label': 'MATERIAL REQUESTS', 'icon': Icons.inventory_2},
    {'label': 'PAYMENTS & DEBTS', 'icon': Icons.payments},
    {'label': 'VISIT LOG', 'icon': Icons.assignment_turned_in},
    {'label': 'RETURNS', 'icon': Icons.assignment_return},
    {'label': 'REPORTS', 'icon': Icons.analytics},
  ];

  Map<String, dynamic>? selectedPOSProfile;

  @override
  void initState() {
    super.initState();
    if (widget.showLoginSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدخول بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
    _loadSelectedPOSProfile();
  }

  Future<void> _loadSelectedPOSProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('selected_pos_profile');
    if (jsonString != null) {
      setState(() {
        selectedPOSProfile = jsonDecode(jsonString);
      });
      print('تم تحميل POS Profile: ${selectedPOSProfile!['name']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'الصفحة الرئيسية',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () => print('Open notifications'),
        ),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: secondaryColor,
              child: Icon(Icons.person, color: primaryColor),
            ),
            onPressed: () => print('Open profile'),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // if (selectedPOSProfile != null)
              //   Padding(
              //     padding: const EdgeInsets.only(bottom: 16.0),
              //     child: Text(
              //       'POS Profile: ${selectedPOSProfile!['name']}',
              //       style: TextStyle(
              //         fontSize: 16,
              //         fontWeight: FontWeight.bold,
              //         color: primaryColor,
              //       ),
              //     ),
              //   ),
              _buildDashboardCard(),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: buttons.length,
                  itemBuilder:
                      (context, index) => _buildButton(buttons[index], context),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await AuthService.logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                  );
                },
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(Map<String, dynamic> button, BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: primaryColor, width: 2),
        ),
        overlayColor: pressedColor,
        elevation: 8,
        // ignore: deprecated_member_use
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      onPressed: () {
        if (button['label'] == 'VISIT LOG') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VisitScreen()),
          );
        } else if (button['label'] == 'MATERIAL REQUESTS') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MaterialRequestPage(),
            ),
          );
        } else if (button['label'] == 'POS') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => POSScreen()),
          );
        } else if (button['label'] == 'PAYMENTS & DEBTS') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CustomerOutstandingPage()),
          );
        } else {
          print('${button['label']} pressed');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(button['icon'] as IconData, size: 40, color: primaryColor),
          const SizedBox(height: 10),
          Text(
            button['label'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard() {
    return Card(
      color: primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8, // زيادة الظل لجعلها ثلاثية الأبعاد
      shadowColor: Colors.black.withOpacity(0.5), // اللون الأسود للظل
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard, size: 36, color: secondaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'لوحة الإحصائيات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: secondaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.shopping_cart, '120', 'الطلبات'),
                _buildStatItem(Icons.assignment_turned_in, '45', 'الزيارات'),
                _buildStatItem(Icons.assignment_return, '10', 'المرتجعات'),
                _buildStatItem(Icons.inventory, '230', 'مخزوني'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: secondaryColor),
        const SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: secondaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: secondaryColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
