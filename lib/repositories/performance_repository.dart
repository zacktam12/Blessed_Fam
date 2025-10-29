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

  Future<List<PerformanceWeekly>> fetchWeek({required DateTime weekStart}) async {
    final isoDate = weekStart.toIso8601String().substring(0, 10);
    final res = await _client.from('performance').select().eq('week_start_date', isoDate).order('rank');
    return (res as List<dynamic>)
        .map((e) => PerformanceWeekly.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

