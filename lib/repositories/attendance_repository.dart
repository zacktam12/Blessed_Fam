import 'package:flutter/foundation.dart';
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
    final res = await _client.rpc<Map<String, dynamic>>('check_in', params: {
      'p_user': userId,
      'p_session_id': sessionId,
      'p_date': date.toIso8601String().substring(0, 10),
      'p_status': status,
    });
    final record = AttendanceRecord.fromJson(res);

    // Recompute weekly performance snapshot for the affected week so that
    // leaderboard/weekly winner stays in sync with new attendance.
    try {
      final weekday = date.weekday; // 1=Mon..7=Sun
      final monday = date.subtract(Duration(days: (weekday - DateTime.monday) % 7));
      final weekStartIso = DateTime(monday.year, monday.month, monday.day)
          .toIso8601String()
          .substring(0, 10);
      await _client.rpc<void>('compute_weekly_performance', params: {
        'p_week_start': weekStartIso,
      });
      debugPrint('✅ Weekly performance recomputed for week starting $weekStartIso');
    } catch (e) {
      // Non-fatal: UI will still reflect attendance; leaderboard may refresh later.
      debugPrint('⚠️ Failed to recompute weekly performance: $e');
    }

    return record;
  }

  Future<List<AttendanceRecord>> fetchForSessionDate({
    required int sessionId,
    required DateTime date,
  }) async {
    final iso = date.toIso8601String().substring(0, 10);
    final res = await _client
        .from('attendance')
        .select()
        .eq('session_id', sessionId)
        .eq('date', iso);
    return (res as List<dynamic>)
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch attendance history for the current user with optional filters
  Future<List<AttendanceRecord>> fetchUserAttendance({
    String? userId,
    int? sessionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Use current user if userId not specified
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) throw Exception('No user logged in');

    var query = _client.from('attendance').select().eq('user_id', uid);

    if (sessionId != null) {
      query = query.eq('session_id', sessionId);
    }

    if (startDate != null) {
      final isoStart = startDate.toIso8601String().substring(0, 10);
      query = query.gte('date', isoStart);
    }

    if (endDate != null) {
      final isoEnd = endDate.toIso8601String().substring(0, 10);
      query = query.lte('date', isoEnd);
    }

    final res = await query.order('date', ascending: false);
    return (res as List<dynamic>)
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get attendance statistics for a user
  Future<Map<String, dynamic>> getUserAttendanceStats({String? userId}) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) throw Exception('No user logged in');

    final records = await fetchUserAttendance(userId: uid);
    final presentCount = records.where((r) => r.status == 'present').length;
    final absentCount = records.where((r) => r.status == 'absent').length;
    final total = records.length;

    return {
      'total': total,
      'present': presentCount,
      'absent': absentCount,
      'attendanceRate': total > 0 ? (presentCount / total * 100).toStringAsFixed(1) : '0.0',
    };
  }
}
