/*
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


 */
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Check if username is available in the database
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

  // Pick the date for last donation
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

  // Pick the profile image
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  // Upload the profile image to Supabase storage
  Future<String?> _uploadImage(File imageFile, String userId) async {
    try {
      final supabase = SupabaseConfig.client;

      // Generate a unique filename for the image
      final String fileName = 'user_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'user_avatars/$fileName';

      print('Uploading image: $filePath');
      print('File exists: ${await imageFile.exists()}');
      print('File size: ${await imageFile.length()} bytes');

      // Upload the image to Supabase Storage
      final String uploadedPath = await supabase.storage
          .from('avatars') // Make sure you have a bucket named 'avatars'
          .upload(filePath, imageFile);

      print('Upload successful: $uploadedPath');

      // Return the public URL of the uploaded image
      final String imageUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      print('Public URL: $imageUrl');
      return imageUrl;
    } on StorageException catch (e) {
      print('Storage error: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Storage error: ${e.message}")),
      );
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: $e")),
      );
      return null;
    }
  }

  // Register the user
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

      final String userId = authResponse.user!.id;

      DateTime? nextDonation;
      if (lastDonateDate != null) {
        nextDonation = DateTime(
          lastDonateDate!.year,
          lastDonateDate!.month + 3,
          lastDonateDate!.day,
        );
      }

      // Upload the image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!, userId);
      }

      // Insert user data into Supabase database
      await supabase.from('users').insert({
        'id': userId,
        'name': nameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': roleController.text.trim(),
        'blood_group': bloodController.text.trim(),
        'last_donate': lastDonateDate?.toIso8601String(),
        'next_donate': nextDonation?.toIso8601String(),
        'occupation': occupationController.text.trim(),
        'image_url': imageUrl,
        'total_points': 0, // Initialize with 0 points
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

                // Profile Image Picker
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : null,
                          child: _selectedImage == null
                              ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                      TextButton(
                        onPressed: _pickImage,
                        child: const Text(
                          "Upload Profile Picture",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
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

  // Helper function to create text fields
  Widget buildTextField(String label, TextEditingController controller, {bool isPassword = false}) {
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

  // Text field with username availability check
  Widget buildTextFieldWithAvailabilityCheck(String label, TextEditingController controller, {required Function(String) onChanged}) {
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
                _isUsernameAvailable ? "Username available" : "Username already taken",
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