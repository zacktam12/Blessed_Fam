import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';
import '../models/user_profile.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref);
});

class UserRepository {
  UserRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<UserProfile?> getCurrentUserProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('getCurrentUserProfile: No authenticated user');
      return null;
    }

    try {
      debugPrint('getCurrentUserProfile: Fetching profile for user $uid');
      final res =
          await _client.from('users').select().eq('id', uid).maybeSingle();

      if (res == null) {
        debugPrint('getCurrentUserProfile: No profile found for user $uid');
        return null;
      }

      final profile = UserProfile.fromJson(res);
      debugPrint(
          'getCurrentUserProfile: Found profile - Role: ${profile.role}, Name: ${profile.name}');
      return profile;
    } on PostgrestException catch (e) {
      debugPrint('getCurrentUserProfile: PostgrestException - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('getCurrentUserProfile: Unexpected error - $e');
      return null;
    }
  }

  Future<List<UserProfile>> listAllUsers() async {
    final res =
        await _client.from('users').select().order('name', ascending: true);
    return (res as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lists only members (excludes admins) for attendance tracking and rankings
  Future<List<UserProfile>> listMembers() async {
    final res = await _client
        .from('users')
        .select()
        .eq('role', 'member')
        .order('name', ascending: true);
    return (res as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserProfile>> fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Fall back to fetching all users and filtering locally. This is simpler
    // and avoids depending on a specific PostgREST client method name across
    // versions. If your user table is large, consider adding a dedicated RPC
    // or using the `in` operator via query parameters.
    final all = await listAllUsers();
    final setIds = ids.toSet();
    return all.where((u) => setIds.contains(u.id)).toList();
  }

  /// Delete a user (admin only)
  Future<void> deleteUser(String userId) async {
    try {
      // Delete user from users table
      await _client.from('users').delete().eq('id', userId);
      
      // Note: Related records (attendance, performance, etc.) should be handled
      // by cascade delete rules in the database or cleaned up separately
      debugPrint('✅ User $userId deleted successfully');
    } catch (e) {
      debugPrint('❌ Failed to delete user: $e');
      rethrow;
    }
  }
}
