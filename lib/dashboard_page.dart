import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'main.dart'; // make sure this has LoginPage
import 'request_form_page.dart';
import 'requests_list_page.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'profile_page.dart';
import 'donation_history_page.dart';

class DashboardPage extends StatefulWidget {
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  String? username;
  int? score = 0; // Initialize with 0
  DateTime? lastDonate;
  DateTime? nextDonate;
  String? userBloodGroup;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchPointsFromDonations(); // Fetch points from donations table
    subscribeToBloodRequests();
  }

  Future<void> fetchUserData() async {
    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      setState(() {
        username = response['name'];

        // Parse last_donate date
        if (response['last_donate'] != null) {
          lastDonate = DateTime.parse(response['last_donate']);
        }

        // Parse next_donate date
        if (response['next_donate'] != null) {
          nextDonate = DateTime.parse(response['next_donate']);
        }

        userBloodGroup = response['blood_group'];
      });
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> fetchPointsFromDonations() async {
    final supabase = SupabaseConfig.client;

    try {
      // Fetch all donations for this user and sum the points
      final response = await supabase
          .from('donations')
          .select('points_earned')
          .eq('donor_id', widget.userId);

      // Calculate total points from donations
      int totalPoints = 0;
      if (response != null && response is List) {
        for (var donation in response) {
          totalPoints += (donation['points_earned'] as num).toInt();
        }
      }

      setState(() {
        score = totalPoints;
        isLoading = false;
      });

      // Also update the users table to keep it synchronized
      await supabase
          .from('users')
          .update({'total_points': totalPoints})
          .eq('id', widget.userId);

    } catch (e) {
      print("Error fetching points from donations: $e");

      // Fallback: try to get points from users table if donations query fails
      try {
        final userResponse = await supabase
            .from('users')
            .select('total_points')
            .eq('id', widget.userId)
            .single();

        setState(() {
          score = userResponse['total_points'] ?? 0;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          score = 0;
          isLoading = false;
        });
      }
    }
  }

  void subscribeToBloodRequests() {
    final supabase = SupabaseConfig.client;
    final channel = supabase.channel('realtime:requests');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'requests',
      callback: (payload) {
        final request = payload.newRecord;
        final bloodGroup = request['blood_group'];
        final location = request['location'];
        final hospital = request['hospital'];
        final neededBy = request['needed_by'];

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "🩸 $bloodGroup blood needed at $hospital, $location by $neededBy",
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      },
    );

    channel.subscribe();
  }

  // Helper function to format dates
  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return DateFormat('dd MMMM, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("সেবক", style: TextStyle(color: Colors.white)),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.red),
              accountName: Text(username ?? "Loading..."),
              accountEmail: Text("Points: ${score ?? 0}"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.red[900]),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userId: widget.userId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Donation History"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DonationHistoryPage(userId: widget.userId),
                  ),
                );
              },
            ),
            const Divider(),
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
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Blood Requests"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestsListPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome ${username ?? ''}",
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text("YOUR POINTS", style: TextStyle(fontSize: 16)),
            Text("${score ?? 0}",
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold,
                    color: Colors.red)),
            const SizedBox(height: 25),

            // Last Donation Date
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bloodtype, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Last Donation",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lastDonate != null
                        ? _formatDate(lastDonate)
                        : "You haven't donated yet",
                    style: TextStyle(
                      fontSize: 16,
                      color: lastDonate != null ? Colors.black : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Next Donation Date
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Next Eligible Donation",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nextDonate != null
                        ? _formatDate(nextDonate)
                        : "You can donate anytime",
                    style: TextStyle(
                      fontSize: 16,
                      color: nextDonate != null ? Colors.black : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Donation message based on dates
            if (lastDonate != null && nextDonate != null)
              Text(
                "You last donated on ${_formatDate(lastDonate)}. "
                    "You can donate again after ${_formatDate(nextDonate)}.",
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 30),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(200, 50),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestFormPage(userId: widget.userId),
                  ),
                );
              },
              child: const Text("REQUEST BLOOD"),
            ),
          ],
        ),
      ),
    );
  }
}