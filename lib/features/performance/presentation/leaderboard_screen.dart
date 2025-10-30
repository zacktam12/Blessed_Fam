import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../repositories/performance_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../models/user_profile.dart';
import '../../../models/performance.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  DateTime _weekStart(DateTime d) {
    final monday = d.subtract(
      Duration(days: (d.weekday - DateTime.monday) % 7),
    );
    return DateTime(monday.year, monday.month, monday.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = _weekStart(DateTime.now());
    final label = DateFormat('MMM d').format(week);
    return Scaffold(
      appBar: AppBar(title: Text('Weekly Leaderboard · $label')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: () async {
          var data = await ref
              .read(performanceRepositoryProvider)
              .fetchWeek(weekStart: week);
          if (data.isEmpty) {
            try {
              await ref
                  .read(performanceRepositoryProvider)
                  .computeWeek(weekStart: week);
              data = await ref
                  .read(performanceRepositoryProvider)
                  .fetchWeek(weekStart: week);
            } catch (_) {
              // swallow; UI will show error/empty
            }
          }
          // Merge with all users to include zero-point users
          final List<UserProfile> allUsers = await ref
              .read(userRepositoryProvider)
              .listAllUsers();
          final Map<String, UserProfile> byId = {
            for (var u in allUsers) u.id: u,
          };
          final Set<String> scoredIds = data.map((e) => e.userId).toSet();
          final List<PerformanceWeekly> merged = [
            ...data,
            for (final u in allUsers)
              if (!scoredIds.contains(u.id))
                PerformanceWeekly(
                  id: 0,
                  userId: u.id,
                  weekStartDate: week,
                  totalScore: 0,
                ),
          ];
          // Sort highest first
          merged.sort((a, b) => b.totalScore.compareTo(a.totalScore));
          return {'perf': merged, 'users': byId};
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data?['perf'] as List? ?? [];
          final users =
              snapshot.data?['users'] as Map<String, UserProfile>? ?? {};
          if (data.isEmpty) {
            return const _EmptyState(
              message: 'No scores yet. Encourage the saints!',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (c, i) {
              final p = data[i];
              final rank = p.rank ?? i + 1;
              final profile = users[p.userId];
              final displayName = (profile?.name?.isNotEmpty ?? false)
                  ? profile!.name!
                  : (profile?.email ?? p.userId.substring(0, 6));
              final avatar = profile?.profilePictureUrl;
              return ListTile(
                leading: avatar == null || avatar.isEmpty
                    ? CircleAvatar(child: Text('$rank'))
                    : CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(avatar),
                      ),
                title: Text(displayName),
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
