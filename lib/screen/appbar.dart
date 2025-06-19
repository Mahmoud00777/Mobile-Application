import 'package:drsaf/services/auth_service.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final Color primaryColor = const Color(0xFFB6B09F);
  final Color secondaryColor = const Color(0xFFEAE4D5);
  final Color backgroundColor = const Color(0xFFF2F2F2);
  final Color blackColor = const Color.fromARGB(255, 85, 84, 84);

  const AppDrawer({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // رأس الدرج مع معلومات المستخدم
            DrawerHeader(
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // أيقونة المستخدم
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: secondaryColor,
                    child: Icon(Icons.person, size: 40, color: primaryColor),
                  ),
                  const SizedBox(width: 16),
                  // اسم المستخدم
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
            ),

            // عناصر القائمة
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

            // زر تسجيل الخروج في الأعلى بعد عناصر القائمة
            _buildListTile(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),

            // إزالة Spacer و Divider
          ],
        ),
      ),
    );
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

// صفحات وهمية
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
