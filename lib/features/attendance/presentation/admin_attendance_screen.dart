import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../repositories/sessions_repository.dart';
import 'session_checkin_screen.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  DateTime _date = DateTime.now();

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

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d').format(_date);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Attendance')),
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
                const Expanded(
                  child: Text('Pick a session then tap a member to check-in.'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: ref.read(sessionsRepositoryProvider).fetchSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final sessions = snapshot.data ?? [];
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (c, i) {
                    final s = sessions[i];
                    final startTimeStr = s.startTime != null 
                        ? ' • ${s.startTime!.format(context)}'
                        : '';
                    return ListTile(
                      title: Text(s.name),
                      subtitle: Text('Weight ${s.weight} • ${s.trackTime ? 'Time-tracked' : 'Attendance only'}$startTimeStr'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SessionCheckinScreen(
                              sessionId: s.id,
                              sessionName: s.name,
                              trackTime: s.trackTime,
                              initialDate: _date,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (c, i) => const Divider(height: 0),
                  itemCount: sessions.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


