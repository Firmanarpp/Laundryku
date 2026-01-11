import 'package:flutter_dotenv/flutter_dotenv.dart';

// Configuration class untuk Supabase
// Menggunakan environment variables untuk keamanan
// Credentials tidak lagi hardcoded di source code
class SupabaseConfig {
  // Load dari .env file untuk security best practice
  // Production: jangan commit .env ke Git
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
