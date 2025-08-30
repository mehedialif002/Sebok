import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class OrganizationRegistrationPage extends StatefulWidget {
  const OrganizationRegistrationPage({super.key});

  @override
  State<OrganizationRegistrationPage> createState() => _OrganizationRegistrationPageState();
}

class _OrganizationRegistrationPageState extends State<OrganizationRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _registerOrganization() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    final supabase = SupabaseConfig.client;

    try {
      // First, sign up the admin user
      final AuthResponse authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'name': _contactPersonController.text.isNotEmpty
              ? _contactPersonController.text.trim()
              : 'Organization Admin',
          'role': 'organization_admin',
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final currentUserId = authResponse.user!.id;

      // Check if organization already exists for this user
      final existingOrg = await supabase
          .from('organizations')
          .select()
          .eq('admin_id', currentUserId)
          .maybeSingle();

      if (existingOrg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already have an organization registered")),
        );
        setState(() => _loading = false);
        return;
      }

      // Prepare data for insertion
      final organizationData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'admin_id': currentUserId,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add optional fields if they have values
      if (_addressController.text.isNotEmpty) {
        organizationData['address'] = _addressController.text.trim();
      }

      if (_cityController.text.isNotEmpty) {
        organizationData['city'] = _cityController.text.trim();
      }

      if (_stateController.text.isNotEmpty) {
        organizationData['state'] = _stateController.text.trim();
      }

      if (_zipCodeController.text.isNotEmpty) {
        organizationData['zip_code'] = _zipCodeController.text.trim();
      }

      if (_contactPersonController.text.isNotEmpty) {
        organizationData['contact_person'] = _contactPersonController.text.trim();
      }

      if (_contactPhoneController.text.isNotEmpty) {
        organizationData['contact_phone'] = _contactPhoneController.text.trim();
      }

      // Insert new organization
      await supabase
          .from('organizations')
          .insert(organizationData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization registered successfully!")),
      );

      // Navigate back
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error registering organization: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Organization'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Organization Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Organization Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter organization name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // City, State, Zip Code Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _zipCodeController,
                      decoration: const InputDecoration(
                        labelText: 'ZIP Code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Contact Person Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Contact Person
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(
                  labelText: 'Contact Person Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Contact Phone
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 30),

              // Register Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _loading ? null : _registerOrganization,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Register Organization',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}