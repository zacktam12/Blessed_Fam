import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/attendance.dart';
import '../../../models/session.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/sessions_repository.dart';

class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  int? _selectedSessionId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  Future<Map<String, dynamic>> _loadData() async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final sessionsRepo = ref.read(sessionsRepositoryProvider);

    final sessions = await sessionsRepo.fetchSessions();
    final records = await attendanceRepo.fetchUserAttendance(
      sessionId: _selectedSessionId,
      startDate: _startDate,
      endDate: _endDate,
    );
    final stats = await attendanceRepo.getUserAttendanceStats();

    // Create session map for quick lookups
    final sessionMap = {for (var s in sessions) s.id: s};

    return {
      'sessions': sessions,
      'records': records,
      'stats': stats,
      'sessionMap': sessionMap,
    };
  }

  void _clearFilters() {
    setState(() {
      _selectedSessionId = null;
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: 'Filter',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Card
          FutureBuilder<Map<String, dynamic>>(
            future: _loadData(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const SizedBox.shrink();
              if (!snapshot.hasData) return const SizedBox.shrink();
              
              final stats = snapshot.data!['stats'] as Map<String, dynamic>;
              return _StatsCard(stats: stats);
            },
          ),
          
          // Filters Section
          if (_showFilters)
            FutureBuilder<Map<String, dynamic>>(
              future: _loadData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final sessions = snapshot.data!['sessions'] as List<SessionType>;
                return _FiltersSection(
                  sessions: sessions,
                  selectedSessionId: _selectedSessionId,
                  startDate: _startDate,
                  endDate: _endDate,
                  onSessionChanged: (id) => setState(() => _selectedSessionId = id),
                  onStartDateTap: _pickStartDate,
                  onEndDateTap: _pickEndDate,
                  onClearFilters: _clearFilters,
                );
              },
            ),
          
          // Attendance List
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              key: ValueKey('$_selectedSessionId-$_startDate-$_endDate'),
              future: _loadData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final records = snapshot.data!['records'] as List<AttendanceRecord>;
                final sessionMap = snapshot.data!['sessionMap'] as Map<int, SessionType>;
                
                if (records.isEmpty) {
                  return const _EmptyState();
                }
                
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  separatorBuilder: (c, i) => const Divider(height: 0),
                  itemBuilder: (c, i) {
                    final record = records[i];
                    final session = sessionMap[record.sessionId];
                    return _AttendanceListTile(record: record, session: session);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] as int;
    final present = stats['present'] as int;
    final absent = stats['absent'] as int;
    final rate = stats['attendanceRate'] as String;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: 'Total',
              value: '$total',
              icon: Icons.event_note,
              color: Colors.blue,
            ),
            _StatItem(
              label: 'Present',
              value: '$present',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            _StatItem(
              label: 'Absent',
              value: '$absent',
              icon: Icons.cancel,
              color: Colors.red,
            ),
            _StatItem(
              label: 'Rate',
              value: '$rate%',
              icon: Icons.trending_up,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.sessions,
    required this.selectedSessionId,
    required this.startDate,
    required this.endDate,
    required this.onSessionChanged,
    required this.onStartDateTap,
    required this.onEndDateTap,
    required this.onClearFilters,
  });

  final List<SessionType> sessions;
  final int? selectedSessionId;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<int?> onSessionChanged;
  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: selectedSessionId,
            decoration: const InputDecoration(
              labelText: 'Session',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(
                child: Text('All Sessions'),
              ),
              ...sessions.map((s) => DropdownMenuItem<int?>(
                    value: s.id,
                    child: Text(s.name),
                  )),
            ],
            onChanged: onSessionChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStartDateTap,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    startDate == null
                        ? 'Start Date'
                        : DateFormat('MMM d, y').format(startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEndDateTap,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    endDate == null
                        ? 'End Date'
                        : DateFormat('MMM d, y').format(endDate!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceListTile extends StatelessWidget {
  const _AttendanceListTile({
    required this.record,
    required this.session,
  });
  final AttendanceRecord record;
  final SessionType? session;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d, y').format(record.date);
    final timeStr = record.arrivalTime != null
        ? DateFormat('h:mm a').format(record.arrivalTime!)
        : null;
    final isPresent = record.status == 'present';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isPresent ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(
          isPresent ? Icons.check : Icons.close,
          color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
      title: Text(session?.name ?? 'Unknown Session'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr),
          // Only show arrival time if present
          if (isPresent && timeStr != null) Text('Arrived at $timeStr', style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Chip(
        label: Text(
          isPresent ? 'Present' : 'Absent',
          style: TextStyle(
            fontSize: 12,
            color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
        side: BorderSide.none,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          const Text('No attendance records found'),
          const SizedBox(height: 8),
          Text(
            'Your attendance will appear here once marked',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
