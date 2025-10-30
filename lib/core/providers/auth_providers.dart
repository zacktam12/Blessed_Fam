import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_provider.dart';
import '../../repositories/user_repository.dart';
import '../../models/user_profile.dart';

final currentSessionProvider = Provider<Session?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.currentSession;
});

final authStateListenableProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  final supabase = ref.watch(supabaseProvider);
  supabase.auth.onAuthStateChange.listen((event) {
    notifier.value++;
  });
  return notifier;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref);
});

class AuthRepository {
  AuthRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<AuthResponse> signInWithEmailPassword(
      {required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmailPassword(
      {required String email, required String password}) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Sends a password reset email to [email].
  ///
  /// Supabase will send the reset link to the user's email if the account exists.
  Future<void> resetPassword({required String email}) async {
    // supabase_flutter provides a helper to request a password reset email.
    // The Supabase client expects the email as a positional argument in some
    // versions; pass it positionally to be compatible with the installed SDK.
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Admin-only: Create a new user account
  /// This uses Supabase's admin API to create users without email confirmation
  Future<void> createUserAsAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    // Create auth user
    final response = await _client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true, // Auto-confirm email
      ),
    );

    if (response.user == null) {
      throw Exception('Failed to create user');
    }

    // Update the user profile with name and role
    await _client.from('users').update({
      'name': name,
      'role': role,
    }).eq('id', response.user!.id);
  }
}

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.read(userRepositoryProvider);
  return repo.getCurrentUserProfile();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  return profile?.role == 'admin';
});
