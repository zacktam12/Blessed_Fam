import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../repositories/sessions_repository.dart';
import '../../../core/utils/flash.dart';

class ManageSessionsScreen extends ConsumerStatefulWidget {
  const ManageSessionsScreen({super.key});

  @override
  ConsumerState<ManageSessionsScreen> createState() => _ManageSessionsScreenState();
}

class _ManageSessionsScreenState extends ConsumerState<ManageSessionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Sessions'),
      ),
      body: FutureBuilder<List<SessionType>>(
        future: ref.read(sessionsRepositoryProvider).fetchSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const Center(child: Text('No sessions found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionCard(
                session: session,
                onUpdated: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({
    required this.session,
    required this.onUpdated,
  });

  final SessionType session;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  late TimeOfDay? _startTime;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.session.startTime;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _saveChanges() async {
    try {
      await ref.read(sessionsRepositoryProvider).updateSessionTime(
            sessionId: widget.session.id,
            startTime: _startTime,
          );
      if (mounted) {
        showTopSuccess(context, 'Session time updated successfully');
        setState(() => _isEditing = false);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Failed to update: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Weight: ${widget.session.weight} points',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    widget.session.trackTime ? 'Time Tracked' : 'No Time Tracking',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: widget.session.trackTime
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
            if (widget.session.trackTime) ...[
              const Divider(height: 24),
              if (!_isEditing) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Start Time: ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _startTime != null
                          ? _startTime!.format(context)
                          : 'Not set',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => setState(() => _isEditing = true),
                      tooltip: 'Edit time',
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    _startTime != null
                        ? 'Start Time: ${_startTime!.format(context)}'
                        : 'Set Start Time',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _startTime = widget.session.startTime;
                          _isEditing = false;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Scoring Rules:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ScoringRule(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      text: 'On time or early: +1 bonus point',
                    ),
                    _ScoringRule(
                      icon: Icons.access_time,
                      color: Colors.orange,
                      text: 'Within 10 min late: No bonus/penalty',
                    ),
                    _ScoringRule(
                      icon: Icons.cancel,
                      color: Colors.red,
                      text: 'More than 10 min late: -1 penalty',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoringRule extends StatelessWidget {
  const _ScoringRule({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
