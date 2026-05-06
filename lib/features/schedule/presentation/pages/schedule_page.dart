import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  int _selectedDay = 0;

  Map<int, List<Schedule>> _groupedSchedules = {};
  bool _isLoading = true;
  String _errorMessage = '';

  final _scheduleService = ScheduleService();
  final _sessionsService = SessionsService();

  @override
  void initState() {
    super.initState();
    _selectedDay = (DateTime.now().weekday - 1).clamp(0, _weekDays.length - 1);
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final schedules = await _scheduleService.getAllSchedules();
      final grouped = <int, List<Schedule>>{};
      
      for (final schedule in schedules) {
        grouped.putIfAbsent(schedule.dayOfWeekInt, () => []).add(schedule);
      }

      if (mounted) {
        setState(() {
          _groupedSchedules = grouped;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => context.go('/schedule/add')),
        ],
      ),
      body: Column(
        children: [
          _buildWeekHeader(),
          _buildDaySelector(),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final friday = monday.add(const Duration(days: 4));
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '${months[monday.month - 1]} ${monday.day} - ${months[friday.month - 1]} ${friday.day}, ${now.year}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dates = List.generate(6, (i) => monday.add(Duration(days: i)));
    
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _weekDays.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDay;
          final isToday = dates[index].day == now.day && dates[index].month == now.month;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = index),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : (isToday ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isToday ? AppColors.primary : AppColors.border),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekDays[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dates[index].day}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isToday ? AppColors.primary : AppColors.textPrimary),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSchedules,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final sessions = _groupedSchedules[_selectedDay] ?? [];
    
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No classes on ${_weekDays[_selectedDay]}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) => _buildScheduleCard(sessions[index]),
    );
  }

  Future<void> _handlePopupAction(Schedule schedule, String value) async {
    // Store context-dependent references before async gaps
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    switch (value) {
      case 'edit':
        await context.push('/schedule/edit/${schedule.id}');
        if (mounted) _loadSchedules();
        break;
      case 'start':
        try {
          setState(() => _isLoading = true);
          final session = await _sessionsService.startSessionFromSchedule(schedule.id);
          if (mounted) {
            // Navigate with path parameter instead of extra
            router.push('/sessions/attendance/${session.id.toString()}');
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to start session: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
            _loadSchedules();
          }
        }
        break;
      case 'cancel':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Schedule'),
            content: const Text('Are you sure you want to delete this schedule?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await _scheduleService.deleteSchedule(schedule.id);
            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Schedule deleted')),
              );
              _loadSchedules();
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Failed to delete: $e')),
              );
            }
          }
        }
        break;
    }
  }

  Widget _buildScheduleCard(Schedule session) {
    final typeColor = switch (session.type.toString().toUpperCase()) {
      'COURS' => AppColors.primary,
      'TD' => AppColors.success,
      'TP' => Colors.blue,
      _ => AppColors.textMuted,
    };

    // Safely convert any type to string
    String formatValue(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is Map) return value['name']?.toString() ?? value.toString();
      return value.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${formatValue(session.startTime)} - ${formatValue(session.endTime)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatValue(session.moduleName),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            formatValue(session.type),
                            style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(formatValue(session.groupName), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.room, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(formatValue(session.room), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              onSelected: (value) => _handlePopupAction(session, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'start', child: Text('Start Session')),
                const PopupMenuItem(value: 'cancel', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
