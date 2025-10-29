import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/user_profile.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../core/utils/flash.dart';

class SessionCheckinScreen extends ConsumerStatefulWidget {
  const SessionCheckinScreen({super.key, required this.sessionId, required this.sessionName, required this.trackTime});
  final int sessionId;
  final String sessionName;
  final bool trackTime;

  @override
  ConsumerState<SessionCheckinScreen> createState() => _SessionCheckinScreenState();
}

class _SessionCheckinScreenState extends ConsumerState<SessionCheckinScreen> {
  DateTime _date = DateTime.now();
  final Set<String> _loadingUserIds = {};

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _checkIn(UserProfile user) async {
    setState(() => _loadingUserIds.add(user.id));
    try {
      await ref.read(attendanceRepositoryProvider).checkIn(
            userId: user.id,
            sessionId: widget.sessionId,
            date: _date,
          );
      if (mounted) {
        showTopSuccess(context, 'Checked in ${user.name ?? user.email}');
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Check-in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingUserIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d').format(_date);
    return Scaffold(
      appBar: AppBar(title: Text('Check-in · ${widget.sessionName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dateLabel),
                ),
                const SizedBox(width: 12),
                if (widget.trackTime)
                  const Chip(label: Text('Time-tracked'))
                else
                  const Chip(label: Text('Attendance only')),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: ref.read(userRepositoryProvider).listAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) return const Center(child: Text('No participants'));
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (c, i) {
                    final u = users[i];
                    final busy = _loadingUserIds.contains(u.id);
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(u.name ?? u.email),
                      subtitle: Text(u.email),
                      trailing: FilledButton.icon(
                        onPressed: busy ? null : () => _checkIn(u),
                        icon: busy
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: const Text('Present'),
                      ),
                    );
                  },
                  separatorBuilder: (c, i) => const Divider(height: 0),
                  itemCount: users.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


