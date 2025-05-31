import 'package:drsaf/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Make sure this import matches the path to your AuthService class

/// A reusable drawer that shows a header with the current user's name (and icon),
/// plus menu items for About, Help, Notifications, and Logout.
class AppDrawer extends StatelessWidget {
  final VoidCallback onLogout;

  const AppDrawer({Key? key, required this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // DrawerHeader with user icon + username via FutureBuilder
            DrawerHeader(
              decoration: BoxDecoration(
                color:
                    Colors.blueAccent, // Adjust to your theme's primary color
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Static icon on the left
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Username loaded asynchronously
                  Expanded(
                    child: FutureBuilder<String?>(
                      future: AuthService.getCurrentUser(),
                      builder: (context, snapshot) {
                        // While waiting, show a placeholder
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }

                        // If there was an error or no user, show “Guest”
                        final name =
                            (snapshot.hasData &&
                                    snapshot.data != null &&
                                    snapshot.data!.isNotEmpty)
                                ? snapshot.data!
                                : 'Guest';

                        return Text(
                          name,
                          style: const TextStyle(
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

            // “About” ListTile
            ListTile(
              leading: const Icon(Icons.info, color: Colors.black87),
              title: const Text('About', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),

            // “Help” ListTile
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.black87),
              title: const Text('Help', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpPage()),
                );
              },
            ),

            // “Notifications” ListTile
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.black87),
              title: const Text(
                'Notifications',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),

            const Divider(height: 1),

            // Push Logout to the bottom

            // “Logout” ListTile
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.black87),
              title: const Text('Logout', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                onLogout(); // Invoke the callback passed from HomePage
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Dummy placeholders for navigation targets.
/// Replace these with your actual pages in your project.
class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(
        child: Text('This is the About page.', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: const Center(
        child: Text('This is the Help page.', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: Text(
          'This is the Notifications page.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
