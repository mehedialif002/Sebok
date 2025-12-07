/*
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
  bool _showAd = true; // Control whether to show ad
  int _currentAdIndex = 0; // For multiple ads
  final List<AdBanner> _ads = [
    AdBanner(
      id: 1,
      imageUrl: 'assets/images/ads/ad.jpeg', // Example blood donation ad
    ),
    AdBanner(
      id: 2,
      imageUrl: 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800&auto=format&fit=crop',
    ),
    AdBanner(
      id: 3,
      imageUrl: 'https://images.unsplash.com/photo-1551601651-2a8555f1a136?w=800&auto=format&fit=crop',
    ),
  ];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchPointsFromDonations(); // Fetch points from donations table
    subscribeToBloodRequests();
    _loadAdPreference();
  }

  Future<void> _loadAdPreference() async {
    final supabase = SupabaseConfig.client;
    try {
      final response = await supabase
          .from('user_preferences')
          .select('show_ads')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _showAd = response['show_ads'] ?? true;
        });
      }
    } catch (e) {
      // Table might not exist, continue with default
      print("Error loading ad preference: $e");
    }
  }

  Future<void> _saveAdPreference(bool showAd) async {
    final supabase = SupabaseConfig.client;
    try {
      await supabase.from('user_preferences').upsert({
        'user_id': widget.userId,
        'show_ads': showAd,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Error saving ad preference: $e");
    }
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

  void _showAdOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.red),
                title: const Text('Hide this ad'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showAd = false;
                  });
                  _saveAdPreference(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ad hidden. You can enable ads in settings.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.blue),
                title: const Text('Show different ad'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdBanner() {
    final ad = _ads[_currentAdIndex];

    return GestureDetector(
      onTap: () {
        // Handle ad click - you can open URL or show details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ad.imageUrl.startsWith('assets/')
                      ? Image.asset(
                    ad.imageUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                      : Image.network(
                    ad.imageUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // You can open the URL here using url_launcher package
                  // For now, just show a message
                },
                child: const Text('Learn More'),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 220, // Increased height for larger ad
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Stack(
          children: [
            // Ad Image - Fills the entire container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ad.imageUrl.startsWith('assets/')
                  ? Image.asset(
                ad.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover, // Changed to cover to fill the space
              )
                  : Image.network(
                ad.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover, // Changed to cover to fill the space
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.red[50],
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),

            // ADVERTISEMENT badge overlay
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ADVERTISEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Options button at top-right
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showAdOptions(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // "Tap to learn more" overlay
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Tap to learn more',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("সেবক", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Ad Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Show Ads'),
                        value: _showAd,
                        onChanged: (value) {
                          setState(() {
                            _showAd = value;
                          });
                          _saveAdPreference(value);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? 'Ads enabled' : 'Ads disabled',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      if (!_showAd)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAd = true;
                            });
                            _saveAdPreference(true);
                            Navigator.pop(context);
                          },
                          child: const Text('Show Ads Again'),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
          : SingleChildScrollView(
        child: Column(
          children: [
            // Ad Banner (if enabled)
            if (_showAd) _buildAdBanner(),

            Padding(
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ad Banner Model
class AdBanner {
  final int id;
  final String imageUrl;

  AdBanner({
    required this.id,
    required this.imageUrl,
  });
}


import "dart:async";
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
  bool _showAd = true; // Control whether to show ad
  int _currentAdIndex = 0; // For multiple ads
  late Timer _adTimer; // Timer for auto-changing ads

  final List<AdBanner> _ads = [
    AdBanner(
      id: 1,
      imageUrl: 'assets/images/ads/ad.jpeg', // Example blood donation ad
    ),
    AdBanner(
      id: 2,
      imageUrl: 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800&auto=format&fit=crop',
    ),
    AdBanner(
      id: 3,
      imageUrl: 'https://images.unsplash.com/photo-1551601651-2a8555f1a136?w=800&auto=format&fit=crop',
    ),
  ];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchPointsFromDonations(); // Fetch points from donations table
    subscribeToBloodRequests();
    _loadAdPreference();
    _startAdTimer();
  }

  @override
  void dispose() {
    _adTimer.cancel();
    super.dispose();
  }

  void _startAdTimer() {
    _adTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_ads.length > 1) {
        setState(() {
          _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
        });
      }
    });
  }

  Future<void> _loadAdPreference() async {
    final supabase = SupabaseConfig.client;
    try {
      final response = await supabase
          .from('user_preferences')
          .select('show_ads')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _showAd = response['show_ads'] ?? true;
        });
      }
    } catch (e) {
      // Table might not exist, continue with default
      print("Error loading ad preference: $e");
    }
  }

  Future<void> _saveAdPreference(bool showAd) async {
    final supabase = SupabaseConfig.client;
    try {
      await supabase.from('user_preferences').upsert({
        'user_id': widget.userId,
        'show_ads': showAd,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Error saving ad preference: $e");
    }
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

  void _showAdOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.red),
                title: const Text('Hide this ad'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showAd = false;
                  });
                  _saveAdPreference(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ad hidden. You can enable ads in settings.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.blue),
                title: const Text('Show different ad'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToNextAd() {
    setState(() {
      _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
    });
    // Reset timer
    _adTimer.cancel();
    _startAdTimer();
  }

  void _goToPreviousAd() {
    setState(() {
      _currentAdIndex = (_currentAdIndex - 1 + _ads.length) % _ads.length;
    });
    // Reset timer
    _adTimer.cancel();
    _startAdTimer();
  }

  Widget _buildAdBanner() {
    final ad = _ads[_currentAdIndex];

    return GestureDetector(
      onTap: () {
        // Handle ad click - you can open URL or show details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ad.imageUrl.startsWith('assets/')
                      ? Image.asset(
                    ad.imageUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                      : Image.network(
                    ad.imageUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // You can open the URL here using url_launcher package
                  // For now, just show a message
                },
                child: const Text('Learn More'),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 220, // Increased height for larger ad
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Stack(
          children: [
            // Ad Image - Fills the entire container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ad.imageUrl.startsWith('assets/')
                  ? Image.asset(
                ad.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover, // Changed to cover to fill the space
              )
                  : Image.network(
                ad.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover, // Changed to cover to fill the space
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.red[50],
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),

            // ADVERTISEMENT badge overlay
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ADVERTISEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Options button at top-right
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showAdOptions(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // "Tap to learn more" overlay
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Tap to learn more',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

            // Navigation buttons (only show if more than 1 ad)
            if (_ads.length > 1) ...[
              // Previous button (left side)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _goToPreviousAd,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Next button (right side)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _goToNextAd,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Ad indicators (dots at the bottom)
              Positioned(
                bottom: 5,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_ads.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentAdIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("সেবক", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Ad Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Show Ads'),
                        value: _showAd,
                        onChanged: (value) {
                          setState(() {
                            _showAd = value;
                          });
                          _saveAdPreference(value);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? 'Ads enabled' : 'Ads disabled',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      if (!_showAd)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAd = true;
                            });
                            _saveAdPreference(true);
                            Navigator.pop(context);
                          },
                          child: const Text('Show Ads Again'),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
          : SingleChildScrollView(
        child: Column(
          children: [
            // Ad Banner (if enabled)
            if (_showAd) _buildAdBanner(),

            Padding(
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ad Banner Model
class AdBanner {
  final int id;
  final String imageUrl;

  AdBanner({
    required this.id,
    required this.imageUrl,
  });
}

 */
import 'dart:async'; // Add this for Timer
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
  bool _showAd = true; // Control whether to show ad
  int _currentAdIndex = 0; // For multiple ads
  Timer? _adTimer; // Timer for auto-changing ads - make it nullable

  final List<AdBanner> _ads = [
    AdBanner(
      id: 1,
      imageUrl: 'assets/images/ads/ad.jpeg', // Example blood donation ad
    ),
    AdBanner(
      id: 2,
      imageUrl: 'assets/images/ads/ad2.jpg',
    ),
    AdBanner(
      id: 3,
      imageUrl: 'assets/images/ads/ad3.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchPointsFromDonations(); // Fetch points from donations table
    subscribeToBloodRequests();
    _loadAdPreference();

    // Start timer after a small delay to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAdTimer();
    });
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    super.dispose();
  }

  void _startAdTimer() {
    _adTimer?.cancel(); // Cancel existing timer if any

    if (_ads.length > 1) {
      _adTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
          });
        }
      });
    }
  }

  Future<void> _loadAdPreference() async {
    final supabase = SupabaseConfig.client;
    try {
      final response = await supabase
          .from('user_preferences')
          .select('show_ads')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _showAd = response['show_ads'] ?? true;
        });
      }
    } catch (e) {
      // Table might not exist, continue with default
      print("Error loading ad preference: $e");
    }
  }

  Future<void> _saveAdPreference(bool showAd) async {
    final supabase = SupabaseConfig.client;
    try {
      await supabase.from('user_preferences').upsert({
        'user_id': widget.userId,
        'show_ads': showAd,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Error saving ad preference: $e");
    }
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

  void _showAdOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.red),
                title: const Text('Hide this ad'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showAd = false;
                  });
                  _saveAdPreference(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ad hidden. You can enable ads in settings.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.blue),
                title: const Text('Show different ad'),
                onTap: () {
                  Navigator.pop(context);
                  _goToNextAd();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToNextAd() {
    if (_ads.length > 1) {
      setState(() {
        _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
      });
      // Reset timer
      _startAdTimer();
    }
  }

  void _goToPreviousAd() {
    if (_ads.length > 1) {
      setState(() {
        _currentAdIndex = (_currentAdIndex - 1 + _ads.length) % _ads.length;
      });
      // Reset timer
      _startAdTimer();
    }
  }

  Widget _buildAdBanner() {
    final ad = _ads[_currentAdIndex];

    return GestureDetector(
      onTap: () {
        // Handle ad click - you can open URL or show details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ad.imageUrl.startsWith('assets/')
                      ? Image.asset(
                    ad.imageUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                      : Image.network(
                    ad.imageUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // You can open the URL here using url_launcher package
                  // For now, just show a message
                },
                child: const Text('Learn More'),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 220, // Increased height for larger ad
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Stack(
          children: [
            // Ad Image - Fills the entire container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ad.imageUrl.startsWith('assets/')
                  ? Image.asset(
                ad.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover, // Changed to cover to fill the space
              )
                  : Image.network(
                ad.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover, // Changed to cover to fill the space
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.red[50],
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),

            // ADVERTISEMENT badge overlay
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ADVERTISEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Options button at top-right
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showAdOptions(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // "Tap to learn more" overlay
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Tap to learn more',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

            // Navigation buttons (only show if more than 1 ad)
            if (_ads.length > 1) ...[
              // Previous button (left side)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _goToPreviousAd,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Next button (right side)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _goToNextAd,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Ad indicators (dots at the bottom)
              Positioned(
                bottom: 5,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_ads.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentAdIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("সেবক", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Ad Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Show Ads'),
                        value: _showAd,
                        onChanged: (value) {
                          setState(() {
                            _showAd = value;
                          });
                          _saveAdPreference(value);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? 'Ads enabled' : 'Ads disabled',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      if (!_showAd)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAd = true;
                            });
                            _saveAdPreference(true);
                            Navigator.pop(context);
                          },
                          child: const Text('Show Ads Again'),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
          : SingleChildScrollView(
        child: Column(
          children: [
            // Ad Banner (if enabled)
            if (_showAd) _buildAdBanner(),

            Padding(
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ad Banner Model
class AdBanner {
  final int id;
  final String imageUrl;

  AdBanner({
    required this.id,
    required this.imageUrl,
  });
}