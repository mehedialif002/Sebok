import 'package:flutter/material.dart';
import 'otp_email_page.dart';
import '../supabase_config.dart'; // make sure this exists

class BloodRequestsPage extends StatefulWidget {
  @override
  State<BloodRequestsPage> createState() => _BloodRequestsPageState();
}

class _BloodRequestsPageState extends State<BloodRequestsPage> {
  List<Map<String, dynamic>> _bloodRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBloodRequests();
  }

  Future<void> _fetchBloodRequests() async {
    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('requests')
          .select()
          .eq('is_fulfilled', false)
          .order('created_at', ascending: false);

      setState(() {
        _bloodRequests = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching requests: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Blood Request")),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _bloodRequests.length,
        itemBuilder: (context, index) {
          final item = _bloodRequests[index];
          return ListTile(
            title: Text(item["patient_name"] ?? "Unknown"),
            subtitle: Text("Blood Group: ${item['blood_group'] ?? ''}"),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OTPEmailPage(requestId: item["id"]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
