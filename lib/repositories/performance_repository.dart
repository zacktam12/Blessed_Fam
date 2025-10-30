import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/supabase_provider.dart';
import '../models/performance.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  return PerformanceRepository(ref);
});

class PerformanceRepository {
  PerformanceRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseProvider);

  Future<List<PerformanceWeekly>> fetchWeek(
      {required DateTime weekStart}) async {
    final isoDate = weekStart.toIso8601String().substring(0, 10);
    // Order by total_score descending to get highest scores first
    final res = await _client
        .from('performance')
        .select()
        .eq('week_start_date', isoDate)
        .order('total_score', ascending: false);
    return (res as List<dynamic>)
        .map((e) => PerformanceWeekly.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> computeWeek({required DateTime weekStart}) async {
    final isoDate = weekStart.toIso8601String().substring(0, 10);
    await _client.rpc<void>('compute_weekly_performance', params: {
      'p_week_start': isoDate,
    });
  }
}
