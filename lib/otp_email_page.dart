import 'package:flutter/material.dart';
import 'otp_verify.dart';
import '../supabase_config.dart';

class OTPEmailPage extends StatefulWidget {
  final String requestId;
  OTPEmailPage({required this.requestId});

  @override
  State<OTPEmailPage> createState() => _OTPEmailPageState();
}

class _OTPEmailPageState extends State<OTPEmailPage> {
  final TextEditingController gmailController = TextEditingController();

  Map<String, dynamic>? _donorInfo;
  bool _loading = false;

  // ---------------------------------------------------------------------------
  // FETCH DONOR INFO USING SUPABASE
  // ---------------------------------------------------------------------------
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
      });

      if (_donorInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No donor found with this email")),
        );
      } else {
        // If donor exists → Redirect to OTP Verification Page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerifyPage(gmail: email),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching donor info: $e")),
      );
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Donor Verification")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: gmailController,
              decoration: InputDecoration(
                labelText: "Enter Donor Gmail",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // SEND OTP BUTTON → Actually fetch donor info first
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _fetchDonorInfo(gmailController.text.trim()),
              child: _loading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Get OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
