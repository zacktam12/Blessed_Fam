import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';
import '../models/announcement.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(ref);
});

// Provider to fetch latest announcements; can be invalidated to refresh the UI
final announcementsListProvider = FutureProvider.autoDispose.family<List<Announcement>, int>((ref, limit) async {
  final repo = ref.read(announcementsRepositoryProvider);
  return repo.fetchLatest(limit: limit);
});

class AnnouncementsRepository {
  AnnouncementsRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<List<Announcement>> fetchLatest({int limit = 20}) async {
    final res = await _client
        .from('announcements')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List<dynamic>)
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Inserts a new announcement and returns the created row as [Announcement].
  /// Also optionally sends push notifications if [notify] is true.
  Future<Announcement> createAnnouncement({required String title, required String message, bool notify = false}) async {
    final uid = _client.auth.currentUser?.id;
    final res = await _client.from('announcements').insert({
      'title': title,
      'message': message,
      'posted_by': uid,
    }).select().single();
  final created = Announcement.fromJson(res);
    if (notify) {
      // fetch tokens and invoke edge function
      final tokens = await _client.from('device_tokens').select('token');
      final list = (tokens as List<dynamic>).map((e) => (e as Map<String, dynamic>)['token'] as String).toList();
      if (list.isNotEmpty) {
        await _client.functions.invoke('send_push', body: {
          'tokens': list,
          'title': title,
          'body': message,
        });
      }
    }
    return created;
  }

  /// Updates an existing announcement.
  /// Only admins can update announcements (enforced by RLS).
  Future<Announcement> updateAnnouncement({
    required int id,
    required String title,
    required String message,
  }) async {
    final res = await _client
        .from('announcements')
        .update({
          'title': title,
          'message': message,
        })
        .eq('id', id)
        .select()
        .single();
    return Announcement.fromJson(res);
  }

  /// Deletes an announcement by ID.
  /// Only admins can delete announcements (enforced by RLS).
  Future<void> deleteAnnouncement({required int id}) async {
    await _client.from('announcements').delete().eq('id', id);
  }

  /// Fetches a single announcement by ID.
  Future<Announcement?> getAnnouncementById({required int id}) async {
    final res = await _client
        .from('announcements')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Announcement.fromJson(res);
  }

}


