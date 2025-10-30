import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/user_profile.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../core/utils/flash.dart';
import '../../../core/providers/supabase_provider.dart';

class SessionCheckinScreen extends ConsumerStatefulWidget {
  const SessionCheckinScreen({
    super.key, 
    required this.sessionId, 
    required this.sessionName, 
    required this.trackTime,
    this.initialDate,
  });
  final int sessionId;
  final String sessionName;
  final bool trackTime;
  final DateTime? initialDate;

  @override
  ConsumerState<SessionCheckinScreen> createState() => _SessionCheckinScreenState();
}

class _SessionCheckinScreenState extends ConsumerState<SessionCheckinScreen> {
  late DateTime _date;
  final Set<String> _loadingUserIds = {};
  final Map<String, String> _userAttendance = {}; // userId -> status (present/absent)
  bool _showOnlyUnmarked = false;
  RealtimeChannel? _realtimeChannel;
  bool _isRealtimeConnected = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    // Load existing attendance for the current date/session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChecked();
      _setupRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadChecked() async {
    try {
      final records = await ref.read(attendanceRepositoryProvider).fetchForSessionDate(sessionId: widget.sessionId, date: _date);
      if (mounted) {
        setState(() {
          _userAttendance.clear();
          for (var record in records) {
            _userAttendance[record.userId] = record.status;
          }
        });
      }
    } catch (_) {
      // ignore - UI will just show unchecked
    }
  }

  void _setupRealtimeSubscription() {
    try {
      final supabase = ref.read(supabaseProvider);
      
      // Unsubscribe from previous channel if exists
      _realtimeChannel?.unsubscribe();
      
      // Create a unique channel name for this session and date
      final isoDate = _date.toIso8601String().substring(0, 10);
      final channelName = 'attendance_${widget.sessionId}_$isoDate';
      
      _realtimeChannel = supabase
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'attendance',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: widget.sessionId,
            ),
            callback: (payload) {
              // Check if the change is for the current date
              final recordDate = payload.newRecord['date'] as String?;
              if (recordDate == isoDate) {
                _handleRealtimeUpdate(payload);
              }
            },
          )
          .subscribe(
            (status, error) {
              if (mounted) {
                setState(() {
                  _isRealtimeConnected = status == RealtimeSubscribeStatus.subscribed;
                });
                if (status == RealtimeSubscribeStatus.subscribed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.green.shade300),
                          const SizedBox(width: 8),
                          const Text('Live updates enabled'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          );
    } catch (e) {
      debugPrint('Realtime subscription error: $e');
    }
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    if (!mounted) return;

    final userId = payload.newRecord['user_id'] as String?;
    final status = payload.newRecord['status'] as String?;

    if (userId != null && status != null) {
      setState(() {
        if (payload.eventType == PostgresChangeEvent.delete) {
          _userAttendance.remove(userId);
        } else {
          _userAttendance[userId] = status;
        }
      });

      // Show a subtle notification for changes made by others
      if (!_loadingUserIds.contains(userId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == 'present' ? Icons.check_circle : Icons.cancel,
                  color: status == 'present' ? Colors.green.shade300 : Colors.red.shade300,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Attendance updated by another admin',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blue.shade800,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      // reload checked users for the new date and resubscribe to realtime
      await _loadChecked();
      _setupRealtimeSubscription();
    }
  }

  Future<void> _markAttendance(UserProfile user, String status) async {
    setState(() => _loadingUserIds.add(user.id));
    try {
      await ref.read(attendanceRepositoryProvider).checkIn(
            userId: user.id,
            sessionId: widget.sessionId,
            date: _date,
            status: status,
          );
      if (mounted) {
        setState(() {
          _userAttendance[user.id] = status;
        });
        final statusText = status == 'present' ? 'Present' : 'Absent';
        showTopSuccess(context, 'Marked ${user.name ?? user.email} as $statusText');
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Mark attendance failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingUserIds.remove(user.id));
    }
  }

  Future<void> _markAllPresent(List<UserProfile> users) async {
    final unmarked = users.where((u) => !_userAttendance.containsKey(u.id)).toList();
    if (unmarked.isEmpty) {
      showTopError(context, 'All users already marked');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All Present'),
        content: Text('Mark ${unmarked.length} unmarked members as present?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final user in unmarked) {
      await _markAttendance(user, 'present');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d').format(_date);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Check-in · ${widget.sessionName}'),
            if (_isRealtimeConnected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Live',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showOnlyUnmarked ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: _showOnlyUnmarked ? 'Show All' : 'Show Unmarked',
            onPressed: () => setState(() => _showOnlyUnmarked = !_showOnlyUnmarked),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(dateLabel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.trackTime)
                      Chip(
                        label: const Text('Time-tracked'),
                        avatar: const Icon(Icons.schedule, size: 18),
                        backgroundColor: colorScheme.tertiaryContainer,
                      )
                    else
                      Chip(
                        label: const Text('Attendance only'),
                        avatar: const Icon(Icons.event_available, size: 18),
                        backgroundColor: colorScheme.tertiaryContainer,
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Stats and Actions Bar
          FutureBuilder<List<UserProfile>>(
            future: ref.read(userRepositoryProvider).listAllUsers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final users = snapshot.data!;
              final presentCount = _userAttendance.values.where((s) => s == 'present').length;
              final absentCount = _userAttendance.values.where((s) => s == 'absent').length;
              final unmarkedCount = users.length - presentCount - absentCount;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatChip(
                          icon: Icons.check_circle,
                          label: 'Present',
                          count: presentCount,
                          color: Colors.green,
                        ),
                        _StatChip(
                          icon: Icons.cancel,
                          label: 'Absent',
                          count: absentCount,
                          color: Colors.red,
                        ),
                        _StatChip(
                          icon: Icons.radio_button_unchecked,
                          label: 'Unmarked',
                          count: unmarkedCount,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    if (unmarkedCount > 0) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _markAllPresent(users),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Mark All Present'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          
          // Users List
          Expanded(
            child: FutureBuilder<List<UserProfile>>(
              future: ref.read(userRepositoryProvider).listAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allUsers = snapshot.data ?? [];
                if (allUsers.isEmpty) return const Center(child: Text('No participants'));
                
                final users = _showOnlyUnmarked
                    ? allUsers.where((u) => !_userAttendance.containsKey(u.id)).toList()
                    : allUsers;
                
                if (users.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text('All members marked!', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  );
                }
                
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (c, i) {
                    final u = users[i];
                    final busy = _loadingUserIds.contains(u.id);
                    final status = _userAttendance[u.id];
                    
                    return _UserAttendanceTile(
                      user: u,
                      status: status,
                      isLoading: busy,
                      onMarkPresent: () => _markAttendance(u, 'present'),
                      onMarkAbsent: () => _markAttendance(u, 'absent'),
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

// Stat Chip Widget
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// User Attendance Tile with Present/Absent Toggle
class _UserAttendanceTile extends StatelessWidget {
  const _UserAttendanceTile({
    required this.user,
    required this.status,
    required this.isLoading,
    required this.onMarkPresent,
    required this.onMarkAbsent,
  });

  final UserProfile user;
  final String? status;
  final bool isLoading;
  final VoidCallback onMarkPresent;
  final VoidCallback onMarkAbsent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPresent = status == 'present';
    final isAbsent = status == 'absent';
    final isMarked = status != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isPresent
            ? Colors.green.shade50
            : isAbsent
                ? Colors.red.shade50
                : null,
        border: Border.all(
          color: isPresent
              ? Colors.green.shade200
              : isAbsent
                  ? Colors.red.shade200
                  : Colors.transparent,
          width: isMarked ? 2 : 0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent
              ? Colors.green.shade100
              : isAbsent
                  ? Colors.red.shade100
                  : colorScheme.surfaceContainerHighest,
          child: Icon(
            isPresent
                ? Icons.check
                : isAbsent
                    ? Icons.close
                    : Icons.person,
            color: isPresent
                ? Colors.green.shade700
                : isAbsent
                    ? Colors.red.shade700
                    : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          user.name ?? user.email,
          style: TextStyle(
            fontWeight: isMarked ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          user.email,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isMarked
                ? Chip(
                    label: Text(
                      isPresent ? 'Present' : 'Absent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPresent
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    backgroundColor: isPresent
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    side: BorderSide.none,
                    deleteIcon: const Icon(Icons.edit, size: 16),
                    onDeleted: () => _showChangeStatusDialog(context),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        onPressed: onMarkPresent,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Present'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onMarkAbsent,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Absent'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showChangeStatusDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Text('Change attendance status for ${user.name ?? user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (status == 'present')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onMarkAbsent();
              },
              icon: const Icon(Icons.close),
              label: const Text('Mark Absent'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            )
          else
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onMarkPresent();
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark Present'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
        ],
      ),
    );
  }
}


