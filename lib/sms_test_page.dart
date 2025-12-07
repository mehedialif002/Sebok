import 'package:flutter/material.dart';
import 'banglalink_sms.dart';

class SMSPage extends StatefulWidget {
  @override
  _SMSPageState createState() => _SMSPageState();
}

class _SMSPageState extends State<SMSPage> {
  final TextEditingController phone = TextEditingController();
  final TextEditingController msg = TextEditingController();
  bool loading = false;

  void sendSMS() async {
    setState(() => loading = true);

    final api = BanglalinkSMS();
    final result = await api.sendSMS(phone.text, msg.text);

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Banglalink SMS Test")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Enter Phone Number (e.g. 88017xxxxxxx)",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            TextField(
              controller: msg,
              decoration: InputDecoration(
                labelText: "Enter Message",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            loading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: sendSMS,
              child: Text("SEND SMS"),
            ),
          ],
        ),
      ),
    );
  }
}
