import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref);
});

class AnalyticsRepository {
  AnalyticsRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  /// Get overall statistics
  Future<Map<String, dynamic>> getOverallStats() async {
    // Get total members
    final usersResponse = await _client.from('users').select('id').count();
    final totalMembers = usersResponse.count;

    // Get total sessions
    final sessionsResponse = await _client.from('sessions').select('id').count();
    final totalSessions = sessionsResponse.count;

    // Get total attendance records
    final attendanceResponse = await _client.from('attendance').select('id').count();
    final totalRecords = attendanceResponse.count;

    // Get present count
    final presentResponse = await _client
        .from('attendance')
        .select('id')
        .eq('status', 'present')
        .count();
    final presentCount = presentResponse.count;

    // Calculate attendance rate
    final attendanceRate = totalRecords > 0 
        ? (presentCount / totalRecords * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'totalMembers': totalMembers,
      'totalSessions': totalSessions,
      'totalRecords': totalRecords,
      'presentCount': presentCount,
      'attendanceRate': attendanceRate,
    };
  }

  /// Get attendance statistics per session
  Future<List<Map<String, dynamic>>> getSessionStats() async {
    // Fetch all sessions
    final sessionsResponse = await _client
        .from('sessions')
        .select('id, name, weight')
        .order('name');
    
    final sessions = List<Map<String, dynamic>>.from(sessionsResponse as List);
    final stats = <Map<String, dynamic>>[];
    
    // For each session, count attendance records
    for (final session in sessions) {
      final sessionId = session['id'];
      
      // Get all attendance records for this session
      final attendanceResponse = await _client
          .from('attendance')
          .select('status')
          .eq('session_id', sessionId);
      
      final records = List<Map<String, dynamic>>.from(attendanceResponse as List);
      final totalRecords = records.length;
      final presentCount = records.where((r) => r['status'] == 'present').length;
      final absentCount = records.where((r) => r['status'] == 'absent').length;
      
      stats.add({
        'id': sessionId,
        'name': session['name'],
        'weight': session['weight'],
        'total_records': totalRecords,
        'present_count': presentCount,
        'absent_count': absentCount,
      });
    }
    
    return stats;
  }

  /// Get weekly attendance trends (last 8 weeks)
  Future<List<Map<String, dynamic>>> getWeeklyTrends() async {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 56)); // 8 weeks ago
    
    final response = await _client
        .from('attendance')
        .select('date, status')
        .gte('date', startDate.toIso8601String().substring(0, 10))
        .order('date');

    final records = List<Map<String, dynamic>>.from(response as List);
    
    // Group by week
    final weeklyData = <String, Map<String, int>>{};
    
    for (final record in records) {
      final date = DateTime.parse(record['date'] as String);
      final weekStart = _getWeekStart(date);
      final weekKey = weekStart.toIso8601String().substring(0, 10);
      
      if (!weeklyData.containsKey(weekKey)) {
        weeklyData[weekKey] = {'present': 0, 'absent': 0, 'total': 0};
      }
      
      weeklyData[weekKey]!['total'] = weeklyData[weekKey]!['total']! + 1;
      if (record['status'] == 'present') {
        weeklyData[weekKey]!['present'] = weeklyData[weekKey]!['present']! + 1;
      } else {
        weeklyData[weekKey]!['absent'] = weeklyData[weekKey]!['absent']! + 1;
      }
    }
    
    // Convert to list format
    final trends = weeklyData.entries.map((entry) {
      final present = entry.value['present']!;
      final total = entry.value['total']!;
      final rate = total > 0 ? (present / total * 100).round() : 0;
      
      return {
        'week': entry.key,
        'present': present,
        'absent': entry.value['absent'],
        'total': total,
        'rate': rate,
      };
    }).toList();
    
    trends.sort((a, b) => (a['week'] as String).compareTo(b['week'] as String));
    
    return trends;
  }

  /// Get individual member participation rates
  Future<List<Map<String, dynamic>>> getMemberParticipation() async {
    // Get members only (exclude admins)
    final usersResponse = await _client
        .from('users')
        .select('id, name, email')
        .eq('role', 'member')
        .order('name');
    
    final users = List<Map<String, dynamic>>.from(usersResponse as List);
    
    // Get attendance for each user
    final participation = <Map<String, dynamic>>[];
    
    for (final user in users) {
      final userId = user['id'] as String;
      
      final attendanceResponse = await _client
          .from('attendance')
          .select('status')
          .eq('user_id', userId);
      
      final records = List<Map<String, dynamic>>.from(attendanceResponse as List);
      final total = records.length;
      final present = records.where((r) => r['status'] == 'present').length;
      final rate = total > 0 ? (present / total * 100).round() : 0;
      
      participation.add({
        'userId': userId,
        'name': user['name'] ?? user['email'],
        'email': user['email'],
        'total': total,
        'present': present,
        'absent': total - present,
        'rate': rate,
      });
    }
    
    // Sort by participation rate descending
    participation.sort((a, b) => (b['rate'] as int).compareTo(a['rate'] as int));
    
    return participation;
  }

  /// Get recent attendance activity (last 30 days)
  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final response = await _client
        .from('attendance')
        .select('*, users!inner(name, email), sessions!inner(name)')
        .gte('date', thirtyDaysAgo.toIso8601String().substring(0, 10))
        .order('date', ascending: false)
        .limit(50);
    
    return List<Map<String, dynamic>>.from(response as List);
  }

  DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: (date.weekday - DateTime.monday) % 7));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Generate CSV export of attendance data
  Future<String> generateCSVExport() async {
    final response = await _client
        .from('attendance')
        .select('*, users!inner(name, email), sessions!inner(name)')
        .order('date', ascending: false);
    
    final records = List<Map<String, dynamic>>.from(response as List);
    
    final csv = StringBuffer();
    csv.writeln('Date,User Name,User Email,Session,Status,Arrival Time');
    
    for (final record in records) {
      final user = record['users'] as Map<String, dynamic>;
      final session = record['sessions'] as Map<String, dynamic>;
      final arrivalTime = record['arrival_time'] != null 
          ? (record['arrival_time'] as String).substring(11, 16) 
          : '';
      
      csv.writeln([
        record['date'],
        user['name'] ?? '',
        user['email'],
        session['name'],
        record['status'],
        arrivalTime,
      ].join(','));
    }
    
    return csv.toString();
  }
}
