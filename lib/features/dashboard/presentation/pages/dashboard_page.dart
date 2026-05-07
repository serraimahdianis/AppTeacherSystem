import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  int _presentToday = 0;
  int _absentToday = 0;
  int _lateToday = 0;
  
  List<Session> _todaySessions = [];
  List<Session> _upcomingSessions = [];

  final _sessionsService = SessionsService();
  final _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final sessions = await _sessionsService.getAllSessions();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final todaySessions = sessions.where((s) {
        final sessionDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        return sessionDate == today;
      }).toList();

      // Fetch real stats for today - handle error locally to avoid blocking full dashboard
      Map<String, dynamic> stats = {};
      try {
        stats = await _attendanceService.getAttendanceStats(
          startDate: today,
          endDate: today.add(const Duration(days: 1)),
        );
      } catch (e) {
        // fallback to empty stats
      }

      if (mounted) {
        setState(() {
          _todaySessions = todaySessions;
          
          // Use real stats if available, otherwise fallback to 0
          _presentToday = stats['present'] ?? 0;
          _absentToday = stats['absent'] ?? 0;
          _lateToday = stats['late'] ?? 0;
          
          _upcomingSessions = sessions.where((s) => s.startTime.isAfter(now)).take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      final error = e.toString();
      if (error.contains('Session expired') && mounted) {
        context.go('/login');
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSessionAction(Session session) async {
    final sessionId = session.id.toString();
    
    if (session.status == SessionStatus.planned) {
      try {
        setState(() => _isLoading = true);
        await _sessionsService.updateSessionStatus(sessionId, 'active');
        await _loadDashboardData();
        if (mounted) {
          context.push('/sessions/attendance/$sessionId');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start session: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (session.status == SessionStatus.inProgress) {
      context.push('/sessions/attendance/$sessionId');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_errorMessage, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboardData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildStatsCards(context)),
            SliverToBoxAdapter(child: _buildTodaysSessions(context)),
            SliverToBoxAdapter(child: _buildUpcomingSessions(context)),
            SliverToBoxAdapter(child: _buildRecentActivity(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final dayName = weekdays[now.weekday - 1];
    final monthName = months[now.month - 1];
    final day = now.day;
    final suffix = _getDaySuffix(day);
    
    final teacherName = ApiClient().user?.firstName ?? 'Teacher';
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Attendance',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome, $teacherName 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track and manage your attendance easily',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  '$dayName, $monthName $day$suffix, ${now.year}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildStatsCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                title: 'Present Today',
                value: '$_presentToday',
                unit: 'Students',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
              _StatCard(
                title: 'Absent Today',
                value: '$_absentToday',
                unit: 'Students',
                icon: Icons.cancel_outlined,
                color: AppColors.error,
              ),
              _StatCard(
                title: 'Late Arrivals',
                value: '$_lateToday',
                unit: 'Students',
                icon: Icons.access_time,
                color: AppColors.warning,
              ),
              _StatCard(
                title: 'Sessions Today',
                value: '${_todaySessions.length}',
                unit: 'Sessions',
                icon: Icons.calendar_today,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSessions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Sessions",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () => context.go('/sessions'),
                child: const Text('View All', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_todaySessions.isEmpty)
            const Center(
              child: Text(
                'No sessions today',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ...(_todaySessions.take(3).map((session) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SessionCard(
                time: session.timeRange,
                module: session.moduleName,
                group: session.groupName,
                type: session.typeString,
                room: session.room,
                status: session.statusString.toLowerCase().replaceAll(' ', '_'),
                presentCount: '${session.presentCount}/${session.totalStudents}',
                showStartButton: session.status == SessionStatus.planned,
                onPressed: () => _handleSessionAction(session),
              ),
            )).toList()),
        ],
      ),
    );
  }

  Widget _buildUpcomingSessions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Sessions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: _upcomingSessions.asMap().entries.map((entry) {
                final session = entry.value;
                return Column(
                  children: [
                    if (entry.key > 0) const Divider(height: 1),
                    _UpcomingTile(
                      date: '${session.startTime.month}/${session.startTime.day}',
                      module: session.moduleName,
                      type: session.typeString,
                      time: '${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _ActivityTile(
                    icon: Icons.check_circle,
                    iconColor: AppColors.success,
                    title: 'SERRAI MAHDI ANIS — present',
                    description: 'Software Engineering',
                    time: '09:15',
                  ),
                  SizedBox(height: 16),
                  _ActivityTile(
                    icon: Icons.access_time,
                    iconColor: AppColors.warning,
                    title: 'AHMED BENALI — late',
                    description: 'Data Structures',
                    time: '09:05',
                  ),
                  SizedBox(height: 16),
                  _ActivityTile(
                    icon: Icons.cancel,
                    iconColor: AppColors.error,
                    title: 'FATIMA ZOHRA — absent',
                    description: 'Algorithms',
                    time: '08:30',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            width: double.infinity,
            color: color,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(width: 6),
                    Text(unit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String time;
  final String module;
  final String group;
  final String type;
  final String room;
  final String status;
  final String presentCount;
  final bool showStartButton;
  final VoidCallback? onPressed;

  const _SessionCard({
    required this.time,
    required this.module,
    required this.group,
    required this.type,
    required this.room,
    required this.status,
    required this.presentCount,
    this.showStartButton = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final statusData = switch (status) {
      'completed' => (color: AppColors.textSecondary, text: 'Completed', bg: AppColors.background),
      'in_progress' => (color: AppColors.success, text: 'In Progress', bg: AppColors.successLight),
      _ => (color: AppColors.warning, text: 'Planned', bg: AppColors.warningLight),
    };

    return GestureDetector(
      onTap: status == 'in_progress' ? onPressed : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                color: statusData.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          module,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$group • $type • $room',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusData.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusData.text,
                                style: TextStyle(
                                  color: statusData.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (status == 'completed' || status == 'in_progress') ...[
                              const SizedBox(width: 8),
                              Text(
                                '$presentCount present',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (showStartButton)
                    ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  if (status == 'in_progress')
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final String date;
  final String module;
  final String type;
  final String time;

  const _UpcomingTile({
    required this.date,
    required this.module,
    required this.type,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(module, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Text(type.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          Text('$date • $time', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String time;

  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          height: 20,
          width: 20,
          decoration: BoxDecoration(
            color: iconColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ],
    );
  }
}
