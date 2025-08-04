import 'package:drsaf/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// CustomAppBar - AppBar مخصص مع معلومات POS Profile
///
/// كيفية الاستخدام:
/// ```dart
/// Scaffold(
///   appBar: CustomAppBar(
///     title: 'عنوان الصفحة',
///     actions: [
///       IconButton(
///         icon: Icon(Icons.settings),
///         onPressed: () {},
///       ),
///     ],
///   ),
///   body: YourContent(),
/// )
/// ```
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);

  CustomAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => Size.fromHeight(110);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: primaryColor,
      foregroundColor: secondaryColor,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _getPosProfile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(
                  'جاري تحميل بيانات POS...',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor.withOpacity(0.8),
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data != null) {
                final profile = snapshot.data!;
                return Text(
                  '${profile['company'] ?? 'شركة'}  - ${profile['warehouse'] ?? 'مخزن'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor.withOpacity(0.8),
                  ),
                );
              }

              return Text(
                'نظام نقاط البيع',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryColor.withOpacity(0.8),
                ),
              );
            },
          ),
        ],
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(30),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.9),
            border: Border(
              top: BorderSide(color: secondaryColor.withOpacity(0.2), width: 1),
            ),
          ),
          child: Center(
            child: Text(
              '© 2025 Ababeel Soft. All rights reserved.',
              style: TextStyle(
                fontSize: 10,
                color: secondaryColor.withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getPosProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString('pos_open');
      final shiftTime = prefs.getString('pos_time');

      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> profile = json.decode(jsonString);

        // إضافة معلومات المناوبة
        if (openShiftId != null && openShiftId.isNotEmpty) {
          profile['open_shift_id'] = openShiftId;
          profile['shift_status'] = 'مفتوحة';
        } else {
          profile['shift_status'] = 'مغلقة';
        }

        // إضافة وقت المناوبة
        if (shiftTime != null && shiftTime.isNotEmpty) {
          profile['shift_time'] = shiftTime;
        }

        return profile;
      }

      return null;
    } catch (e) {
      print('Error loading POS profile: $e');
      return null;
    }
  }
}

class AppDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

  AppDrawer({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: secondaryColor,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FutureBuilder<String?>(
                          future: AuthService.getCurrentUser(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Text(
                                'جاري التحميل...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }

                            final name =
                                (snapshot.hasData &&
                                        snapshot.data != null &&
                                        snapshot.data!.isNotEmpty)
                                    ? snapshot.data!
                                    : 'ضيف';

                            return Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  // POS Profile Information
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _getPosProfile(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          'جاري تحميل بيانات POS...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        );
                      }

                      if (snapshot.hasData && snapshot.data != null) {
                        final profile = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${profile['company'] ?? 'شركة'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (profile['warehouse'] != null)
                              Text(
                                '${profile['warehouse']}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        );
                      }

                      return Text(
                        'نظام نقاط البيع',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            _buildListTile(
              icon: Icons.business,
              title: 'معلومات ',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            CompanyInfoPage(primaryColor: primaryColor),
                  ),
                );
              },
            ),

            _buildListTile(
              icon: Icons.info,
              title: 'حول التطبيق',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AboutPage(primaryColor: primaryColor),
                  ),
                );
              },
            ),

            _buildListTile(
              icon: Icons.help_outline,
              title: 'المساعدة',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HelpPage(primaryColor: primaryColor),
                  ),
                );
              },
            ),

            _buildListTile(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getPosProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString('pos_open');
      final shiftTime = prefs.getString('pos_time');

      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> profile = json.decode(jsonString);

        // إضافة معلومات المناوبة
        if (openShiftId != null && openShiftId.isNotEmpty) {
          profile['open_shift_id'] = openShiftId;
          profile['shift_status'] = 'مفتوحة';
        } else {
          profile['shift_status'] = 'مغلقة';
        }

        // إضافة وقت المناوبة
        if (shiftTime != null && shiftTime.isNotEmpty) {
          profile['shift_time'] = shiftTime;
        }

        return profile;
      }

      return null;
    } catch (e) {
      print('Error loading POS profile: $e');
      return null;
    }
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: blackColor),
      title: Text(title, style: TextStyle(color: blackColor, fontSize: 16)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 0,
      dense: true,
    );
  }
}

class CompanyInfoPage extends StatelessWidget {
  final Color primaryColor;

  const CompanyInfoPage({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلومات الشركة'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getPosProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data != null) {
            final profile = snapshot.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات الشركة الأساسية
                  _buildSectionTitle('معلومات الأساسية'),
                  _buildInfoCard(
                    title: 'اسم الشركة',
                    value: profile['company'] ?? 'غير محدد',
                    icon: Icons.business,
                  ),
                  SizedBox(height: 15),
                  _buildInfoCard(
                    title: 'اسم الفرع',
                    value: profile['cost_center'] ?? 'غير محدد',
                    icon: Icons.store,
                  ),
                  SizedBox(height: 15),
                  _buildInfoCard(
                    title: 'اسم المستخدم',
                    value: profile['name'] ?? 'غير محدد',
                    icon: Icons.person,
                  ),

                  SizedBox(height: 15),
                  if (profile['open_shift_id'] != null)
                    _buildInfoCard(
                      title: 'رقم المناوبة المفتوحة',
                      value: profile['open_shift_id'],
                      icon: Icons.numbers,
                    ),
                  SizedBox(height: 15),
                  if (profile['shift_time'] != null)
                    _buildInfoCard(
                      title: 'وقت المناوبة',
                      value: profile['shift_time'],
                      icon: Icons.access_time,
                    ),
                  SizedBox(height: 30),
                  // معلومات المخزن
                  _buildSectionTitle('معلومات المخزن'),
                  _buildInfoCard(
                    title: 'اسم المخزن',
                    value: profile['warehouse'] ?? 'المخزن الرئيسي',
                    icon: Icons.warehouse,
                  ),
                  _buildSectionTitle('معلومات قائمة الأسعار'),
                  _buildInfoCard(
                    title: 'اسم قائمة الأسعار',
                    value: profile['selling_price_list'],
                    icon: Icons.warehouse,
                  ),
                ],
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'لا يمكن تحميل معلومات الشركة',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'تأكد من اختيار POS Profile',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getPosProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_pos_profile');
      final openShiftId = prefs.getString('pos_open');
      final shiftTime = prefs.getString('pos_time');

      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> profile = json.decode(jsonString);

        // إضافة معلومات المناوبة
        if (openShiftId != null && openShiftId.isNotEmpty) {
          profile['open_shift_id'] = openShiftId;
          profile['shift_status'] = 'مفتوحة';
        } else {
          profile['shift_status'] = 'مغلقة';
        }

        // إضافة وقت المناوبة
        if (shiftTime != null && shiftTime.isNotEmpty) {
          profile['shift_time'] = shiftTime;
        }

        return profile;
      }

      return null;
    } catch (e) {
      print('Error loading POS profile: $e');
      return null;
    }
  }
}

class AboutPage extends StatelessWidget {
  final Color primaryColor;

  const AboutPage({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حول التطبيق'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'هذه صفحة حول التطبيق. يمكنك هنا عرض معلومات عن التطبيق والإصدار والمطورين.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  final Color primaryColor;

  const HelpPage({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعدة'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'هذه صفحة المساعدة. يمكنك هنا العثور على إجابات للأسئلة الشائعة ودلائل الاستخدام.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
