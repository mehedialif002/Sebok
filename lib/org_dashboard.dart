import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'main.dart';
import 'verify.dart';
import 'PointsAddPage.dart';
import 'blood_request_list.dart';

import 'sms_test_page.dart';
class OrgDashboard extends StatelessWidget {
  final String userId;

  const OrgDashboard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Dashboard'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.red[900],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.bloodtype, color: Colors.red, size: 30),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Organization',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Points Add'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PointsAddPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Donor Verify'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BloodRequestsPage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Request Manage'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SMSPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                final supabase = SupabaseConfig.client;
                await supabase.auth.signOut();

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organization',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Sebok',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 1.0,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [

                _buildDashboardCard(
                  icon: Icons.add_circle,
                  title: 'Points Add',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PointsAddPage()),
                    );
                  },
                ),
                _buildDashboardCard(
                  icon: Icons.add_circle,
                  title: 'Donor Verify',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BloodRequestsPage()),
                    );
                  },
                ),
                _buildDashboardCard(
                  icon: Icons.add_circle,
                  title: 'Request Manage',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SMSPage()),
                    );
                  },
                ),

                _buildDashboardCard(
                  icon: Icons.manage_accounts,
                  title: 'Request Manage',
                  onTap: () {
                    // Navigate to request management
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.red[900]),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}