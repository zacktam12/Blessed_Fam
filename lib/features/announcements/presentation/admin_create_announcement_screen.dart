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
    final title = _title.text.trim();
    final message = _message.text.trim();
    
    // Validation
    if (title.isEmpty) {
      showTopError(context, 'Title is required');
      return;
    }
    
    if (title.length < 3) {
      showTopError(context, 'Title must be at least 3 characters');
      return;
    }
    
    if (message.isEmpty) {
      showTopError(context, 'Message is required');
      return;
    }
    
    if (message.length < 10) {
      showTopError(context, 'Message must be at least 10 characters');
      return;
    }
    
    setState(() => _saving = true);
    try {
      await ref.read(announcementsRepositoryProvider).createAnnouncement(
            title: title,
            message: message,
            notify: _notify,
          );
      if (mounted) {
        // Refresh announcements list on return
        ref.invalidate(announcementsListProvider(20));
        showTopSuccess(context, 'Announcement published successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('network')
            ? 'Network error. Please check your connection.'
            : 'Failed to publish announcement. Please try again.';
        showTopError(context, errorMsg);
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


