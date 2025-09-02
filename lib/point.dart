import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class PointsAddPage extends StatefulWidget {
  final Map<String, dynamic> selectedRequest;
  final Map<String, dynamic> donorInfo;

  const PointsAddPage({
    super.key,
    required this.selectedRequest,
    required this.donorInfo,
  });

  @override
  State<PointsAddPage> createState() => _PointsAddPageState();
}

class _PointsAddPageState extends State<PointsAddPage> {
  final _pointsController = TextEditingController();
  bool _loading = false;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _pointsController.text = '10'; // Default points
    _getOrCreateOrganization();
  }

  Future<void> _getOrCreateOrganization() async {
    final supabase = SupabaseConfig.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) return;

    try {
      // Check if organization already exists for this user
      final orgResponse = await supabase
          .from('organizations')
          .select()
          .eq('admin_id', currentUserId)
          .maybeSingle();

      if (orgResponse != null) {
        setState(() {
          _orgId = orgResponse['id'];
        });
      } else {
        // Create a new organization if it doesn't exist
        final userData = await supabase
            .from('users')
            .select('name, email')
            .eq('id', currentUserId)
            .single();

        final newOrg = await supabase
            .from('organizations')
            .insert({
          'name': '${userData['name']} Organization',
          'email': userData['email'],
          'admin_id': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        })
            .select()
            .single();

        setState(() {
          _orgId = newOrg['id'];
        });
      }
    } catch (e) {
      print("Error getting/creating organization: $e");
    }
  }

  Future<void> _addPointsAndRemoveRequest() async {
    if (_orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization not set up properly")),
      );
      return;
    }

    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    if (points <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid points")),
      );
      return;
    }

    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;
    final requestId = widget.selectedRequest['id'];
    final donorId = widget.donorInfo['id'];
    final currentUserId = supabase.auth.currentUser?.id;

    try {
      // 1. Add points to user (try RPC first, then fallback to direct update)
      try {
        // Try to use the RPC function
        await supabase.rpc('increment_points', params: {
          'userid': donorId,
          'p': points,
        });
      } catch (e) {
        // If RPC fails, fall back to direct update
        final currentUser = await supabase
            .from('users')
            .select('total_points')
            .eq('id', donorId)
            .single();

        final newPoints = (currentUser['total_points'] ?? 0) + points;

        await supabase
            .from('users')
            .update({'total_points': newPoints})
            .eq('id', donorId);
      }

      // 2. Record donation - Use the organization ID we retrieved/created
      await supabase.from('donations').insert({
        'donor_id': donorId,
        'org_id': _orgId, // Use the organization ID
        'donation_date': DateTime.now().toIso8601String(),
        'points_earned': points,
        'hospital_name': widget.selectedRequest['hospital'],
        'request_id': requestId,
      });

      // 3. Update last donation date
      await supabase.from('users').update({
        'last_donate': DateTime.now().toIso8601String(),
      }).eq('id', donorId);

      // 4. Remove/fulfill the request
      await supabase
          .from('requests')
          .update({
        'is_fulfilled': true,
        'fulfilled_at': DateTime.now().toIso8601String(),
        'fulfilled_by': currentUserId,
      })
          .eq('id', requestId);

      // 5. Log the action
      await supabase.from('audit_logs').insert({
        'action': 'points_added_request_fulfilled',
        'performed_by': currentUserId,
        'target_user': donorId,
        'details': 'Added $points points and fulfilled blood request $requestId',
        'performed_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Points added and request fulfilled successfully!")),
      );

      // Navigate back to the request selection page
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Add Points to Donor", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Details
            const Text(
              "Request Details:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Blood Group: ${widget.selectedRequest['blood_group']}"),
                    Text("Hospital: ${widget.selectedRequest['hospital']}"),
                    Text("Location: ${widget.selectedRequest['location']}"),
                    Text("Contact: ${widget.selectedRequest['contact_info'] ?? 'N/A'}"),
                    Text("Needed by: ${widget.selectedRequest['needed_by']}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Donor Information
            const Text(
              "Donor Information:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Name: ${widget.donorInfo['name'] ?? 'Unknown'}"),
                    Text("Email: ${widget.donorInfo['email'] ?? 'N/A'}"),
                    Text("Phone: ${widget.donorInfo['phone'] ?? 'N/A'}"),
                    Text("Blood Group: ${widget.donorInfo['blood_group'] ?? 'N/A'}"),
                    Text(
                      "Current Points: ${widget.donorInfo['total_points']?.toString() ?? '0'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Points Input
            const Text(
              "Points to Add:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Points",
                border: OutlineInputBorder(),
                hintText: "10",
                suffixText: "points",
              ),
            ),
            const SizedBox(height: 20),

            // Add Points Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _loading ? null : _addPointsAndRemoveRequest,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Add Points & Fulfill Request"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }
}