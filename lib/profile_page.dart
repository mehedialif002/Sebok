import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> donationHistory = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchDonationHistory();
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
        userData = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching data: $e")),
      );
    }
  }

  Future<void> fetchDonationHistory() async {
    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('donations') // Assuming you have a donations table
          .select()
          .eq('user_id', widget.userId)
          .order('donation_date', ascending: false);

      setState(() {
        donationHistory = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Error fetching donation history: $e");
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not available';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.red[100],
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.red[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        userData?['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Blood Group
                    _buildProfileItem(
                      icon: Icons.bloodtype,
                      title: 'Blood group',
                      value: userData?['blood_group'] ?? 'Not set',
                    ),

                    const Divider(),

                    // Occupation
                    _buildProfileItem(
                      icon: Icons.work,
                      title: 'Occupation',
                      value: userData?['occupation'] ?? 'Not set',
                    ),

                    const Divider(),

                    // Score
                    _buildProfileItem(
                      icon: Icons.emoji_events,
                      title: 'Score',
                      value: '${userData?['total_points'] ?? 0}',
                      valueStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                        fontSize: 18,
                      ),
                    ),

                    const Divider(),

                    // Email
                    _buildProfileItem(
                      icon: Icons.email,
                      title: 'Email',
                      value: userData?['email'] ?? 'Not set',
                    ),

                    const Divider(),

                    // Phone
                    _buildProfileItem(
                      icon: Icons.phone,
                      title: 'Phone',
                      value: userData?['phone'] ?? 'Not set',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Donation History Section
            const Text(
              'Donation History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (donationHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No donation history yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: donationHistory.length,
                itemBuilder: (context, index) {
                  final donation = donationHistory[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.bloodtype, color: Colors.red),
                      title: Text(
                        'Donated ${donation['blood_quantity'] ?? 1} bag(s)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _formatDate(donation['donation_date']),
                      ),
                      trailing: Text(
                        '+${donation['points_earned'] ?? 10} points',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: valueStyle ?? const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}