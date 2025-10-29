import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';
import '../models/attendance.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref);
});

class AttendanceRepository {
  AttendanceRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<AttendanceRecord> checkIn({
    required String userId,
    required int sessionId,
    required DateTime date,
    String status = 'present',
  }) async {
    final res = await _client.rpc('check_in', params: {
      'p_user': userId,
      'p_session_id': sessionId,
      'p_date': date.toIso8601String().substring(0, 10),
      'p_status': status,
    });
    return AttendanceRecord.fromJson(res as Map<String, dynamic>);
  }
}

