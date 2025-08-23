
import 'package:flutter/material.dart';
import 'supabase_config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final roleController = TextEditingController();
  final bloodController = TextEditingController();
  final occupationController = TextEditingController();
  final passwordController = TextEditingController();

  DateTime? lastDonateDate;
  bool isLoading = false;
  bool _isUsernameAvailable = true;

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) return;

    try {
      final supabase = SupabaseConfig.client;
      final response = await supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      setState(() {
        _isUsernameAvailable = response == null;
      });
    } catch (e) {
      print('Error checking username: $e');
    }
  }

  Future<void> _pickLastDonateDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        lastDonateDate = picked;
      });
    }
  }

  Future<void> registerUser() async {
    if (!_isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username already taken. Please choose another.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final supabase = SupabaseConfig.client;

      final authResponse = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (authResponse.user == null) {
        throw Exception("Signup failed");
      }

      DateTime? nextDonation;
      if (lastDonateDate != null) {
        nextDonation = DateTime(
          lastDonateDate!.year,
          lastDonateDate!.month + 3,
          lastDonateDate!.day,
        );
      }

      await supabase.from('users').insert({
        'id': authResponse.user!.id,
        'name': nameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': roleController.text.trim(),
        'blood_group': bloodController.text.trim(),
        'last_donate': lastDonateDate?.toIso8601String(),
        'next_donate': nextDonation?.toIso8601String(),
        'occupation': occupationController.text.trim(),
        'image_url': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[900],
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Back to Login", style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Register",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                buildTextField("Name", nameController),
                buildTextFieldWithAvailabilityCheck(
                  "Username",
                  usernameController,
                  onChanged: _checkUsernameAvailability,
                ),
                buildTextField("Email", emailController),
                buildTextField("Phone", phoneController),
                buildTextField("Role (admin/manager/donor/doctor)", roleController),
                buildTextField("Blood Group (A+/O-/...)", bloodController),

                // Date Picker
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: _pickLastDonateDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Last Donate",
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      child: Text(
                        lastDonateDate != null
                            ? "${lastDonateDate!.toLocal()}".split(' ')[0]
                            : "Select date",
                        style: TextStyle(
                          color: lastDonateDate != null ? Colors.black : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),

                buildTextField("Occupation", occupationController),
                buildTextField("Password", passwordController, isPassword: true),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isLoading ? null : registerUser,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Submit"),
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Back to Login",
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget buildTextFieldWithAvailabilityCheck(
      String label,
      TextEditingController controller,
      {required Function(String) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? Icon(
                _isUsernameAvailable ? Icons.check_circle : Icons.cancel,
                color: _isUsernameAvailable ? Colors.green : Colors.red,
              )
                  : null,
            ),
            onChanged: onChanged,
          ),
          if (controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isUsernameAvailable
                    ? "Username available"
                    : "Username already taken",
                style: TextStyle(
                  color: _isUsernameAvailable ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
