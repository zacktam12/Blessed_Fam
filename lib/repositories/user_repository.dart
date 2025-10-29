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
    if (uid == null) return null;
    try {
      final res = await _client.from('users').select().eq('id', uid).maybeSingle();
      if (res == null) return null;
      return UserProfile.fromJson(res);
    } on PostgrestException {
      // If RLS/policy temporarily blocks or row missing, avoid blocking UI
      return null;
    }
  }

  Future<List<UserProfile>> listAllUsers() async {
    final res = await _client.from('users').select().order('name', ascending: true);
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
}

