import 'dart:convert';
import 'package:http/http.dart' as http;

class BanglalinkSMS {
  final String clientId = "YOUR_CLIENT_ID";
  final String clientSecret = "YOUR_SECRET";
  final String appId = "YOUR_APP_ID";
  final String password = "YOUR_PASSWORD";

  final String baseUrl =
      "https://dev-applink.hsenidmobile.com:7443/hsenidmobile/sms/send";

  Future<String> sendSMS(String number, String message) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "clientId": clientId,
          "clientSecret": clientSecret,
        },
        body: jsonEncode({
          "applicationId": appId,
          "password": password,
          "message": message,
          "destinationAddress": number,
        }),
      );

      print("API Response: ${response.body}");

      if (response.statusCode == 200) {
        return "SMS Sent Successfully!";
      } else {
        return "Failed: ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
