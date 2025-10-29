import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Replace with your Supabase project values
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://vgbdmntdjyltngurzcxw.supabase.co');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnYmRtbnRkanlsdG5ndXJ6Y3h3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3MjkwNDksImV4cCI6MjA3NzMwNTA0OX0.eIWOg_WvmfybYwzgfdpXSO1HyyKYRwTH_JDaGB6jQhc');

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseInitProvider = FutureProvider<void>((ref) async {
  if (Supabase.instance.client.rest.url.isEmpty) {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  }
});

