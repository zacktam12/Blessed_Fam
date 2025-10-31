import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/announcements_repository.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../models/announcement.dart';
import 'admin_edit_announcement_screen.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final session = ref.watch(currentSessionProvider);
    final currentUserId = session?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: Consumer(
        builder: (context, ref2, _) {
          final listAsync = ref2.watch(announcementsListProvider(20));
          return listAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return const _EmptyState(message: 'No announcements yet');
              }
              return isAdminAsync.when(
                data: (isAdmin) => ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (c, i) {
                    final a = data[i];
                    return _AnnouncementCard(
                      announcement: a,
                      canEdit: isAdmin || (currentUserId != null && a.postedBy == currentUserId),
                      onEdit: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (_) =>
                                AdminEditAnnouncementScreen(announcement: a),
                          ),
                        );
                        if (result == true) {
                          ref2.invalidate(announcementsListProvider(20));
                        }
                      },
                    );
                  },
                  separatorBuilder: (c, i) => const SizedBox(height: 4),
                  itemCount: data.length,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error loading admin status: $e')),
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

class _AnnouncementCard extends StatefulWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canEdit,
    required this.onEdit,
  });

  final Announcement announcement;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final textStyle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );

    // Check if text is long (more than 200 characters or 4 lines approximately)
    final isLongText = a.message.length > 200;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Edit Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit/Delete',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: widget.onEdit,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Message Content
            if (_isExpanded && isLongText)
              // Scrollable container when expanded
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Text(a.message, style: textStyle),
                ),
              )
            else
              // Normal text with max lines
              Text(
                a.message,
                style: textStyle,
                maxLines: _isExpanded ? null : 4,
                overflow:
                    _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),

            // View More/Less Button
            if (isLongText)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isExpanded ? 'View Less' : 'View More'),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
