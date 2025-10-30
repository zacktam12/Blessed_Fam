import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/announcements_repository.dart';
import '../../../core/providers/auth_providers.dart';
import 'admin_edit_announcement_screen.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: Consumer(
        builder: (context, ref2, _) {
          final listAsync = ref2.watch(announcementsListProvider(20));
          return listAsync.when(
            data: (data) {
              if (data.isEmpty) return const _EmptyState(message: 'No announcements yet');
              return isAdminAsync.when(
                data: (isAdmin) => ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (c, i) {
                    final a = data[i];
                    return ListTile(
                      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(a.message),
                      leading: const Icon(Icons.menu_book),
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit',
                              onPressed: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute<bool>(
                                    builder: (_) => AdminEditAnnouncementScreen(announcement: a),
                                  ),
                                );
                                // Refresh the list if edit/delete was successful
                                if (result == true) {
                                  ref2.invalidate(announcementsListProvider);
                                }
                              },
                            )
                          : null,
                    );
                  },
                  separatorBuilder: (c, i) => const Divider(height: 0),
                  itemCount: data.length,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading admin status: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
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
          const Icon(Icons.inbox, size: 40),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

