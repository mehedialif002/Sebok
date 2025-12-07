import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'supabase_config.dart';
import 'register_page.dart';
import 'dashboard_page.dart';
import 'admin_dashboard.dart';
import 'org_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init(); // initialize supabase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  // Function to get role from JWT token (auth.users.raw_app_meta_data)
  Future<String?> getRoleFromJWT() async {
    try {
      final supabase = SupabaseConfig.client;
      final session = supabase.auth.currentSession;

      if (session != null) {
        // Decode the JWT token to access the claims
        final accessToken = session.accessToken;
        final decodedToken = JwtDecoder.decode(accessToken);

        print("JWT Token claims: $decodedToken");

        // The role should be in the app_metadata section
        final appMetadata = decodedToken['app_metadata'];
        if (appMetadata != null && appMetadata is Map) {
          final role = appMetadata['role'] as String?;
          print("Role from JWT app_metadata: $role");
          return role;
        }

        // Alternative: check if role is directly in the token
        final role = decodedToken['role'] as String?;
        if (role != null) {
          print("Role from JWT directly: $role");
          return role;
        }
      }

      return null;
    } catch (e) {
      print("Error getting role from JWT: $e");
      return null;
    }
  }

  // Function to check if user exists in organizations table
  Future<bool> isUserInOrganizationsTable(String userId) async {
    try {
      final supabase = SupabaseConfig.client;

      // Check if user exists in organizations table as admin
      final orgResponse = await supabase
          .from('organizations')
          .select('id')
          .eq('admin_id', userId)
          .maybeSingle();

      return orgResponse != null;
    } catch (e) {
      print("Error checking organizations table: $e");
      return false;
    }
  }

  Future<void> loginUser() async {
    setState(() => isLoading = true);
    try {
      final supabase = SupabaseConfig.client;
      final response = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (response.user != null) {
        print("User logged in: ${response.user!.email}");

        // Get the user's role from JWT token (auth.users.raw_app_meta_data)
        final role = await getRoleFromJWT();
        print("Detected user role: '$role'");

        // Check if user exists in organizations table
        final isInOrganizationsTable = await isUserInOrganizationsTable(response.user!.id);
        print("User in organizations table: $isInOrganizationsTable");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Successful! Role: ${role ?? 'Not set'}")),
        );

        // Redirect based on user role and organization membership
        if (role == 'admin') {
          print("Redirecting to admin dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(userId: response.user!.id),
            ),
          );
        } else if (role == 'manager' || isInOrganizationsTable) {
          // Redirect to organization dashboard if user is a manager OR is in organizations table
          print("Redirecting to organization dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrgDashboard(userId: response.user!.id),
            ),
          );
        } else {
          // Default to regular user dashboard
          print("Redirecting to regular user dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardPage(userId: response.user!.id),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Error: $e")),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.red[900],
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.bloodtype, color: Colors.red[900], size: 50),
                ),
                const SizedBox(height: 8),
                const Text(
                  "সেবক",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Login text
            const Text(
              "Login",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Email input
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: "Email",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Password input
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Password",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Login Button
            SizedBox(
              width: 200,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading ? null : loginUser,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.red)
                    : const Text(
                  "Login",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Register Button
            SizedBox(
              width: 200,
              height: 45,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text(
                  "Register",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}