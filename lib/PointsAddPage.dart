/*
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'dart:math';

class PointsAddPage extends StatefulWidget {
  const PointsAddPage({super.key});

  @override
  State<PointsAddPage> createState() => _PointsAddPageState();
}

class _PointsAddPageState extends State<PointsAddPage> {
  final _emailController = TextEditingController();
  final _pointsController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _bloodGroupVerified = false;
  List<Map<String, dynamic>> _bloodRequests = [];
  Map<String, dynamic>? _selectedRequest;
  Map<String, dynamic>? _donorInfo;
  String? _verificationId;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _fetchBloodRequests();
    _getOrCreateOrganization();
    _pointsController.text = '10'; // Set default points
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

  Future<void> _fetchBloodRequests() async {
    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      // Fetch only blood requests (not user data)
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

  Future<void> _fetchDonorInfo(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an email address")),
      );
      return;
    }

    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      // Fetch donor info by email from users table
      final response = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      setState(() {
        _donorInfo = response;
        _loading = false;
        _otpSent = false;
        _otpVerified = false;
        _bloodGroupVerified = false;
      });

      if (_donorInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No donor found with this email")),
        );
      } else {
        // Check blood group compatibility
        _verifyBloodGroup();
      }

    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching donor info: $e")),
      );
    }
  }

  void _verifyBloodGroup() {
    if (_selectedRequest == null || _donorInfo == null) return;

    final requestBloodGroup = _selectedRequest!['blood_group'];
    final donorBloodGroup = _donorInfo!['blood_group'];

    // Blood group compatibility check
    final isCompatible = _isBloodGroupCompatible(donorBloodGroup, requestBloodGroup);

    setState(() {
      _bloodGroupVerified = isCompatible;
    });

    if (isCompatible) {
      // Auto-send OTP when blood group is verified
      _sendOtp();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group mismatch: Donor ($donorBloodGroup) cannot donate to Request ($requestBloodGroup)"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isBloodGroupCompatible(String donorGroup, String recipientGroup) {
    // Blood group compatibility rules
    final compatibilityMap = {
      'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'], // O- can donate to everyone
      'O+': ['O+', 'A+', 'B+', 'AB+'],
      'A-': ['A-', 'A+', 'AB-', 'AB+'],
      'A+': ['A+', 'AB+'],
      'B-': ['B-', 'B+', 'AB-', 'AB+'],
      'B+': ['B+', 'AB+'],
      'AB-': ['AB-', 'AB+'],
      'AB+': ['AB+'],
    };

    // Normalize blood groups (remove spaces, make uppercase)
    final normalizedDonor = donorGroup.replaceAll(' ', '').toUpperCase();
    final normalizedRecipient = recipientGroup.replaceAll(' ', '').toUpperCase();

    return compatibilityMap[normalizedDonor]?.contains(normalizedRecipient) ?? false;
  }

  Future<void> _sendOtp() async {
    if (_donorInfo == null || _donorInfo!['phone'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donor phone number not available")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    setState(() => _sendingOtp = true);

    final supabase = SupabaseConfig.client;
    final phoneNumber = _donorInfo!['phone'];
    final userId = _donorInfo!['id'];

    try {
      // Generate a random 6-digit OTP
      final otp = _generateOtp();

      // Store OTP in the database with expiration time (5 minutes from now)
      final expiresAt = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      await supabase.from('otp_requests').insert({
        'user_id': userId,
        'phone': phoneNumber,
        'otp': otp,
        'expires_at': expiresAt,
        'created_at': DateTime.now().toIso8601String(),
      });

      // In a real app, you would send the OTP via SMS service here
      // For now, we'll just show it in a dialog for testing purposes
      _showOtpDialog(otp);

      setState(() {
        _otpSent = true;
        _sendingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP sent to $phoneNumber")),
      );

    } catch (e) {
      setState(() => _sendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending OTP: $e")),
      );
    }
  }

  String _generateOtp() {
    // Generate a random 6-digit number
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _showOtpDialog(String otp) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("OTP for Testing"),
          content: Text("For testing purposes, the OTP is: $otp"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_donorInfo == null || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the OTP")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    setState(() => _verifyingOtp = true);

    final supabase = SupabaseConfig.client;
    final otp = _otpController.text.trim();
    final userId = _donorInfo!['id'];

    try {
      // Verify OTP against the database
      final response = await supabase
          .from('otp_requests')
          .select()
          .eq('user_id', userId)
          .eq('otp', otp)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        throw Exception("Invalid or expired OTP");
      }

      setState(() {
        _otpVerified = true;
        _verifyingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP verified successfully!")),
      );

    } catch (e) {
      setState(() => _verifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error verifying OTP: $e")),
      );
    }
  }

  Future<void> _addPointsAndRemoveRequest() async {
    if (_selectedRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a blood request")),
      );
      return;
    }

    if (_donorInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fetch donor information first")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required")),
      );
      return;
    }

    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify donor with OTP first")),
      );
      return;
    }

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
    final requestId = _selectedRequest!['id'];
    final donorId = _donorInfo!['id'];
    final email = _emailController.text.trim();
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
        'hospital_name': _selectedRequest!['hospital'],
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

      // Refresh the donor info to show updated points
      await _fetchDonorInfo(email);

      // Refresh the blood requests list
      await _fetchBloodRequests();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onRequestSelected(Map<String, dynamic> request) {
    setState(() {
      _selectedRequest = request;
      // Clear email field when selecting a new request
      _emailController.clear();
      _pointsController.text = '10'; // Default points
      _donorInfo = null; // Reset donor info
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Add Points from Blood Requests", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchBloodRequests,
          ),
        ],
      ),
      body: _loading && _bloodRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Blood Requests Section
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Available Blood Requests:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _bloodRequests.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          "No pending blood requests",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                )
                    : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _bloodRequests.length,
                    itemBuilder: (context, index) {
                      final request = _bloodRequests[index];
                      final isSelected = _selectedRequest?['id'] == request['id'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? Colors.red[50] : null,
                        child: ListTile(
                          leading: const Icon(Icons.bloodtype, color: Colors.red),
                          title: Text(
                            "${request['blood_group']} Blood Request",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hospital: ${request['hospital']}"),
                              Text("Location: ${request['location']}"),
                              Text("Needed by: ${request['needed_by']}"),
                              Text("Contact: ${request['contact_info'] ?? 'N/A'}"),
                              Text("Units: ${request['blood_units'] ?? 1}"),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () => _onRequestSelected(request),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Donor Information Section
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedRequest != null) ...[
                    const Text(
                      "Selected Request Details:",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Blood Group: ${_selectedRequest!['blood_group']}"),
                            Text("Hospital: ${_selectedRequest!['hospital']}"),
                            Text("Location: ${_selectedRequest!['location']}"),
                            Text("Contact: ${_selectedRequest!['contact_info'] ?? 'N/A'}"),
                            Text("Needed by: ${_selectedRequest!['needed_by']}"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email Input
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Donor Email",
                        border: const OutlineInputBorder(),
                        hintText: "Enter donor's email",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            if (_emailController.text.isNotEmpty) {
                              _fetchDonorInfo(_emailController.text.trim());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter an email address")),
                              );
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _fetchDonorInfo(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Donor Information
                    if (_donorInfo != null) ...[
                      const Text(
                        "Donor Information:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Name: ${_donorInfo!['name'] ?? 'Unknown'}"),
                              Text("Email: ${_donorInfo!['email'] ?? 'N/A'}"),
                              Text("Phone: ${_donorInfo!['phone'] ?? 'N/A'}"),
                              Text("Blood Group: ${_donorInfo!['blood_group'] ?? 'N/A'}"),
                              Text(
                                "Current Points: ${_donorInfo!['total_points']?.toString() ?? '0'}",
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
                      const SizedBox(height: 8),

                      // Blood Group Verification Status
                      _bloodGroupVerified
                          ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Blood Group Verified: ${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}",
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      )
                          : Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Blood Group Mismatch: ${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}",
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // OTP Verification Section (only show if blood group is verified)
                      if (_bloodGroupVerified) ...[
                        const Text(
                          "Donor Verification:",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_otpSent && !_otpVerified)
                          Column(
                            children: [
                              Text(
                                "OTP sent to ${_donorInfo!['phone']}",
                                style: const TextStyle(color: Colors.green),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Enter OTP",
                                  border: OutlineInputBorder(),
                                  hintText: "6-digit code",
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _verifyingOtp ? null : _verifyOtp,
                                  child: _verifyingOtp
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text("Verify OTP"),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _sendingOtp ? null : _sendOtp,
                                child: const Text("Resend OTP"),
                              ),
                            ],
                          )
                        else if (!_otpSent)
                          Column(
                            children: [
                              Text(
                                "Verify donor via OTP sent to ${_donorInfo!['phone']}",
                                style: const TextStyle(color: Colors.blue),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _sendingOtp ? null : _sendOtp,
                                  child: _sendingOtp
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text("Send OTP"),
                                ),
                              ),
                            ],
                          )
                        else if (_otpVerified)
                            const Text(
                              "Donor verified successfully!",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Points Input
                    TextField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Points to Add",
                        border: OutlineInputBorder(),
                        hintText: "10",
                        suffixText: "points",
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add Points Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bloodGroupVerified && _otpVerified ? Colors.red : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _bloodGroupVerified && _otpVerified && !_loading ? _addPointsAndRemoveRequest : null,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Add Points & Fulfill Request"),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Center(
                      child: Text(
                        "Select a blood request to continue",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pointsController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'dart:math';

class PointsAddPage extends StatefulWidget {
  const PointsAddPage({super.key});

  @override
  State<PointsAddPage> createState() => _PointsAddPageState();
}

class _PointsAddPageState extends State<PointsAddPage> {
  final _emailController = TextEditingController();
  final _pointsController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _bloodGroupVerified = false;
  List<Map<String, dynamic>> _bloodRequests = [];
  Map<String, dynamic>? _selectedRequest;
  Map<String, dynamic>? _donorInfo;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _fetchBloodRequests();
    _getOrCreateOrganization();
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

  Future<void> _getOrCreateOrganization() async {
    final supabase = SupabaseConfig.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) return;

    try {
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

  Future<void> _fetchDonorInfo(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an email address")),
      );
      return;
    }

    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      setState(() {
        _donorInfo = response;
        _loading = false;
        _otpSent = false;
        _otpVerified = false;
        _bloodGroupVerified = false;
      });

      if (_donorInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No donor found with this email")),
        );
      } else {
        _verifyBloodGroup();
      }

    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching donor info: $e")),
      );
    }
  }

  void _verifyBloodGroup() {
    if (_selectedRequest == null || _donorInfo == null) return;

    final requestBloodGroup = _selectedRequest!['blood_group'];
    final donorBloodGroup = _donorInfo!['blood_group'];

    final isCompatible = _isBloodGroupCompatible(donorBloodGroup, requestBloodGroup);

    setState(() {
      _bloodGroupVerified = isCompatible;
    });

    if (isCompatible) {
      _sendOtp();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group mismatch: Donor ($donorBloodGroup) cannot donate to Request ($requestBloodGroup)"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isBloodGroupCompatible(String donorGroup, String recipientGroup) {
    final compatibilityMap = {
      'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
      'O+': ['O+', 'A+', 'B+', 'AB+'],
      'A-': ['A-', 'A+', 'AB-', 'AB+'],
      'A+': ['A+', 'AB+'],
      'B-': ['B-', 'B+', 'AB-', 'AB+'],
      'B+': ['B+', 'AB+'],
      'AB-': ['AB-', 'AB+'],
      'AB+': ['AB+'],
    };

    final normalizedDonor = donorGroup.replaceAll(' ', '').toUpperCase();
    final normalizedRecipient = recipientGroup.replaceAll(' ', '').toUpperCase();

    return compatibilityMap[normalizedDonor]?.contains(normalizedRecipient) ?? false;
  }

  Future<void> _sendOtp() async {
    if (_donorInfo == null || _donorInfo!['phone'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donor phone number not available")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    setState(() => _sendingOtp = true);

    final supabase = SupabaseConfig.client;
    final phoneNumber = _donorInfo!['phone'];
    final userId = _donorInfo!['id'];

    try {
      // Generate a random 6-digit OTP
      final otp = _generateOtp();

      // Store OTP in the database with expiration time (5 minutes from now)
      final expiresAt = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      await supabase.from('otp_requests').insert({
        'user_id': userId,
        'phone': phoneNumber,
        'otp': otp,
        'expires_at': expiresAt,
        'created_at': DateTime.now().toIso8601String(),
      });

      // TODO: Integrate with your SMS service here
      // Example: await _sendSmsOtp(phoneNumber, otp);

      // For now, we'll simulate SMS sending
      await _simulateSmsSending(phoneNumber, otp);

      setState(() {
        _otpSent = true;
        _sendingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP has been sent to $phoneNumber")),
      );

    } catch (e) {
      setState(() => _sendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending OTP: $e")),
      );
    }
  }

  // This is a simulation function - replace with real SMS service
  Future<void> _simulateSmsSending(String phoneNumber, String otp) async {
    print("Simulating SMS to $phoneNumber with OTP: $otp");
    // In production, replace this with actual SMS API call
    await Future.delayed(const Duration(seconds: 2));

    // Example of what a real SMS service integration might look like:
    // await supabase.functions.invoke('send-sms', {
    //   'body': {
    //     'to': phoneNumber,
    //     'message': 'Your verification code is: $otp'
    //   }
    // });
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _verifyOtp() async {
    if (_donorInfo == null || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the OTP")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    setState(() => _verifyingOtp = true);

    final supabase = SupabaseConfig.client;
    final otp = _otpController.text.trim();
    final userId = _donorInfo!['id'];

    try {
      final response = await supabase
          .from('otp_requests')
          .select()
          .eq('user_id', userId)
          .eq('otp', otp)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        throw Exception("Invalid or expired OTP");
      }

      setState(() {
        _otpVerified = true;
        _verifyingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP verified successfully!")),
      );

    } catch (e) {
      setState(() => _verifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error verifying OTP: $e")),
      );
    }
  }

  Future<void> _addPointsAndRemoveRequest() async {
    if (_selectedRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a blood request")),
      );
      return;
    }

    if (_donorInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fetch donor information first")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required")),
      );
      return;
    }

    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify donor with OTP first")),
      );
      return;
    }

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
    final requestId = _selectedRequest!['id'];
    final donorId = _donorInfo!['id'];
    final email = _emailController.text.trim();
    final currentUserId = supabase.auth.currentUser?.id;

    try {
      try {
        await supabase.rpc('increment_points', params: {
          'userid': donorId,
          'p': points,
        });
      } catch (e) {
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

      await supabase.from('donations').insert({
        'donor_id': donorId,
        'org_id': _orgId,
        'donation_date': DateTime.now().toIso8601String(),
        'points_earned': points,
        'hospital_name': _selectedRequest!['hospital'],
        'request_id': requestId,
      });

      await supabase.from('users').update({
        'last_donate': DateTime.now().toIso8601String(),
      }).eq('id', donorId);

      await supabase
          .from('requests')
          .update({
        'is_fulfilled': true,
        'fulfilled_at': DateTime.now().toIso8601String(),
        'fulfilled_by': currentUserId,
      })
          .eq('id', requestId);

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

      await _fetchDonorInfo(email);
      await _fetchBloodRequests();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onRequestSelected(Map<String, dynamic> request) {
    setState(() {
      _selectedRequest = request;
      _emailController.clear();
      _pointsController.text = '10';
      _donorInfo = null;
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Add Points from Blood Requests", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchBloodRequests,
          ),
        ],
      ),
      body: _loading && _bloodRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Available Blood Requests:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_bloodRequests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      "No pending blood requests",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bloodRequests.length,
                  itemBuilder: (context, index) {
                    final request = _bloodRequests[index];
                    final isSelected = _selectedRequest?['id'] == request['id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? Colors.red[50] : null,
                      child: ListTile(
                        leading: const Icon(Icons.bloodtype, color: Colors.red),
                        title: Text(
                          "${request['blood_group']} Blood Request",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Hospital: ${request['hospital']}"),
                            Text("Location: ${request['location']}"),
                            Text("Needed by: ${request['needed_by']}"),
                            Text("Contact: ${request['contact_info'] ?? 'N/A'}"),
                            Text("Units: ${request['blood_units'] ?? 1}"),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () => _onRequestSelected(request),
                      ),
                    );
                  },
                ),
              ),

            if (_selectedRequest != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Selected Request Details:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Blood Group: ${_selectedRequest!['blood_group']}"),
                      Text("Hospital: ${_selectedRequest!['hospital']}"),
                      Text("Location: ${_selectedRequest!['location']}"),
                      Text("Contact: ${_selectedRequest!['contact_info'] ?? 'N/A'}"),
                      Text("Needed by: ${_selectedRequest!['needed_by']}"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Donor Email",
                  border: const OutlineInputBorder(),
                  hintText: "Enter donor's email",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      if (_emailController.text.isNotEmpty) {
                        _fetchDonorInfo(_emailController.text.trim());
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter an email address")),
                        );
                      }
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _fetchDonorInfo(value);
                  }
                },
              ),

              if (_donorInfo != null) ...[
                const SizedBox(height: 20),
                const Text(
                  "Donor Information:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: ${_donorInfo!['name'] ?? 'Unknown'}"),
                        Text("Email: ${_donorInfo!['email'] ?? 'N/A'}"),
                        Text("Phone: ${_donorInfo!['phone'] ?? 'N/A'}"),
                        Text("Blood Group: ${_donorInfo!['blood_group'] ?? 'N/A'}"),
                        Text(
                          "Current Points: ${_donorInfo!['total_points']?.toString() ?? '0'}",
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

                const SizedBox(height: 10),
                _bloodGroupVerified
                    ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Blood Group Verified: ${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}",
                          style: const TextStyle(color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Blood Group Mismatch: ${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}",
                          style: const TextStyle(color: Colors.red),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_bloodGroupVerified) ...[
                  const SizedBox(height: 20),
                  const Text(
                    "Donor Verification:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // OTP Sent Message
                  if (_otpSent)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.message, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "OTP sent to ${_donorInfo!['phone']}. Please check your messages.",
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // OTP Input Field (always shown if blood group verified)
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Enter OTP",
                      border: const OutlineInputBorder(),
                      hintText: "6-digit code",
                      suffixIcon: !_otpSent ? null : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _sendingOtp ? null : _sendOtp,
                        tooltip: "Resend OTP",
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Send/Verify OTP Buttons
                  if (!_otpSent)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _sendingOtp ? null : _sendOtp,
                        child: _sendingOtp
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Send OTP"),
                      ),
                    )
                  else if (!_otpVerified)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _verifyingOtp ? null : _verifyOtp,
                            child: _verifyingOtp
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("Verify OTP"),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _sendingOtp ? null : _sendOtp,
                          child: const Text("Didn't receive OTP? Resend"),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Donor verified successfully!",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],

              const SizedBox(height: 20),

              TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Points to Add",
                  border: OutlineInputBorder(),
                  hintText: "10",
                  suffixText: "points",
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bloodGroupVerified && _otpVerified ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _bloodGroupVerified && _otpVerified && !_loading ? _addPointsAndRemoveRequest : null,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Add Points & Fulfill Request"),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pointsController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'supabase_config.dart';

class AppLinkSmsService {
  final String applicationId;
  final String password;
  final String baseUrl = 'https://api.applink.com.bd';

  AppLinkSmsService({
    required this.applicationId,
    required this.password,
  });

  Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/request'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'applicationId': applicationId,
          'password': password,
          'subscriberId': 'tel:$phoneNumber',
          'applicationHash': 'abcdefgh',
          'applicationMetaData': {
            'client': 'FLUTTERAPP',
            'device': 'Mobile Device',
            'os': 'Android/iOS',
            'appCode': 'com.yourcompany.bloodapp',
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to request OTP: HTTP ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['statusCode'] != 'S1000') {
        throw Exception('OTP request failed: ${responseData['statusDetail']}');
      }

      return responseData;
    } catch (e) {
      throw Exception('OTP request error: $e');
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'applicationId': applicationId,
          'password': password,
          'referenceNo': referenceNo,
          'otp': otp,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to verify OTP: HTTP ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['statusCode'] != 'S1000') {
        throw Exception('OTP verification failed: ${responseData['statusDetail']}');
      }

      return responseData;
    } catch (e) {
      throw Exception('OTP verification error: $e');
    }
  }
}

class PointsAddPage extends StatefulWidget {
  const PointsAddPage({super.key});

  @override
  State<PointsAddPage> createState() => _PointsAddPageState();
}

class _PointsAddPageState extends State<PointsAddPage> {
  final _emailController = TextEditingController();
  final _pointsController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _bloodGroupVerified = false;
  List<Map<String, dynamic>> _bloodRequests = [];
  Map<String, dynamic>? _selectedRequest;
  Map<String, dynamic>? _donorInfo;
  String? _orgId;

  // SMS Service
  late final AppLinkSmsService _smsService;
  String? _otpReferenceNo;

  @override
  void initState() {
    super.initState();
    _fetchBloodRequests();
    _getOrCreateOrganization();

    // Initialize SMS service with your credentials
    _smsService = AppLinkSmsService(
      applicationId: 'APP_018652',
      password: '2e4a87894dc2184f0a9dd19f865cd06c',
    );
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

  Future<void> _getOrCreateOrganization() async {
    final supabase = SupabaseConfig.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) return;

    try {
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

  Future<void> _fetchDonorInfo(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an email address")),
      );
      return;
    }

    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      setState(() {
        _donorInfo = response;
        _loading = false;
        _otpSent = false;
        _otpVerified = false;
        _bloodGroupVerified = false;
        _otpReferenceNo = null;
      });

      if (_donorInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No donor found with this email")),
        );
      } else {
        _verifyBloodGroup();
      }

    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching donor info: $e")),
      );
    }
  }

  void _verifyBloodGroup() {
    if (_selectedRequest == null || _donorInfo == null) return;

    final requestBloodGroup = _selectedRequest!['blood_group'];
    final donorBloodGroup = _donorInfo!['blood_group'];

    final isCompatible = _isBloodGroupCompatible(donorBloodGroup, requestBloodGroup);

    setState(() {
      _bloodGroupVerified = isCompatible;
    });

    if (isCompatible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group compatible: $donorBloodGroup → $requestBloodGroup"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group mismatch: Donor ($donorBloodGroup) cannot donate to Request ($requestBloodGroup)"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isBloodGroupCompatible(String donorGroup, String recipientGroup) {
    if (donorGroup == null || recipientGroup == null) return false;

    final compatibilityMap = {
      'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
      'O+': ['O+', 'A+', 'B+', 'AB+'],
      'A-': ['A-', 'A+', 'AB-', 'AB+'],
      'A+': ['A+', 'AB+'],
      'B-': ['B-', 'B+', 'AB-', 'AB+'],
      'B+': ['B+', 'AB+'],
      'AB-': ['AB-', 'AB+'],
      'AB+': ['AB+'],
    };

    final normalizedDonor = donorGroup.replaceAll(' ', '').toUpperCase();
    final normalizedRecipient = recipientGroup.replaceAll(' ', '').toUpperCase();

    return compatibilityMap[normalizedDonor]?.contains(normalizedRecipient) ?? false;
  }

  Future<void> _sendOtp() async {
    if (_donorInfo == null || _donorInfo!['phone'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donor phone number not available")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    setState(() => _sendingOtp = true);
    _otpController.clear();

    try {
      final phoneNumber = _donorInfo!['phone'].toString();

      // Clean phone number format
      final cleanPhone = phoneNumber.startsWith('0') ? phoneNumber.substring(1) : phoneNumber;
      final formattedPhone = '880$cleanPhone';

      // Request OTP from AppLink API
      final response = await _smsService.requestOtp(
        phoneNumber: formattedPhone,
      );

      // Store the reference number for verification
      _otpReferenceNo = response['referenceNo'];

      // Store OTP in database for verification
      final supabase = SupabaseConfig.client;
      final userId = _donorInfo!['id'];
      final otp = _generateOtp(); // Generate OTP for database storage
      final expiresAt = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      await supabase.from('otp_verifications').insert({
        'user_id': userId,
        'phone': formattedPhone,
        'otp': otp,
        'reference_no': _otpReferenceNo,
        'expires_at': expiresAt,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      setState(() {
        _otpSent = true;
        _sendingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("OTP has been sent to $formattedPhone"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() => _sendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sending OTP: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _verifyOtp() async {
    if (_donorInfo == null || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the OTP")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    if (_otpReferenceNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No OTP request found. Please send OTP first.")),
      );
      return;
    }

    setState(() => _verifyingOtp = true);

    try {
      // Verify OTP with AppLink API
      final verificationResponse = await _smsService.verifyOtp(
        referenceNo: _otpReferenceNo!,
        otp: _otpController.text.trim(),
      );

      // Update database with verification status
      final supabase = SupabaseConfig.client;
      final userId = _donorInfo!['id'];

      await supabase.from('otp_verifications')
          .update({
        'verified_at': DateTime.now().toIso8601String(),
        'status': 'verified',
      })
          .eq('reference_no', _otpReferenceNo!)
          .eq('user_id', userId);

      setState(() {
        _otpVerified = true;
        _verifyingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("OTP verified successfully!"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() => _verifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error verifying OTP: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addPointsAndRemoveRequest() async {
    if (_selectedRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a blood request")),
      );
      return;
    }

    if (_donorInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fetch donor information first")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required")),
      );
      return;
    }

    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify donor with OTP first")),
      );
      return;
    }

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
    final requestId = _selectedRequest!['id'];
    final donorId = _donorInfo!['id'];
    final email = _emailController.text.trim();
    final currentUserId = supabase.auth.currentUser?.id;

    try {
      // Add points to donor
      try {
        await supabase.rpc('increment_points', params: {
          'userid': donorId,
          'p': points,
        });
      } catch (e) {
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

      // Record donation
      await supabase.from('donations').insert({
        'donor_id': donorId,
        'org_id': _orgId,
        'donation_date': DateTime.now().toIso8601String(),
        'points_earned': points,
        'hospital_name': _selectedRequest!['hospital'],
        'request_id': requestId,
      });

      // Update donor's last donation date
      await supabase.from('users').update({
        'last_donate': DateTime.now().toIso8601String(),
      }).eq('id', donorId);

      // Mark request as fulfilled
      await supabase
          .from('requests')
          .update({
        'is_fulfilled': true,
        'fulfilled_at': DateTime.now().toIso8601String(),
        'fulfilled_by': currentUserId,
        'fulfilled_donor_id': donorId,
      })
          .eq('id', requestId);

      // Create audit log
      await supabase.from('audit_logs').insert({
        'action': 'points_added_request_fulfilled',
        'performed_by': currentUserId,
        'target_user': donorId,
        'details': 'Added $points points and fulfilled blood request $requestId',
        'performed_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Points added and request fulfilled successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      await _fetchDonorInfo(email);
      await _fetchBloodRequests();

      // Reset form
      _resetForm();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedRequest = null;
      _donorInfo = null;
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
      _otpReferenceNo = null;
    });
  }

  void _onRequestSelected(Map<String, dynamic> request) {
    setState(() {
      _selectedRequest = request;
      _emailController.clear();
      _pointsController.text = '10';
      _donorInfo = null;
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
      _otpReferenceNo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Add Points from Blood Requests", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchBloodRequests,
            tooltip: "Refresh Requests",
          ),
        ],
      ),
      body: _loading && _bloodRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Available Blood Requests:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_bloodRequests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      "No pending blood requests",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bloodRequests.length,
                  itemBuilder: (context, index) {
                    final request = _bloodRequests[index];
                    final isSelected = _selectedRequest?['id'] == request['id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? Colors.red[50] : null,
                      child: ListTile(
                        leading: const Icon(Icons.bloodtype, color: Colors.red),
                        title: Text(
                          "${request['blood_group']} Blood Request",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Hospital: ${request['hospital']}"),
                            Text("Location: ${request['location']}"),
                            Text("Needed by: ${request['needed_by']}"),
                            Text("Contact: ${request['contact_info'] ?? 'N/A'}"),
                            Text("Units: ${request['blood_units'] ?? 1}"),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () => _onRequestSelected(request),
                      ),
                    );
                  },
                ),
              ),

            if (_selectedRequest != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Selected Request Details:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Blood Group: ${_selectedRequest!['blood_group']}"),
                      Text("Hospital: ${_selectedRequest!['hospital']}"),
                      Text("Location: ${_selectedRequest!['location']}"),
                      Text("Contact: ${_selectedRequest!['contact_info'] ?? 'N/A'}"),
                      Text("Needed by: ${_selectedRequest!['needed_by']}"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Donor Email",
                  border: const OutlineInputBorder(),
                  hintText: "Enter donor's email",
                  prefixIcon: const Icon(Icons.email),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      if (_emailController.text.isNotEmpty) {
                        _fetchDonorInfo(_emailController.text.trim());
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter an email address")),
                        );
                      }
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _fetchDonorInfo(value);
                  }
                },
              ),

              if (_donorInfo != null) ...[
                const SizedBox(height: 20),
                const Text(
                  "Donor Information:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: ${_donorInfo!['name'] ?? 'Unknown'}"),
                        Text("Email: ${_donorInfo!['email'] ?? 'N/A'}"),
                        Text("Phone: ${_donorInfo!['phone'] ?? 'N/A'}"),
                        Text("Blood Group: ${_donorInfo!['blood_group'] ?? 'N/A'}"),
                        Text(
                          "Current Points: ${_donorInfo!['total_points']?.toString() ?? '0'}",
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

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _bloodGroupVerified ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _bloodGroupVerified ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _bloodGroupVerified ? Icons.verified : Icons.error,
                        color: _bloodGroupVerified ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bloodGroupVerified
                              ? "Blood Group Verified: ${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}"
                              : "Blood Group Mismatch: ${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}",
                          style: TextStyle(
                            color: _bloodGroupVerified ? Colors.green : Colors.red,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_bloodGroupVerified) ...[
                  const SizedBox(height: 20),
                  const Text(
                    "Donor Verification:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  if (_otpSent && _otpReferenceNo != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.message, color: Colors.blue),
                              const SizedBox(width: 10),
                              const Text("OTP Status:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Sent to: ${_donorInfo!['phone']}"),
                          Text("Reference: ${_otpReferenceNo!.substring(0, 8)}..."),
                          const SizedBox(height: 4),
                          const Text("Please check your phone for the OTP code.", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: "Enter OTP",
                      border: const OutlineInputBorder(),
                      hintText: "6-digit code",
                      counterText: "",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: !_otpSent ? null : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _sendingOtp ? null : _sendOtp,
                        tooltip: "Resend OTP",
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (!_otpSent)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _sendingOtp ? null : _sendOtp,
                        icon: _sendingOtp
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.send),
                        label: _sendingOtp
                            ? const Text("Sending...")
                            : const Text("Send OTP via SMS"),
                      ),
                    )
                  else if (!_otpVerified)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: _verifyingOtp ? null : _verifyOtp,
                            icon: _verifyingOtp
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.verified),
                            label: _verifyingOtp
                                ? const Text("Verifying...")
                                : const Text("Verify OTP"),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _sendingOtp ? null : _sendOtp,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text("Resend OTP"),
                            ),
                            const SizedBox(width: 20),
                            TextButton.icon(
                              onPressed: () {
                                _otpController.clear();
                                setState(() {
                                  _otpSent = false;
                                  _otpReferenceNo = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text("Cancel"),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Donor Verified Successfully!",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Phone: ${_donorInfo!['phone']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _otpVerified = false;
                                _otpController.clear();
                              });
                            },
                            tooltip: "Reset verification",
                          ),
                        ],
                      ),
                    ),
                ],
              ],

              const SizedBox(height: 20),

              TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Points to Add",
                  border: OutlineInputBorder(),
                  hintText: "10",
                  suffixText: "points",
                  prefixIcon: Icon(Icons.point_of_sale),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bloodGroupVerified && _otpVerified ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _bloodGroupVerified && _otpVerified && !_loading ? _addPointsAndRemoveRequest : null,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 8),
                      Text("Add Points & Fulfill Request"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pointsController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}

 */
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'supabase_config.dart';

class AppLinkSmsService {
  final String applicationId;
  final String password;
  final String baseUrl = 'https://api.applink.com.bd';

  AppLinkSmsService({
    required this.applicationId,
    required this.password,
  });

  Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/request'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'applicationId': applicationId,
          'password': password,
          'subscriberId': 'tel:$phoneNumber',
          'applicationHash': 'abcdefgh',
          'applicationMetaData': {
            'client': 'FLUTTERAPP',
            'device': 'Mobile Device',
            'os': 'Android/iOS',
            'appCode': 'com.yourcompany.bloodapp',
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to request OTP: HTTP ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['statusCode'] != 'S1000') {
        throw Exception('OTP request failed: ${responseData['statusDetail']}');
      }

      return responseData;
    } catch (e) {
      throw Exception('OTP request error: $e');
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'applicationId': applicationId,
          'password': password,
          'referenceNo': referenceNo,
          'otp': otp,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to verify OTP: HTTP ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['statusCode'] != 'S1000') {
        throw Exception('OTP verification failed: ${responseData['statusDetail']}');
      }

      return responseData;
    } catch (e) {
      throw Exception('OTP verification error: $e');
    }
  }
}

class PointsAddPage extends StatefulWidget {
  const PointsAddPage({super.key});

  @override
  State<PointsAddPage> createState() => _PointsAddPageState();
}

class _PointsAddPageState extends State<PointsAddPage> {
  final _emailController = TextEditingController();
  final _pointsController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _bloodGroupVerified = false;
  List<Map<String, dynamic>> _bloodRequests = [];
  Map<String, dynamic>? _selectedRequest;
  Map<String, dynamic>? _donorInfo;
  String? _orgId;

  // SMS Service
  late final AppLinkSmsService _smsService;
  String? _otpReferenceNo;

  @override
  void initState() {
    super.initState();
    _fetchBloodRequests();
    _getOrCreateOrganization();

    // Initialize SMS service with your credentials
    _smsService = AppLinkSmsService(
      applicationId: 'APP_018652',
      password: '2e4a87894dc2184f0a9dd19f865cd06c',
    );
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

  Future<void> _getOrCreateOrganization() async {
    final supabase = SupabaseConfig.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) return;

    try {
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

  Future<void> _fetchDonorInfo(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an email address")),
      );
      return;
    }

    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      setState(() {
        _donorInfo = response;
        _loading = false;
        _otpSent = false;
        _otpVerified = false;
        _bloodGroupVerified = false;
        _otpReferenceNo = null;
        _otpController.clear();
      });

      if (_donorInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No donor found with this email")),
        );
      } else {
        _verifyBloodGroup();
      }

    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching donor info: $e")),
      );
    }
  }

  void _verifyBloodGroup() {
    if (_selectedRequest == null || _donorInfo == null) return;

    final requestBloodGroup = _selectedRequest!['blood_group'];
    final donorBloodGroup = _donorInfo!['blood_group'];

    final isCompatible = _isBloodGroupCompatible(donorBloodGroup, requestBloodGroup);

    setState(() {
      _bloodGroupVerified = isCompatible;
    });

    if (isCompatible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group compatible: $donorBloodGroup → $requestBloodGroup"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group mismatch: Donor ($donorBloodGroup) cannot donate to Request ($requestBloodGroup)"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isBloodGroupCompatible(String donorGroup, String recipientGroup) {
    if (donorGroup == null || recipientGroup == null) return false;

    final compatibilityMap = {
      'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
      'O+': ['O+', 'A+', 'B+', 'AB+'],
      'A-': ['A-', 'A+', 'AB-', 'AB+'],
      'A+': ['A+', 'AB+'],
      'B-': ['B-', 'B+', 'AB-', 'AB+'],
      'B+': ['B+', 'AB+'],
      'AB-': ['AB-', 'AB+'],
      'AB+': ['AB+'],
    };

    final normalizedDonor = donorGroup.replaceAll(' ', '').toUpperCase();
    final normalizedRecipient = recipientGroup.replaceAll(' ', '').toUpperCase();

    return compatibilityMap[normalizedDonor]?.contains(normalizedRecipient) ?? false;
  }

  Future<void> _sendOtp() async {
    if (_donorInfo == null || _donorInfo!['phone'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donor phone number not available")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    setState(() => _sendingOtp = true);
    _otpController.clear();

    try {
      final phoneNumber = _donorInfo!['phone'].toString();

      // Clean phone number format
      final cleanPhone = phoneNumber.startsWith('0') ? phoneNumber.substring(1) : phoneNumber;
      final formattedPhone = '880$cleanPhone';

      // Request OTP from AppLink API
      final response = await _smsService.requestOtp(
        phoneNumber: formattedPhone,
      );

      // Store the reference number for verification
      _otpReferenceNo = response['referenceNo'];

      // Store OTP in database for verification
      final supabase = SupabaseConfig.client;
      final userId = _donorInfo!['id'];
      final otp = _generateOtp(); // Generate OTP for database storage
      final expiresAt = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      await supabase.from('otp_verifications').insert({
        'user_id': userId,
        'phone': formattedPhone,
        'otp': otp,
        'reference_no': _otpReferenceNo,
        'expires_at': expiresAt,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      setState(() {
        _otpSent = true;
        _sendingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("OTP has been sent to $formattedPhone"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() => _sendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sending OTP: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _verifyOtp() async {
    if (_donorInfo == null || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the OTP")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required first")),
      );
      return;
    }

    if (_otpReferenceNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No OTP request found. Please send OTP first.")),
      );
      return;
    }

    setState(() => _verifyingOtp = true);

    try {
      // Verify OTP with AppLink API
      final verificationResponse = await _smsService.verifyOtp(
        referenceNo: _otpReferenceNo!,
        otp: _otpController.text.trim(),
      );

      // Update database with verification status
      final supabase = SupabaseConfig.client;
      final userId = _donorInfo!['id'];

      await supabase.from('otp_verifications')
          .update({
        'verified_at': DateTime.now().toIso8601String(),
        'status': 'verified',
      })
          .eq('reference_no', _otpReferenceNo!)
          .eq('user_id', userId);

      setState(() {
        _otpVerified = true;
        _verifyingOtp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("OTP verified successfully!"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() => _verifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error verifying OTP: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addPointsAndRemoveRequest() async {
    if (_selectedRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a blood request")),
      );
      return;
    }

    if (_donorInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fetch donor information first")),
      );
      return;
    }

    if (!_bloodGroupVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Blood group verification required")),
      );
      return;
    }

    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify donor with OTP first")),
      );
      return;
    }

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
    final requestId = _selectedRequest!['id'];
    final donorId = _donorInfo!['id'];
    final email = _emailController.text.trim();
    final currentUserId = supabase.auth.currentUser?.id;

    try {
      // Add points to donor
      try {
        await supabase.rpc('increment_points', params: {
          'userid': donorId,
          'p': points,
        });
      } catch (e) {
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

      // Record donation
      await supabase.from('donations').insert({
        'donor_id': donorId,
        'org_id': _orgId,
        'donation_date': DateTime.now().toIso8601String(),
        'points_earned': points,
        'hospital_name': _selectedRequest!['hospital'],
        'request_id': requestId,
      });

      // Update donor's last donation date
      await supabase.from('users').update({
        'last_donate': DateTime.now().toIso8601String(),
      }).eq('id', donorId);

      // Mark request as fulfilled
      await supabase
          .from('requests')
          .update({
        'is_fulfilled': true,
        'fulfilled_at': DateTime.now().toIso8601String(),
        'fulfilled_by': currentUserId,
        'fulfilled_donor_id': donorId,
      })
          .eq('id', requestId);

      // Create audit log
      await supabase.from('audit_logs').insert({
        'action': 'points_added_request_fulfilled',
        'performed_by': currentUserId,
        'target_user': donorId,
        'details': 'Added $points points and fulfilled blood request $requestId',
        'performed_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Points added and request fulfilled successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      await _fetchDonorInfo(email);
      await _fetchBloodRequests();

      // Reset form
      _resetForm();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedRequest = null;
      _donorInfo = null;
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
      _otpReferenceNo = null;
    });
  }

  void _onRequestSelected(Map<String, dynamic> request) {
    setState(() {
      _selectedRequest = request;
      _emailController.clear();
      _pointsController.text = '10';
      _donorInfo = null;
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
      _otpReferenceNo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Donor Verification & Points Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 2,
        shadowColor: Colors.red.shade200,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchBloodRequests,
            tooltip: "Refresh Requests",
          ),
        ],
      ),
      body: _loading && _bloodRequests.isEmpty
          ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text("Loading blood requests...", style: TextStyle(color: Colors.grey)),
            ],
          ))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bloodtype, color: Colors.red, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Blood Request Fulfillment",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _bloodRequests.isEmpty
                                ? "No pending requests"
                                : "${_bloodRequests.length} pending blood request${_bloodRequests.length > 1 ? 's' : ''}",
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Step 1: Select Blood Request
            _buildSectionHeader("1. Select Blood Request"),
            const SizedBox(height: 12),

            if (_bloodRequests.isEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48),
                        SizedBox(height: 12),
                        Text(
                          "All requests fulfilled!",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "No pending blood requests available.",
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bloodRequests.length,
                  itemBuilder: (context, index) {
                    final request = _bloodRequests[index];
                    final isSelected = _selectedRequest?['id'] == request['id'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red.shade50 : Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: isSelected ? Colors.red : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bloodtype,
                            color: isSelected ? Colors.white : Colors.red,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          "${request['blood_group']} Blood Request",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.red : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildDetailRow(Icons.local_hospital, request['hospital']),
                            _buildDetailRow(Icons.location_on, request['location']),
                            _buildDetailRow(Icons.calendar_today, "Needed by: ${request['needed_by']}"),
                            if (request['contact_info'] != null)
                              _buildDetailRow(Icons.phone, request['contact_info']),
                          ],
                        ),
                        trailing: isSelected
                            ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        )
                            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _onRequestSelected(request),
                      ),
                    );
                  },
                ),
              ),

            // Show selected request details
            if (_selectedRequest != null) ...[
              const SizedBox(height: 24),
              _buildSectionHeader("Selected Request"),
              const SizedBox(height: 12),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.info, color: Colors.red, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${_selectedRequest!['blood_group']} Blood Request",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _selectedRequest!['hospital'],
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        Icons.medical_services,
                        "Medical Details",
                        [
                          "Hospital: ${_selectedRequest!['hospital']}",
                          "Location: ${_selectedRequest!['location']}",
                          "Needed by: ${_selectedRequest!['needed_by']}",
                          if (_selectedRequest!['blood_units'] != null)
                            "Units: ${_selectedRequest!['blood_units']}",
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Step 2: Search Donor
            if (_selectedRequest != null) ...[
              const SizedBox(height: 24),
              _buildSectionHeader("2. Search Donor"),
              const SizedBox(height: 12),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Donor Email",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: "Enter donor's email address",
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  _fetchDonorInfo(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                if (_emailController.text.isNotEmpty) {
                                  _fetchDonorInfo(_emailController.text.trim());
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please enter an email address")),
                                  );
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.search, size: 20),
                                    SizedBox(width: 8),
                                    Text("Search"),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Donor Information
              if (_donorInfo != null) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("Donor Information"),
                const SizedBox(height: 12),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_outline, color: Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _donorInfo!['name'] ?? 'Unknown Donor',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _donorInfo!['email'] ?? 'N/A',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${_donorInfo!['total_points']?.toString() ?? '0'} pts",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildInfoChip(Icons.phone, _donorInfo!['phone'] ?? 'N/A', Colors.green),
                            const SizedBox(width: 12),
                            _buildInfoChip(Icons.bloodtype, _donorInfo!['blood_group'] ?? 'N/A', Colors.red),
                          ],
                        ),

                        // Blood Group Verification
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _bloodGroupVerified ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _bloodGroupVerified ? Colors.green.shade200 : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _bloodGroupVerified ? Icons.verified : Icons.error_outline,
                                color: _bloodGroupVerified ? Colors.green : Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _bloodGroupVerified ? "Blood Group Compatible" : "Blood Group Mismatch",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _bloodGroupVerified ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Donor (${_donorInfo!['blood_group']}) → Request (${_selectedRequest!['blood_group']})",
                                      style: TextStyle(
                                        color: _bloodGroupVerified ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Step 3: Donor Verification (Only if blood group is verified)
              if (_bloodGroupVerified && _donorInfo != null) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("3. Donor Verification"),
                const SizedBox(height: 12),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Send OTP Button Section
                        if (!_otpSent && !_otpVerified)
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.sms_outlined, color: Colors.blue, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Verify Donor via SMS",
                                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Send OTP to ${_donorInfo!['phone']}",
                                            style: TextStyle(color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: _sendingOtp ? null : _sendOtp,
                                  icon: _sendingOtp
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Icon(Icons.send_outlined),
                                  label: _sendingOtp
                                      ? const Text("Sending OTP...")
                                      : const Text("Send OTP via SMS"),
                                ),
                              ),
                            ],
                          ),

                        // OTP Input Section (Shows after OTP is sent)
                        if (_otpSent && !_otpVerified) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.message_outlined, color: Colors.orange, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "OTP Sent Successfully",
                                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Check ${_donorInfo!['phone']} for the 6-digit code",
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // OTP Input Field
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, letterSpacing: 8),
                            decoration: InputDecoration(
                              labelText: "Enter 6-digit OTP",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              counterText: "",
                              hintText: "••••••",
                              hintStyle: const TextStyle(letterSpacing: 8),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Verify OTP Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _verifyingOtp ? null : _verifyOtp,
                              icon: _verifyingOtp
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(Icons.verified_outlined),
                              label: _verifyingOtp
                                  ? const Text("Verifying...")
                                  : const Text("Verify OTP"),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Resend/Cancel Options
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _sendingOtp ? null : _sendOtp,
                                icon: const Icon(Icons.refresh_outlined, size: 16),
                                label: const Text("Resend OTP"),
                              ),
                              const SizedBox(width: 20),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _otpSent = false;
                                    _otpController.clear();
                                  });
                                },
                                icon: const Icon(Icons.close_outlined, size: 16),
                                label: const Text("Cancel"),
                              ),
                            ],
                          ),
                        ],

                        // OTP Verified Status
                        if (_otpVerified)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, color: Colors.green, size: 28),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Donor Verified Successfully!",
                                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Phone: ${_donorInfo!['phone']}",
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_outlined, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _otpVerified = false;
                                      _otpSent = false;
                                      _otpController.clear();
                                    });
                                  },
                                  tooltip: "Reset verification",
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              // Step 4: Add Points & Complete
              if (_bloodGroupVerified && _otpVerified) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("4. Complete Donation"),
                const SizedBox(height: 12),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Points Input
                        const Text(
                          "Points to Award",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pointsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Enter points",
                            hintText: "10",
                            prefixIcon: const Icon(Icons.star_outline),
                            suffixText: "points",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Summary Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.summarize_outlined, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Transaction Summary",
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow("Donor:", _donorInfo!['name']),
                              _buildSummaryRow("Blood Group:", "${_donorInfo!['blood_group']} → ${_selectedRequest!['blood_group']}"),
                              _buildSummaryRow("Hospital:", _selectedRequest!['hospital']),
                              _buildSummaryRow("Points to Add:", "${_pointsController.text} points"),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Points After:",
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    "${(_donorInfo!['total_points'] ?? 0) + (int.tryParse(_pointsController.text) ?? 0)} points",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: Colors.red.shade300,
                            ),
                            onPressed: _loading ? null : _addPointsAndRemoveRequest,
                            child: _loading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline),
                                SizedBox(width: 12),
                                Text(
                                  "Add Points & Complete Donation",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.red,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, List<String> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              detail,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pointsController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}