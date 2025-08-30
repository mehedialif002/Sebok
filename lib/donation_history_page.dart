import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'package:intl/intl.dart';

class DonationHistoryPage extends StatefulWidget {
  final String userId;

  const DonationHistoryPage({super.key, required this.userId});

  @override
  State<DonationHistoryPage> createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage> {
  bool isLoading = true;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> donationHistory = [];
  int totalDonations = 0;

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
      });
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> fetchDonationHistory() async {
    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('donations')
          .select()
          .eq('user_id', widget.userId)
          .order('donation_date', ascending: false);

      setState(() {
        donationHistory = List<Map<String, dynamic>>.from(response);
        totalDonations = donationHistory.length;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching donation history: $e");
      setState(() => isLoading = false);
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

  DateTime? _parseDate(String? dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  String _getNextDonationDate() {
    if (userData?['last_donate'] == null) return 'You can donate now';

    final lastDonation = _parseDate(userData?['last_donate']);
    if (lastDonation == null) return 'You can donate now';

    final nextDonation = lastDonation.add(const Duration(days: 90)); // 3 months gap
    return DateFormat('dd MMMM, yyyy').format(nextDonation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Donation History", style: TextStyle(color: Colors.white)),
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
            // Summary Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Total Donations
                    _buildSummaryItem(
                      icon: Icons.bloodtype,
                      title: 'Total Donations',
                      value: '$totalDonations times',
                      color: Colors.red,
                    ),

                    const Divider(),

                    // Last Donation
                    _buildSummaryItem(
                      icon: Icons.calendar_today,
                      title: 'Last Donation',
                      value: userData?['last_donate'] != null
                          ? _formatDate(userData?['last_donate'])
                          : 'Never donated',
                      color: Colors.blue,
                    ),

                    const Divider(),

                    // Next Eligible Donation
                    _buildSummaryItem(
                      icon: Icons.event_available,
                      title: 'Next Eligible Donation',
                      value: _getNextDonationDate(),
                      color: Colors.green,
                    ),

                    const Divider(),

                    // Total Points
                    _buildSummaryItem(
                      icon: Icons.emoji_events,
                      title: 'Total Points',
                      value: '${userData?['total_points'] ?? 0} points',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Donation History List
            const Text(
              'Donation Records',
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
                    child: Column(
                      children: [
                        Icon(Icons.bloodtype, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No donation records yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Your donation history will appear here',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: donationHistory.map((donation) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bloodtype, color: Colors.red[700]),
                      ),
                      title: Text(
                        'Blood Donation',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(donation['donation_date']),
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (donation['hospital_name'] != null)
                            Text(
                              'at ${donation['hospital_name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+${donation['points_earned'] ?? 10}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'points',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // Information Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '💡 You can donate blood every 3 months (90 days) after your last donation.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
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