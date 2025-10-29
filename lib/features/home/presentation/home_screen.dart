import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/supabase_provider.dart';
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
    final tabs = [
      const _HomeTab(),
      const _LeaderboardTab(),
      const _AnnouncementsTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlessedFam'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: tabs[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Ranks'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Word'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Admin Attendance',
                  subtitle: 'Check-in participants and record server time.',
                  icon: Icons.fact_check,
                  onTap: () => context.push('/admin/attendance'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        isAdminAsync.when(
          data: (isAdmin) => isAdmin
              ? _HeroCard(
                  title: 'Post Announcement',
                  subtitle: 'Share scripture or encouragement with a push notification.',
                  icon: Icons.campaign,
                  onTap: () => context.push('/admin/announce'),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        _HeroCard(
          title: 'Weekly Winner',
          subtitle: 'Celebrate the most consistent saint this week.',
          icon: Icons.celebration,
          onTap: () => context.push('/leaderboard'),
        ),
      ],
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  DateTime _weekStart(DateTime d) {
    final monday = d.subtract(Duration(days: (d.weekday - DateTime.monday) % 7));
    return DateTime(monday.year, monday.month, monday.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = _weekStart(DateTime.now());

    // Combined future: fetch weekly performance snapshot, then batch-fetch user profiles
    final combined = Future(() async {
      final List<PerformanceWeekly> perf = await ref.read(performanceRepositoryProvider).fetchWeek(weekStart: week);
      final ids = perf.map((e) => e.userId).toSet().toList();
      final List<UserProfile> users = ids.isEmpty ? <UserProfile>[] : await ref.read(userRepositoryProvider).fetchUsersByIds(ids);
      final Map<String, UserProfile> byId = {for (var u in users) u.id: u};
      return {'perf': perf, 'users': byId};
    });

    return FutureBuilder<Map<String, dynamic>>(
      future: combined,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load leaderboard: ${snapshot.error}'));
        }
        final data = snapshot.data?['perf'] as List<PerformanceWeekly>? ?? <PerformanceWeekly>[];
        final users = snapshot.data?['users'] as Map<String, UserProfile>? ?? <String, UserProfile>{};
        if (data.isEmpty) {
          return const Center(child: Text('No scores yet. Encourage the saints!'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: data.length,
          separatorBuilder: (c, i) => const Divider(height: 0),
          itemBuilder: (c, i) {
            final PerformanceWeekly p = data[i];
            final rank = p.rank ?? i + 1;
            final profile = users[p.userId];
            final displayName = (profile?.name?.isNotEmpty ?? false) ? profile!.name! : (profile?.email ?? p.userId.substring(0, 6));
            final avatar = profile?.profilePictureUrl;
            return ListTile(
              leading: avatar == null || avatar.isEmpty
                  ? CircleAvatar(child: Text('$rank'))
                  : CircleAvatar(backgroundImage: CachedNetworkImageProvider(avatar), child: Text('$rank')),
              title: Text(displayName),
              subtitle: Text('Total score: ${p.totalScore}'),
            );
          },
        );
      },
    );
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
          final idx = DateTime.now().difference(DateTime(2020)).inDays % verses.length;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Word of the Day', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(verses[idx], style: Theme.of(context).textTheme.bodyLarge),
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => const _EditProfileSheet(),
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit profile'),
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
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(currentUserProfileProvider.future).then((p) {
      if (p != null) _name.text = p.name ?? '';
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    // Lazy import to keep scope simple
    // ignore: depend_on_referenced_packages
    final picker = await Future.sync(() => ImagePicker());
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 82);
    if (img == null) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final uid = client.auth.currentUser!.id;
      final path = 'avatars/$uid.jpg';
      await client.storage.from('avatars').uploadBinary(
        path,
        await img.readAsBytes(),
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      final url = client.storage.from('avatars').getPublicUrl(path);
      await client.from('users').update({ 'profile_picture_url': url }).eq('id', uid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
  if (mounted) showTopError(context, 'Avatar upload failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final uid = client.auth.currentUser!.id;
      await client.from('users').update({ 'name': _name.text.trim() }).eq('id', uid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
  if (mounted) showTopError(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickAndUploadAvatar,
                      icon: const Icon(Icons.photo),
                      label: const Text('Change avatar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveName,
                      icon: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
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
      return CircleAvatar(radius: radius, child: const Icon(Icons.person, size: 36));
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(url),
    );
  }
}


