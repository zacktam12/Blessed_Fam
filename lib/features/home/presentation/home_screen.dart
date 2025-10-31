import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/utils/connectivity_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../repositories/performance_repository.dart';
import '../../../models/performance.dart';
import '../../../repositories/user_repository.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/announcements_repository.dart';
import '../../../models/announcement.dart';
import '../../../core/utils/flash.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(currentSessionProvider);
    ref.watch(currentUserProfileProvider);
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    final isOffline = connectivityStatus.value == false;

    final tabs = [
      _HomeTab(onSwitchToLeaderboard: () => setState(() => _index = 1)),
      const _LeaderboardTab(),
      const _AnnouncementsTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlessedFam'),
        actions: [
          // Theme toggle button
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
          ),
          // Sign out button
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                // Sign out from Supabase
                await ref.read(authRepositoryProvider).signOut();

                // Clear all cached providers
                ref.invalidate(currentSessionProvider);
                ref.invalidate(currentUserProfileProvider);
                ref.invalidate(isAdminProvider);

                // Force auth state change
                final notifier = ref.read(authStateListenableProvider);
                notifier.value++;

                // Navigate to login
                if (mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  showTopError(context, 'Sign out failed: $e');
                }
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineIndicator(isOffline: isOffline),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: tabs[_index],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ranks',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Word',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.onSwitchToLeaderboard});

  final VoidCallback onSwitchToLeaderboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Create User',
                  subtitle: 'Add new members or admins to the system.',
                  icon: Icons.person_add,
                  onTap: () => context.push('/admin/create-user'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Admin Attendance',
                  subtitle: 'Check-in participants and record server time.',
                  icon: Icons.fact_check,
                  onTap: () => context.push('/admin/attendance'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Analytics Dashboard',
                  subtitle:
                      'View statistics, trends, and export attendance data.',
                  icon: Icons.analytics,
                  onTap: () => context.push('/admin/analytics'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Post Announcement',
                  subtitle:
                      'Share scripture or encouragement with a push notification.',
                  icon: Icons.campaign,
                  onTap: () => context.push('/admin/announce'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Manage Sessions',
                  subtitle:
                      'Configure session times and time-tracking settings.',
                  icon: Icons.settings,
                  onTap: () => context.push('/admin/manage-sessions'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        // Only show "My Attendance" for non-admin members
        isAdminAsync.when(
          data: (isAdmin) => !isAdmin
              ? _HeroCard(
                  title: 'My Attendance',
                  subtitle: 'View your attendance history and track your consistency.',
                  icon: Icons.calendar_month,
                  onTap: () => context.push('/my-attendance'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: 'Weekly Winner',
          subtitle:
              'Celebrate the most consistent saint this week. Tap to view rankings.',
          icon: Icons.celebration,
          onTap: onSwitchToLeaderboard,
        ),
      ],
    );
  }
}

class _LeaderboardTab extends ConsumerStatefulWidget {
  const _LeaderboardTab();

  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _refreshLeaderboard() async {
    setState(() => _refreshKey++);
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  DateTime _weekStart(DateTime d) {
    final monday = d.subtract(
      Duration(days: (d.weekday - DateTime.monday) % 7),
    );
    return DateTime(monday.year, monday.month, monday.day);
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekStart(DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;

    // Combined future: fetch weekly performance snapshot, then batch-fetch user profiles
    final combined = Future(() async {
      // ALWAYS recompute to ensure fresh data based on current attendance
      try {
        await ref
            .read(performanceRepositoryProvider)
            .computeWeek(weekStart: week);
        debugPrint('✅ Successfully computed weekly performance');
      } catch (e) {
        debugPrint('❌ Error computing weekly performance: $e');
        // Rethrow to see the actual error in UI if needed
        rethrow;
      }
      
      // Fetch performance data for the week (now guaranteed to be fresh)
      List<PerformanceWeekly> perf = await ref
          .read(performanceRepositoryProvider)
          .fetchWeek(weekStart: week);
      debugPrint('📊 Fetched ${perf.length} performance records from database');
      
      // Merge with ONLY members (excludes admins) to include zero-point users
      final List<UserProfile> members =
          await ref.read(userRepositoryProvider).listMembers();
      debugPrint('👥 Found ${members.length} members (admins excluded)');
      final Map<String, UserProfile> byId = {for (var u in members) u.id: u};
      final Set<String> scoredIds = perf.map((e) => e.userId).toSet();
      final List<PerformanceWeekly> merged = [
        ...perf,
        for (final u in members)
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
    });

    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_refreshKey),
      future: combined,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load leaderboard: ${snapshot.error}'),
          );
        }
        final data = snapshot.data?['perf'] as List<PerformanceWeekly>? ??
            <PerformanceWeekly>[];
        final users = snapshot.data?['users'] as Map<String, UserProfile>? ??
            <String, UserProfile>{};
        if (data.isEmpty) {
          return const Center(
            child: Text('No scores yet. Encourage the saints!'),
          );
        }

        // Get winner - data is sorted by total_score DESC, so first is highest
        final winner = data.first;
        final winnerProfile = users[winner.userId];
        final winnerName = (winnerProfile?.name?.isNotEmpty ?? false)
            ? winnerProfile!.name!
            : (winnerProfile?.email ?? winner.userId.substring(0, 6));

        return RefreshIndicator(
          onRefresh: _refreshLeaderboard,
          child: CustomScrollView(
            slivers: [
            // Winner Celebration Header
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade300,
                              Colors.amber.shade600,
                              Colors.amber.shade300,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 220),
                                    child: const Text(
                                      'WEEKLY CHAMPION',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.emoji_events,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (winnerProfile?.profilePictureUrl != null)
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.amber.shade900,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: CachedNetworkImageProvider(
                                    winnerProfile!.profilePictureUrl!,
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.amber.shade900,
                                    width: 4,
                                  ),
                                  color: Colors.amber.shade100,
                                ),
                                child: const CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.transparent,
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              winnerName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade900,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${winner.totalScore} Points',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '🎉 Most Consistent This Week! 🎉',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Leaderboard Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Full Rankings',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Rankings List
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final PerformanceWeekly p = data[i];
                final rank = p.rank ?? i + 1;
                final profile = users[p.userId];
                final displayName = (profile?.name?.isNotEmpty ?? false)
                    ? profile!.name!
                    : (profile?.email ?? p.userId.substring(0, 6));
                final avatar = profile?.profilePictureUrl;
                final isWinner = rank == 1;
                final isTopThree = rank <= 3;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isWinner
                        ? Colors.amber.shade50
                        : isTopThree
                            ? colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                    borderRadius: BorderRadius.circular(12),
                    border: isWinner
                        ? Border.all(color: Colors.amber, width: 2)
                        : isTopThree
                            ? Border.all(
                                color: colorScheme.primary.withOpacity(0.3),
                              )
                            : null,
                  ),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        avatar == null || avatar.isEmpty
                            ? CircleAvatar(
                                backgroundColor:
                                    isTopThree ? _getMedalColor(rank) : null,
                                child: isTopThree
                                    ? Icon(
                                        _getMedalIcon(rank),
                                        color: Colors.white,
                                      )
                                    : Text('$rank'),
                              )
                            : CircleAvatar(
                                backgroundImage: CachedNetworkImageProvider(
                                  avatar,
                                ),
                              ),
                        if (isTopThree)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _getMedalColor(rank),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getMedalIcon(rank),
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: isWinner
                            ? FontWeight.w900
                            : isTopThree
                                ? FontWeight.w700
                                : FontWeight.normal,
                        color: (isWinner || isTopThree)
                            ? Colors.black87
                            : colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Total score: ${p.totalScore}',
                      style: TextStyle(
                        color: (isWinner || isTopThree)
                            ? Colors.black54
                            : colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    trailing: isWinner
                        ? const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 32,
                          )
                        : isTopThree
                            ? Chip(
                                label: Text(
                                  '#$rank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: _getMedalColor(rank),
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                              )
                            : Text(
                                '#$rank',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                  ),
                );
              }, childCount: data.length),
            ),
          ],
          ),
        );
      },
    );
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600; // Gold
      case 2:
        return Colors.grey.shade400; // Silver
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.grey;
    }
  }

  IconData _getMedalIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.military_tech;
      case 3:
        return Icons.workspace_premium;
      default:
        return Icons.circle;
    }
  }
}

class _AnnouncementsTab extends ConsumerWidget {
  const _AnnouncementsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Treat the "Word" tab as a quick place to surface the latest announcement
    // (e.g. scripture / word of encouragement). If none exist, show a built-in
    // fallback verse.
    return FutureBuilder<List<Announcement>>(
      future: ref.read(announcementsRepositoryProvider).fetchLatest(limit: 1),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load word: ${snapshot.error}'));
        }
        final list = snapshot.data ?? <Announcement>[];
        if (list.isEmpty) {
          // Fallback: a small curated list of short verses
          final verses = [
            'Philippians 4:13 — I can do all things through Christ who strengthens me.',
            'Psalm 23:1 — The Lord is my shepherd; I shall not want.',
            'Jeremiah 29:11 — For I know the plans I have for you, declares the Lord.',
          ];
          final idx =
              DateTime.now().difference(DateTime(2020)).inDays % verses.length;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Word of the Day',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      verses[idx],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final Announcement a = list.first;
        final title = a.title;
        final message = a.message;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(message, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: profileAsync.when(
        data: (p) {
          final name = p?.name ?? 'Anonymous';
          final email = p?.email ?? 'Guest';
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AvatarImage(radius: 36),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => const _EditProfileSheet(),
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit profile'),
                ),
              ),
              const SizedBox(height: 24),
              // Theme Settings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Appearance',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Consumer(
                        builder: (context, ref, _) {
                          final themeMode = ref.watch(themeModeProvider);
                          final isDark = themeMode == ThemeMode.dark;

                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Dark Mode'),
                            subtitle: Text(isDark
                                ? 'Dark theme enabled'
                                : 'Light theme enabled'),
                            secondary: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            value: isDark,
                            onChanged: (value) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .toggleTheme();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [scheme.primaryContainer, scheme.secondaryContainer],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _showPasswordFields = false;
  bool _showEmailField = false;

  @override
  void initState() {
    super.initState();
    ref.read(currentUserProfileProvider.future).then((p) {
      if (p != null) {
        _name.text = p.name ?? '';
        _email.text = p.email;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      // Lazy import to keep scope simple
      // ignore: depend_on_referenced_packages
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 82,
      );
      
      if (img == null) {
        debugPrint('📷 Image picker cancelled by user');
        return;
      }

      debugPrint('📷 Image selected: ${img.path}');
      setState(() => _saving = true);
      
      final client = ref.read(supabaseProvider);
      final uid = client.auth.currentUser!.id;
      
      // Read image bytes
      final bytes = await img.readAsBytes();
      debugPrint('📷 Image size: ${bytes.length} bytes');
      
      // Upload to storage with timestamp to avoid cache issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'avatars/$uid-$timestamp.jpg';
      
      debugPrint('📷 Uploading to: $path');
      await client.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );
      
      // Get public URL with cache buster
      final url = client.storage.from('avatars').getPublicUrl(path);
      debugPrint('📷 Public URL: $url');
      
      // Update users table
      await client
          .from('users')
          .update({'profile_picture_url': url}).eq('id', uid);
      
      debugPrint('📷 Database updated');

      // Invalidate profile to refresh UI
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        showTopSuccess(context, 'Profile picture updated successfully!');
        // Don't close modal immediately - let user see the success
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Avatar upload error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMsg = 'Failed to update profile picture.';
        
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('storage') || errorStr.contains('bucket')) {
          errorMsg = 'Storage error. Please ensure the avatars bucket exists in Supabase.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          errorMsg = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('permission') || errorStr.contains('policy')) {
          errorMsg = 'Permission denied. Please check storage policies.';
        }
        
        showTopError(context, errorMsg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeEmail() async {
    final newEmail = _email.text.trim();

    // Validation
    if (newEmail.isEmpty) {
      showTopError(context, 'Email cannot be empty');
      return;
    }

    if (!newEmail.contains('@')) {
      showTopError(context, 'Please enter a valid email address');
      return;
    }

    // Get current email to check if it's actually changing
    final client = ref.read(supabaseProvider);
    final currentEmail = client.auth.currentUser?.email;
    
    if (currentEmail == newEmail) {
      showTopError(context, 'This is already your current email');
      return;
    }

    setState(() => _saving = true);
    try {
      // Update email in Supabase Auth
      // Note: This sends a confirmation email to the NEW address
      await client.auth.updateUser(UserAttributes(email: newEmail));

      // DO NOT update users table yet - it will be updated automatically
      // when the user confirms the new email via the confirmation link
      // This prevents login issues

      // Invalidate profile to refresh UI
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        // Show detailed instructions
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify Your Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A confirmation email has been sent to:'),
                const SizedBox(height: 8),
                Text(
                  newEmail,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Please check your inbox and click the confirmation link.'),
                const SizedBox(height: 8),
                const Text(
                  'Important: Continue using your old email to login until you confirm the new one.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Close edit profile modal too
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Email update error: $e');
      if (mounted) {
        String errorMsg = 'Failed to update email';
        
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('same')) {
          errorMsg = 'This is already your current email';
        } else if (errorStr.contains('invalid')) {
          errorMsg = 'Invalid email format';
        } else if (errorStr.contains('rate')) {
          errorMsg = 'Too many requests. Please try again later.';
        }
        
        showTopError(context, errorMsg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPassword.text.trim();
    final confirmPassword = _confirmPassword.text.trim();

    // Validation
    if (newPassword.isEmpty) {
      showTopError(context, 'New password cannot be empty');
      return;
    }

    if (newPassword.length < 6) {
      showTopError(context, 'Password must be at least 6 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      showTopError(context, 'Passwords do not match');
      return;
    }

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      await client.auth.updateUser(UserAttributes(password: newPassword));

      if (mounted) {
        showTopSuccess(context, 'Password updated successfully');
        _newPassword.clear();
        _confirmPassword.clear();
        setState(() => _showPasswordFields = false);
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Failed to update password: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();

    // Validation
    if (name.isEmpty) {
      showTopError(context, 'Display name cannot be empty');
      return;
    }

    if (name.length < 2) {
      showTopError(context, 'Display name must be at least 2 characters');
      return;
    }

    if (name.length > 50) {
      showTopError(context, 'Display name must be less than 50 characters');
      return;
    }

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final uid = client.auth.currentUser!.id;
      await client.from('users').update({'name': name}).eq('id', uid);

      // Invalidate profile to refresh UI
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        showTopSuccess(context, 'Profile updated successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('network')
            ? 'Network error. Please check your connection.'
            : 'Failed to update profile. Please try again.';
        showTopError(context, errorMsg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                
                // Profile Picture - Clickable
                Center(
                  child: GestureDetector(
                    onTap: _saving ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        const _AvatarImage(radius: 50),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to change profile picture',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Display Name
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Email Section
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Email Address',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _showEmailField = !_showEmailField);
                      },
                      child: Text(_showEmailField ? 'Cancel' : 'Change'),
                    ),
                  ],
                ),
                if (_showEmailField) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'New email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _changeEmail,
                      icon: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Update Email'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                
                // Password Section
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Password',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _showPasswordFields = !_showPasswordFields);
                      },
                      child: Text(_showPasswordFields ? 'Cancel' : 'Change'),
                    ),
                  ],
                ),
                if (_showPasswordFields) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPassword,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _changePassword,
                      icon: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Update Password'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Update Profile Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveName,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Update Profile'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarImage extends ConsumerWidget {
  const _AvatarImage({required this.radius});
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final url = profile?.profilePictureUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: const Icon(Icons.person, size: 36),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(url),
    );
  }
}
