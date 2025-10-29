import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';
import '../models/announcement.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(ref);
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

  Future<void> createAnnouncement({required String title, required String message, bool notify = false}) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('announcements').insert({
      'title': title,
      'message': message,
      'posted_by': uid,
    });
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
  }
}

