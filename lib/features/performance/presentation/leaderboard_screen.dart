import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../repositories/performance_repository.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  DateTime _weekStart(DateTime d) {
    final monday = d.subtract(Duration(days: (d.weekday - DateTime.monday) % 7));
    return DateTime(monday.year, monday.month, monday.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = _weekStart(DateTime.now());
    final label = DateFormat('MMM d').format(week);
    return Scaffold(
      appBar: AppBar(title: Text('Weekly Leaderboard · $label')),
      body: FutureBuilder(
        future: ref.read(performanceRepositoryProvider).fetchWeek(weekStart: week),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const _EmptyState(message: 'No scores yet. Encourage the saints!');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (c, i) {
              final p = data[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${p.rank ?? i + 1}')),
                title: Text('User ${p.userId.substring(0, 6)}…'),
                subtitle: Text('Total score: ${p.totalScore}'),
              );
            },
            separatorBuilder: (c, i) => const Divider(height: 0),
            itemCount: data.length,
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

