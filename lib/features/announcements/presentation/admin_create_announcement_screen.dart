import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/announcements_repository.dart';
import '../../../core/utils/flash.dart';

class AdminCreateAnnouncementScreen extends ConsumerStatefulWidget {
  const AdminCreateAnnouncementScreen({super.key});

  @override
  ConsumerState<AdminCreateAnnouncementScreen> createState() => _AdminCreateAnnouncementScreenState();
}

class _AdminCreateAnnouncementScreenState extends ConsumerState<AdminCreateAnnouncementScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _notify = true;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(announcementsRepositoryProvider).createAnnouncement(
            title: _title.text.trim(),
            message: _message.text.trim(),
            notify: _notify,
          );
      if (mounted) {
        showTopSuccess(context, 'Announcement published');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Publish failed: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Announcement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              decoration: const InputDecoration(labelText: 'Message'),
              minLines: 4,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              title: const Text('Send push notification'),
              subtitle: const Text('Notify all registered devices'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Publish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


