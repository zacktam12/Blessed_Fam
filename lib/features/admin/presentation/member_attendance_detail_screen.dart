import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/user_profile.dart';
import '../../../models/attendance.dart';
import '../../../models/session.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/sessions_repository.dart';

class MemberAttendanceDetailScreen extends ConsumerStatefulWidget {
  const MemberAttendanceDetailScreen({
    super.key,
    required this.member,
  });

  final UserProfile member;

  @override
  ConsumerState<MemberAttendanceDetailScreen> createState() =>
      _MemberAttendanceDetailScreenState();
}

class _MemberAttendanceDetailScreenState
    extends ConsumerState<MemberAttendanceDetailScreen> {
  int? _selectedSessionId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name ?? widget.member.email),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadAttendanceData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final theme = Theme.of(context);
          final data = snapshot.data!;
          final records = data['records'] as List<AttendanceRecord>;
          final stats = data['stats'] as Map<String, dynamic>;
          final sessions = data['sessions'] as Map<int, SessionType>;

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No attendance records found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_selectedSessionId != null || _startDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSessionId = null;
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Statistics Card
                _buildStatsCard(context, stats),
                const SizedBox(height: 16),

                // Filter Chips
                if (_selectedSessionId != null || _startDate != null) ...[
                  _buildFilterChips(context, sessions),
                  const SizedBox(height: 16),
                ],

                // Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance History',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${records.length} records',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Attendance List
                ...records.map((record) {
                  final session = sessions[record.sessionId];
                  return _buildAttendanceCard(
                    context,
                    record,
                    session,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    // Fetch attendance records
    final records = await ref.read(attendanceRepositoryProvider).fetchUserAttendance(
          userId: widget.member.id,
          sessionId: _selectedSessionId,
          startDate: _startDate,
          endDate: _endDate,
        );

    // Fetch sessions for mapping
    final sessionsList = await ref.read(sessionsRepositoryProvider).fetchSessions();
    final sessionsMap = {for (var s in sessionsList) s.id: s};

    // Calculate stats
    final presentCount = records.where((r) => r.status == 'present').length;
    final absentCount = records.where((r) => r.status == 'absent').length;
    final total = records.length;
    final rate = total > 0 ? (presentCount / total * 100).toStringAsFixed(1) : '0.0';

    return {
      'records': records,
      'sessions': sessionsMap,
      'stats': {
        'total': total,
        'present': presentCount,
        'absent': absentCount,
        'rate': rate,
      },
    };
  }

  Widget _buildStatsCard(BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.event,
              label: 'Total',
              value: '${stats['total']}',
              color: colorScheme.primary,
            ),
            _StatItem(
              icon: Icons.check_circle,
              label: 'Present',
              value: '${stats['present']}',
              color: Colors.green,
            ),
            _StatItem(
              icon: Icons.cancel,
              label: 'Absent',
              value: '${stats['absent']}',
              color: Colors.red,
            ),
            _StatItem(
              icon: Icons.trending_up,
              label: 'Rate',
              value: '${stats['rate']}%',
              color: colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    Map<int, SessionType> sessions,
  ) {
    return Wrap(
      spacing: 8,
      children: [
        if (_selectedSessionId != null)
          Chip(
            avatar: const Icon(Icons.event, size: 18),
            label: Text(sessions[_selectedSessionId]?.name ?? 'Session'),
            onDeleted: () {
              setState(() => _selectedSessionId = null);
            },
          ),
        if (_startDate != null)
          Chip(
            avatar: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              'From ${DateFormat('MMM d, y').format(_startDate!)}',
            ),
            onDeleted: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
            },
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedSessionId = null;
              _startDate = null;
              _endDate = null;
            });
          },
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Clear All'),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(
    BuildContext context,
    AttendanceRecord record,
    SessionType? session,
  ) {
    final isPresent = record.status == 'present';
    final dateStr = DateFormat('EEE, MMM d, y').format(record.date);
    final timeStr = record.arrivalTime != null
        ? DateFormat('h:mm a').format(record.arrivalTime!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isPresent ? Icons.check : Icons.close,
            color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        title: Text(
          session?.name ?? 'Unknown Session',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(dateStr),
            // Only show arrival time if present
            if (isPresent && timeStr != null)
              Text(
                'Arrived at $timeStr',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Text(
            isPresent ? 'Present' : 'Absent',
            style: TextStyle(
              color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final sessions = await ref.read(sessionsRepositoryProvider).fetchSessions();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Attendance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Session',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _selectedSessionId,
                decoration: const InputDecoration(
                  labelText: 'Session Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Sessions')),
                  ...sessions.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedSessionId = value);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter by Date Range',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  _startDate != null
                      ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'
                      : 'Select Date Range',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSessionId = null;
                _startDate = null;
                _endDate = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
