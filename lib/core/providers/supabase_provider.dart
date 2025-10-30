import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase configuration from environment variables
// ⚠️ WARNING: TEMPORARY DEFAULT VALUES FOR DEVELOPMENT ONLY
// TODO: REMOVE THESE BEFORE COMMITTING TO GIT OR DEPLOYING TO PRODUCTION
// Run with: flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://vgbdmntdjyltngurzcxw.supabase.co',  // ⚠️ TEMPORARY - REMOVE BEFORE COMMIT
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnYmRtbnRkanlsdG5ndXJ6Y3h3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3MjkwNDksImV4cCI6MjA3NzMwNTA0OX0.eIWOg_WvmfybYwzgfdpXSO1HyyKYRwTH_JDaGB6jQhc',  // ⚠️ TEMPORARY - REMOVE BEFORE COMMIT
);

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseInitProvider = FutureProvider<void>((ref) async {
  if (Supabase.instance.client.rest.url.isEmpty) {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  }
});

