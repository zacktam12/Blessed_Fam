import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../repositories/analytics_repository.dart';
import '../../../core/utils/flash.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    
    try {
      final csv = await ref.read(analyticsRepositoryProvider).generateCSVExport();
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));
      
      if (mounted) {
        showTopSuccess(context, 'CSV data copied to clipboard! Paste into Excel or Google Sheets.');
      }
    } catch (e) {
      if (mounted) {
        showTopError(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Trends', icon: Icon(Icons.show_chart)),
            Tab(text: 'Members', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            tooltip: 'Export Data',
            onPressed: _isExporting ? null : _exportData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _TrendsTab(),
          _MembersTab(),
        ],
      ),
    );
  }
}

// Overview Tab
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(analyticsRepositoryProvider).getOverallStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final stats = snapshot.data!;
        
        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by invalidating
            ref.invalidate(analyticsRepositoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'System Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Stats Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    title: 'Total Members',
                    value: '${stats['totalMembers']}',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  _StatCard(
                    title: 'Sessions',
                    value: '${stats['totalSessions']}',
                    icon: Icons.event,
                    color: Colors.purple,
                  ),
                  _StatCard(
                    title: 'Total Records',
                    value: '${stats['totalRecords']}',
                    icon: Icons.description,
                    color: Colors.orange,
                  ),
                  _StatCard(
                    title: 'Attendance Rate',
                    value: '${stats['attendanceRate']}%',
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Session Statistics
              Text(
                'Session Performance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref.read(analyticsRepositoryProvider).getSessionStats(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final sessions = snapshot.data!;
                  
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sessions.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final session = sessions[i];
                        final total = session['total_records'] as int;
                        final present = session['present_count'] as int;
                        final rate = total > 0 
                            ? (present / total * 100).toStringAsFixed(0)
                            : '0';
                        
                        return ListTile(
                          title: Text(session['name'] as String),
                          subtitle: Text('$present/$total present'),
                          trailing: Chip(
                            label: Text('$rate%'),
                            backgroundColor: _getRateColor(double.parse(rate)),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRateColor(double rate) {
    if (rate >= 80) return Colors.green.shade100;
    if (rate >= 60) return Colors.orange.shade100;
    return Colors.red.shade100;
  }
}

// Trends Tab
class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(analyticsRepositoryProvider).getWeeklyTrends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final trends = snapshot.data!;
        
        if (trends.isEmpty) {
          return const Center(
            child: Text('No trend data available'),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(analyticsRepositoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Weekly Attendance Trends',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Last ${trends.length} weeks',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
              // Simple bar chart visualization
              ...trends.map((trend) {
                final weekDate = DateTime.parse(trend['week'] as String);
                final weekLabel = DateFormat('MMM d').format(weekDate);
                final rate = trend['rate'] as int;
                final present = trend['present'] as int;
                final total = trend['total'] as int;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(weekLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('$present/$total ($rate%)'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate / 100,
                          minHeight: 20,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// Members Tab
class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(analyticsRepositoryProvider).getMemberParticipation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final members = snapshot.data!;
        
        if (members.isEmpty) {
          return const Center(child: Text('No member data available'));
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(analyticsRepositoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Member Participation',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${members.length} members',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              
              ...members.map((member) {
                final name = member['name'] as String;
                final rate = member['rate'] as int;
                final present = member['present'] as int;
                final total = member['total'] as int;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getRateColor(rate.toDouble()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$rate%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _MiniStat(
                              label: 'Total',
                              value: '$total',
                              icon: Icons.event,
                            ),
                            const SizedBox(width: 16),
                            _MiniStat(
                              label: 'Present',
                              value: '$present',
                              icon: Icons.check_circle,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 16),
                            _MiniStat(
                              label: 'Absent',
                              value: '${total - present}',
                              icon: Icons.cancel,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Color _getRateColor(double rate) {
    if (rate >= 80) return Colors.green.shade100;
    if (rate >= 60) return Colors.orange.shade100;
    return Colors.red.shade100;
  }
}

// Helper Widgets
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
