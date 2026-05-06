import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _sessionsService = SessionsService();
  
  List<Session> _allSessions = [];
  List<Session> _filteredSessions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final sessions = await _sessionsService.getAllSessions();
      if (mounted) {
        setState(() {
          _allSessions = sessions;
          _filterSessions();
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
    // Safely get session ID as string (handles _JsonMap issue)
    final sessionId = session.id.toString();
    
    if (session.status == SessionStatus.planned) {
      try {
        setState(() => _isLoading = true);
        await _sessionsService.updateSessionStatus(sessionId, 'active');
        await _loadSessions();
        if (mounted) {
          // Navigate with path parameter instead of extra
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

  void _filterSessions() {
    setState(() {
      _filteredSessions = _allSessions.where((s) {
        if (_tabController.index == 1) {
          return s.status == SessionStatus.inProgress;
        } else if (_tabController.index == 2) {
          return s.status == SessionStatus.planned;
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          onTap: (_) => _filterSessions(),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Planned'),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/sessions/new');
          _loadSessions();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Session', style: TextStyle(color: Colors.white)),
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
              onPressed: _loadSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No sessions found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSessions.length,
      itemBuilder: (context, index) => _buildSessionCard(_filteredSessions[index]),
    );
  }

  Widget _buildSessionCard(Session session) {
    // Safely convert session fields for web compatibility
    final moduleName = session.moduleName.toString();
    final groupName = session.groupName.toString();
    final typeString = session.typeString;
    final presentCount = session.presentCount;
    final totalStudents = session.totalStudents;
    
    final isCompleted = session.status == SessionStatus.completed;
    final isInProgress = session.status == SessionStatus.inProgress;
    
    final statusColor = isCompleted
        ? AppColors.textSecondary
        : (isInProgress ? AppColors.success : AppColors.warning);
    final statusText = isCompleted
        ? 'Completed'
        : (isInProgress ? 'In Progress' : 'Planned');
    final statusBg = isCompleted
        ? AppColors.background
        : (isInProgress ? AppColors.successLight : AppColors.warningLight);

    final typeColor = session.type == SessionType.cours
        ? AppColors.primary
        : (session.type == SessionType.td
            ? AppColors.warning
            : (session.type == SessionType.tp ? AppColors.success : AppColors.textMuted));

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
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moduleName,
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
                                  typeString,
                                  style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(groupName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(Icons.calendar_today, session.startTime.day.toString()),
                    const SizedBox(width: 12),
                    _buildInfoChip(Icons.room, session.room.toString()),
                    const Spacer(),
                    if (session.status == SessionStatus.completed || session.status == SessionStatus.inProgress)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '$presentCount/$totalStudents',
                              style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (session.status == SessionStatus.inProgress) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleSessionAction(session),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('View Live Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                if (session.status == SessionStatus.planned) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleSessionAction(session),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
