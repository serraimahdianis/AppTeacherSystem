import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Session> _allSessions = [];
  List<Session> _completedSessions = [];
  Session? _selectedSession;
  List<Attendance> _selectedAttendance = [];
  bool _loadingAttendance = false;

  final _sessionsService = SessionsService();
  final _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final teacherId = ApiClient().teacherId;
      if (teacherId == null) {
        setState(() {
          _errorMessage = 'Teacher ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final sessions = await _sessionsService.getTeacherSessions(teacherId);
      if (mounted) {
        setState(() {
          _allSessions = sessions;
          _completedSessions = sessions
              .where((s) => s.status == SessionStatus.completed)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAttendance(String sessionId) async {
    setState(() => _loadingAttendance = true);
    try {
      final attendance = await _attendanceService.getSessionAttendance(sessionId);
      if (mounted) {
        setState(() {
          _selectedAttendance = attendance;
          _loadingAttendance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAttendance = [];
          _loadingAttendance = false;
        });
      }
    }
  }

  void _exportCsv() {
    final headers = ['Session ID', 'Date', 'Module', 'Type', 'Group', 'Time', 'Status'];
    final rows = _completedSessions.map((s) => [
      s.id,
      DateFormat('yyyy-MM-dd').format(s.date),
      s.moduleName,
      s.typeString.toUpperCase(),
      s.groupName,
      s.timeRange,
      s.statusString,
    ]);

    final csv = [headers, ...rows].map((r) => r.join(',')).join('\n');

    final bytes = csv.codeUnits;
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/attendance-report-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv');
    file.writeAsBytesSync(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported to ${file.path}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPdfPreview(Session session) {
    setState(() => _selectedSession = session);
    _loadAttendance(session.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _buildPdfPreview(scrollController),
      ),
    );
  }

  Widget _buildPdfPreview(ScrollController scrollController) {
    if (_selectedSession == null) return const SizedBox.shrink();
    final session = _selectedSession!;

    final presentCount = _selectedAttendance.where((a) => a.status == AttendanceStatus.present).length;
    final lateCount = _selectedAttendance.where((a) => a.status == AttendanceStatus.late).length;
    final absentCount = _selectedAttendance.where((a) => a.status == AttendanceStatus.absent).length;
    final total = _selectedAttendance.length;

    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Attendance Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.moduleName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(DateFormat('EEEE, MMMM d, yyyy').format(session.date), style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${session.typeString} ${session.groupName.isNotEmpty ? '• Group ${session.groupName}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${session.startTimeStr} - ${session.endTimeStr}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statsPill('Total', '$total', AppColors.textPrimary),
                const SizedBox(width: 8),
                _statsPill('Present', '$presentCount', AppColors.success),
                const SizedBox(width: 8),
                _statsPill('Late', '$lateCount', AppColors.warning),
                const SizedBox(width: 8),
                _statsPill('Absent', '$absentCount', AppColors.error),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Roster', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (_loadingAttendance)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_selectedAttendance.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No attendance records for this session.', style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ..._selectedAttendance.asMap().entries.map((entry) {
                final i = entry.key;
                final record = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text('${i + 1}.', style: const TextStyle(fontFamily: 'monospace', color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          record.studentName.isNotEmpty ? record.studentName : record.studentId,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                      _statusBadge(record.status),
                      const SizedBox(width: 8),
                      Text(
                          DateFormat('HH:mm:ss').format(record.scanTime),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statsPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(AttendanceStatus status) {
    final (color, label) = switch (status) {
      AttendanceStatus.present => (AppColors.success, 'Present'),
      AttendanceStatus.late => (AppColors.warning, 'Late'),
      AttendanceStatus.absent => (AppColors.error, 'Absent'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueModules = _completedSessions.map((s) => s.moduleName).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _completedSessions.isEmpty ? null : _exportCsv,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export CSV'),
            ),
        ],
      ),
      body: _buildBody(uniqueModules),
    );
  }

  Widget _buildBody(int uniqueModules) {
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
            ElevatedButton(onPressed: _loadReports, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _statCard('Completed', '${_completedSessions.length}', AppColors.success, Icons.trending_up),
            const SizedBox(width: 10),
            _statCard('Modules', '$uniqueModules', AppColors.primary, Icons.book),
            const SizedBox(width: 10),
            _statCard('Total', '${_allSessions.length}', AppColors.warning, Icons.people),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Completed Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_completedSessions.length} sessions',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_completedSessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No completed sessions yet', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          ..._completedSessions.map((session) => _buildReportCard(session)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Session session) {
    final typeColor = switch (session.type) {
      SessionType.cours => AppColors.primary,
      SessionType.td => AppColors.success,
      SessionType.tp => Colors.blue,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPdfPreview(session),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.moduleName,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(session.date),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              session.typeString.toUpperCase(),
                              style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (session.groupName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Grp ${session.groupName}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      session.timeRange,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'PDF',
                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}