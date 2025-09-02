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
  List<Map<String, dynamic>> donationHistory = [];
  int totalDonations = 0;
  int totalPoints = 0;
  DateTime? lastDonationDate;
  DateTime? nextDonationDate;

  @override
  void initState() {
    super.initState();
    fetchDonationHistory();
  }

  Future<void> fetchDonationHistory() async {
    final supabase = SupabaseConfig.client;

    try {
      // Fetch all donations for this user from donations table
      final response = await supabase
          .from('donations')
          .select('''
            donation_date, 
            points_earned, 
            hospital_name,
            request_id,
            organizations(name)
          ''')
          .eq('donor_id', widget.userId)
          .order('donation_date', ascending: false);

      if (response != null && response is List) {
        // Calculate totals and find latest donation
        int points = 0;
        DateTime? latestDate;

        for (var donation in response) {
          // Sum points
          points += (donation['points_earned'] as num).toInt();

          // Find latest donation date
          final donationDate = _parseDate(donation['donation_date']);
          if (donationDate != null && (latestDate == null || donationDate.isAfter(latestDate))) {
            latestDate = donationDate;
          }
        }

        // Calculate next donation date (90 days after last donation)
        DateTime? nextDate;
        if (latestDate != null) {
          nextDate = latestDate.add(const Duration(days: 90));
        }

        setState(() {
          donationHistory = List<Map<String, dynamic>>.from(response);
          totalDonations = donationHistory.length;
          totalPoints = points;
          lastDonationDate = latestDate;
          nextDonationDate = nextDate;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching donation history: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return DateFormat('dd MMMM, yyyy').format(date);
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
    if (lastDonationDate == null) return 'You can donate now';
    return _formatDate(nextDonationDate);
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
                      value: lastDonationDate != null
                          ? _formatDate(lastDonationDate)
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
                      value: '$totalPoints points',
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
                  final donationDate = _parseDate(donation['donation_date']);
                  final organization = donation['organizations'] is Map
                      ? donation['organizations']['name']
                      : 'Unknown Organization';

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
                            donationDate != null
                                ? _formatDate(donationDate)
                                : donation['donation_date'] ?? 'Unknown date',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (donation['hospital_name'] != null)
                            Text(
                              'Hospital: ${donation['hospital_name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (organization != null)
                            Text(
                              'Organization: $organization',
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
                            '+${donation['points_earned'] ?? 0}',
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