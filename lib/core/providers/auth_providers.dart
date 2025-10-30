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
    try {
      await _client.auth.signOut();
    } catch (e) {
      // Even if signOut fails, we want to clear local session
      debugPrint('Sign out error: $e');
    }
  }

  /// Admin-only: Create a new user account
  /// This calls a secure edge function that uses admin privileges
  Future<void> createUserAsAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create_user_admin',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Failed to create user';
        throw Exception(error);
      }

      if (response.data?['success'] != true) {
        throw Exception(response.data?['error'] ?? 'User creation failed');
      }
    } catch (e) {
      debugPrint('Create user error: $e');
      rethrow;
    }
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
