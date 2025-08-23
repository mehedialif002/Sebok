import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://ppmzabgdsejyaxovopqi.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBwbXphYmdkc2VqeWF4b3ZvcHFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3ODY0MTYsImV4cCI6MjA3MTM2MjQxNn0.4Hinu3LA65LRrW30hR-Y_Wx2sKFIpi8d8XimfNy8xTI', // 🔹 Replace with your Supabase anon key
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
