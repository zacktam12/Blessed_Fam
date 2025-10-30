import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/announcement.dart';
import '../../../repositories/announcements_repository.dart';
import '../../../core/utils/flash.dart';

class AdminEditAnnouncementScreen extends ConsumerStatefulWidget {
  const AdminEditAnnouncementScreen({
    super.key,
    required this.announcement,
  });

  final Announcement announcement;

  @override
  ConsumerState<AdminEditAnnouncementScreen> createState() =>
      _AdminEditAnnouncementScreenState();
}

class _AdminEditAnnouncementScreenState
    extends ConsumerState<AdminEditAnnouncementScreen> {
  late final TextEditingController _title;
  late final TextEditingController _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.announcement.title);
    _message = TextEditingController(text: widget.announcement.message);
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final message = _message.text.trim();

    if (title.isEmpty || message.isEmpty) {
      showTopError(context, 'Title and message cannot be empty');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(announcementsRepositoryProvider).updateAnnouncement(
            id: widget.announcement.id,
            title: title,
            message: message,
          );
      if (mounted) {
        // Invalidate the announcements list to refresh
        ref.invalidate(announcementsListProvider(20));
        showTopSuccess(context, 'Announcement updated');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Update failed: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text(
          'Are you sure you want to delete this announcement? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(announcementsRepositoryProvider)
          .deleteAnnouncement(id: widget.announcement.id);
      if (mounted) {
        // Invalidate the announcements list to refresh
        ref.invalidate(announcementsListProvider(20));
        showTopSuccess(context, 'Announcement deleted');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Delete failed: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Announcement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: _saving ? null : _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              minLines: 4,
              maxLines: 8,
              enabled: !_saving,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
