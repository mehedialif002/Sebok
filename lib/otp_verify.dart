import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'otp_email_page.dart';
class OTPVerifyPage extends StatefulWidget {
  final String gmail;
  OTPVerifyPage({required this.gmail});

  @override
  State<OTPVerifyPage> createState() => _OTPVerifyPageState();
}

class _OTPVerifyPageState extends State<OTPVerifyPage> {
  final TextEditingController otpController = TextEditingController();
  bool verifying = false;

  Future<void> verifyOtp() async {
    setState(() => verifying = true);

    final url = Uri.parse("http://YOUR_IP:8000/api/verify-otp/");
    final response = await http.post(
      url,
      body: {
        "gmail": widget.gmail,
        "otp": otpController.text,
      },
    );

    setState(() => verifying = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("OTP Verified Successfully!")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Invalid OTP")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Enter OTP",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: verifying ? null : verifyOtp,
              child: verifying
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Verify OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
