import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';
import '../models/session.dart';

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(ref);
});

class SessionsRepository {
  SessionsRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<List<SessionType>> fetchSessions() async {
    final res = await _client.from('sessions').select();
    return (res as List<dynamic>)
        .map((e) => SessionType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateSessionTime({
    required int sessionId,
    required TimeOfDay? startTime,
  }) async {
    // Convert TimeOfDay to HH:MM string format
    final timeString = startTime != null
        ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
        : null;

    await _client.from('sessions').update({
      'start_time': timeString,
    }).eq('id', sessionId);
  }
}

