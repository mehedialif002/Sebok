import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'dart:math';
import 'point.dart';
class RequestSelectionPage extends StatefulWidget {
  const RequestSelectionPage({super.key});

  @override
  State<RequestSelectionPage> createState() => _RequestSelectionPageState();
}

class _RequestSelectionPageState extends State<RequestSelectionPage> {
  final _emailController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _fetchBloodRequests();
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

  void _onRequestSelected(Map<String, dynamic> request) {
    setState(() {
      _selectedRequest = request;
      // Clear email field when selecting a new request
      _emailController.clear();
      _donorInfo = null; // Reset donor info
      _otpSent = false;
      _otpVerified = false;
      _bloodGroupVerified = false;
      _otpController.clear();
    });
  }

  void _navigateToPointsPage() {
    if (_selectedRequest == null || _donorInfo == null || !_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete verification first")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PointsAddPage(
          selectedRequest: _selectedRequest!,
          donorInfo: _donorInfo!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Select Request & Verify Donor", style: TextStyle(color: Colors.white)),
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

          // Donor Verification Section
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
                            Column(
                              children: [
                                const Text(
                                  "Donor verified successfully!",
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                    ),
                                    onPressed: _navigateToPointsPage,
                                    child: const Text("Continue to Add Points"),
                                  ),
                                ),
                              ],
                            ),
                        const SizedBox(height: 16),
                      ],
                    ],
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
    _otpController.dispose();
    super.dispose();
  }
}