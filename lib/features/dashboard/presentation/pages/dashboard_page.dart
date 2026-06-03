import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
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
  List<Attendance> _recentActivity = [];

  final _sessionsService = SessionsService();
  final _scheduleService = ScheduleService();
  final _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final teacherId = ApiClient().user?.id;
      if (teacherId == null) throw 'Teacher ID not found.';

      final results = await Future.wait([
        _sessionsService.getTeacherSessions(teacherId),
        _scheduleService.getTeacherSchedule(teacherId),
        _attendanceService.getAttendanceStats(),
      ]);

      final sessions = results[0] as List<Session>;
      final schedules = results[1] as List<Schedule>;
      final stats = results[2] as Map<String, dynamic>;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayDayName = _dayName(now.weekday);

      final todaySessions = sessions.where((s) =>
        DateTime(s.date.year, s.date.month, s.date.day) == today
      ).toList();

      final todayScheduleSessionIds = todaySessions
        .where((s) => s.scheduleId != null)
        .map((s) => s.scheduleId)
        .toSet();

      final todaySchedules = schedules.where((s) =>
        s.dayOfWeek == todayDayName
      ).toList();

      for (final schedule in todaySchedules) {
        if (!todayScheduleSessionIds.contains(schedule.id)) {
          todaySessions.add(Session(
            id: schedule.id,
            scheduleId: schedule.id,
            moduleName: schedule.moduleName,
            groupName: schedule.groupName,
            type: _parseType(schedule.type),
            room: schedule.room,
            date: today,
            startTimeStr: schedule.startTime,
            endTimeStr: schedule.endTime,
            status: SessionStatus.planned,
            teacherId: schedule.teacherId,
            createdAt: now,
          ));
        }
      }

      todaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      if (mounted) {
        List<Attendance> recentActivity = [];
        final recentLiveSession = todaySessions.where((s) =>
          s.status == SessionStatus.inProgress || s.status == SessionStatus.completed
        ).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));

        if (recentLiveSession.isNotEmpty) {
          try {
            recentActivity = await _attendanceService.getSessionAttendance(recentLiveSession.first.id);
          } catch (_) {}
        }

        setState(() {
          _todaySessions = todaySessions;
          _presentToday = stats['totalPresent'] ?? 0;
          _absentToday = stats['totalAbsent'] ?? 0;
          _lateToday = stats['totalLate'] ?? 0;
          _upcomingSessions = todaySessions.where((s) => s.status == SessionStatus.planned).take(5).toList();
          _recentActivity = recentActivity.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      final error = e.toString();
      if (error.contains('Session expired') && mounted) { context.go('/login'); return; }
      if (mounted) setState(() { _errorMessage = error; _isLoading = false; });
    }
  }

  String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  SessionType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'td': return SessionType.td;
      case 'tp': return SessionType.tp;
      default: return SessionType.cours;
    }
  }

  Future<void> _handleSessionAction(Session session) async {
    final sessionId = session.id.toString();
    if (session.status == SessionStatus.planned) {
      setState(() => _isLoading = true);
      try {
        if (session.scheduleId != null && session.id == session.scheduleId) {
          await _sessionsService.startSessionFromSchedule(session.scheduleId!);
        } else {
          await _sessionsService.updateSessionStatus(sessionId, 'active');
        }
        await _loadDashboardData();
        if (mounted) context.push('/sessions/attendance/$sessionId');
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (session.status == SessionStatus.inProgress) {
      if (mounted) context.push('/sessions/attendance/$sessionId');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)));
    }
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error), const SizedBox(height: 16),
          Text(_errorMessage, style: const TextStyle(color: AppColors.error)), const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadDashboardData, child: const Text('Retry')),
        ])),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        Positioned(top: -100, right: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent], radius: 0.8)))),
        SafeArea(bottom: false, child: RefreshIndicator(onRefresh: _loadDashboardData, color: AppColors.primaryLight, backgroundColor: AppColors.surface, child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildStatsCards(context)),
          SliverToBoxAdapter(child: _buildTodaySessions(context)),
          SliverToBoxAdapter(child: _buildAttendanceChart(context)),
          SliverToBoxAdapter(child: _buildUpcomingSessions(context)),
          SliverToBoxAdapter(child: _buildRecentActivity(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]))),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 28)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Smart', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('Attendance', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primaryLight)),
            ]),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.surfaceGlass, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryLight), const SizedBox(width: 8),
              Text('${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ])),
        ]),
        const SizedBox(height: 32),
        Text('Welcome back,\n${ApiClient().user?.firstName ?? 'Teacher'} 👋', style: Theme.of(context).textTheme.headlineLarge?.copyWith(height: 1.2)),
        const SizedBox(height: 8),
        Text('Here is what\'s happening today.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
      ]).animate().fade(duration: 400.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.15, children: [
        _StatCard(title: 'Present Today', value: '$_presentToday', icon: Icons.check_circle, color: AppColors.success).animate().fade(delay: 100.ms).scaleXY(begin: 0.9, curve: Curves.easeOutBack),
        _StatCard(title: 'Absent Today', value: '$_absentToday', icon: Icons.cancel, color: AppColors.error).animate().fade(delay: 200.ms).scaleXY(begin: 0.9, curve: Curves.easeOutBack),
        _StatCard(title: 'Late Arrivals', value: '$_lateToday', icon: Icons.access_time_filled, color: AppColors.warning).animate().fade(delay: 300.ms).scaleXY(begin: 0.9, curve: Curves.easeOutBack),
        _StatCard(title: 'Sessions Today', value: '${_todaySessions.length}', icon: Icons.calendar_month, color: AppColors.primaryLight).animate().fade(delay: 400.ms).scaleXY(begin: 0.9, curve: Curves.easeOutBack),
      ]),
    );
  }

  Widget _buildTodaySessions(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 32, left: 24, right: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Today's Sessions", style: Theme.of(context).textTheme.titleLarge),
        if (_todaySessions.isNotEmpty) TextButton(onPressed: () => context.go('/sessions'), child: const Text('View All', style: TextStyle(color: AppColors.primaryLight))),
      ]),
      const SizedBox(height: 16),
      if (_todaySessions.isEmpty)
        Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: const Center(child: Text('No sessions today', style: TextStyle(color: AppColors.textMuted))))
      else
        ..._todaySessions.take(5).toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final session = entry.value;
          return Padding(padding: const EdgeInsets.only(bottom: 16), child: _SessionCard(
            time: session.timeRange, module: session.moduleName, group: session.groupName,
            type: session.typeString, room: session.room,
            status: session.status == SessionStatus.inProgress ? 'in_progress' : (session.status == SessionStatus.completed ? 'completed' : 'planned'),
            presentCount: '${session.presentCount}/${session.totalStudents}',
            showStartButton: session.status == SessionStatus.planned,
            onPressed: () => _handleSessionAction(session),
          )).animate().fade(delay: (idx * 100).ms).slideX(begin: 0.1);
        }),
    ]));
  }

  Widget _buildAttendanceChart(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 24, left: 24, right: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Attendance Overview', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
        height: 220, child: _WeekChart(),
      ).animate().fade().slideY(begin: 0.1),
    ]));
  }

  Widget _buildUpcomingSessions(BuildContext context) {
    if (_upcomingSessions.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 24, left: 24, right: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Upcoming Sessions', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      Card(child: Column(children: _upcomingSessions.asMap().entries.map((entry) {
        final session = entry.value;
        return Column(children: [
          if (entry.key > 0) const Divider(height: 1),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.class_, size: 16, color: AppColors.primaryLight)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(session.moduleName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)), Text(session.typeString, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500))]),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${session.date.month}/${session.date.day}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)), Text(session.timeRange, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
          ])),
        ]);
      }).toList())).animate().fade().slideY(begin: 0.1),
    ]));
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 24, left: 24, right: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: _recentActivity.isEmpty
        ? const Text('No recent activity', style: TextStyle(color: AppColors.textMuted))
        : Column(children: _recentActivity.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: a.status == AttendanceStatus.present ? AppColors.successLight : (a.status == AttendanceStatus.late ? AppColors.warningLight : AppColors.errorLight), shape: BoxShape.circle),
                child: Icon(a.status == AttendanceStatus.present ? Icons.check_circle : (a.status == AttendanceStatus.late ? Icons.access_time_filled : Icons.cancel), color: a.status == AttendanceStatus.present ? AppColors.success : (a.status == AttendanceStatus.late ? AppColors.warning : AppColors.error), size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Text(a.studentName.isNotEmpty ? a.studentName : a.studentId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary))),
              Text(a.statusString, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: a.status == AttendanceStatus.present ? AppColors.success : (a.status == AttendanceStatus.late ? AppColors.warning : AppColors.error))),
            ]),
          )).toList()),
      )).animate().fade().slideY(begin: 0.1),
    ]));
  }
}

class _WeekChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(days[v.toInt() % 7], style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0, maxX: 6, minY: 0, maxY: 100,
      lineBarsData: [
        LineChartBarData(spots: List.generate(7, (i) => FlSpot(i.toDouble(), 50.0 + (i * 5.0).toDouble())), isCurved: true, color: AppColors.primaryLight, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (s, p, a, i) => FlDotCirclePainter(radius: 4, color: AppColors.primaryLight, strokeWidth: 0)), belowBarData: BarAreaData(show: true, color: AppColors.primaryLight.withValues(alpha: 0.1))),
      ],
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceGlass, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border.withValues(alpha: 0.5)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Stack(children: [
        Positioned(right: -10, bottom: -10, child: Icon(icon, size: 80, color: color.withValues(alpha: 0.1))),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ])),
      ]))),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String time; final String module; final String group; final String type; final String room; final String status; final String presentCount;
  final bool showStartButton; final VoidCallback? onPressed;
  const _SessionCard({required this.time, required this.module, required this.group, required this.type, required this.room, required this.status, required this.presentCount, this.showStartButton = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final statusData = switch (status) {
      'completed' => (color: AppColors.textSecondary, text: 'Completed', bg: AppColors.surfaceGlass),
      'in_progress' => (color: AppColors.success, text: 'In Progress', bg: AppColors.successLight),
      _ => (color: AppColors.warning, text: 'Planned', bg: AppColors.warningLight),
    };
    final isInProgress = status == 'in_progress';
    final borderColor = isInProgress ? AppColors.success.withValues(alpha: 0.3) : AppColors.border;
    return GestureDetector(
      onTap: isInProgress ? onPressed : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text(time, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(module, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text('$group • ${type.toUpperCase()} • $room', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: statusData.bg, borderRadius: BorderRadius.circular(8)),
                          child: Text(statusData.text, style: TextStyle(color: statusData.color, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (isInProgress || status == 'completed') ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.people, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('$presentCount present', style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (showStartButton)
                ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(16)),
                  child: const Icon(Icons.play_arrow_rounded, size: 28),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
              if (isInProgress) const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primaryLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
