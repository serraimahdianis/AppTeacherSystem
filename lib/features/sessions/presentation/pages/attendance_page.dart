import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class AttendancePage extends StatefulWidget {
  final String sessionId;
  const AttendancePage({super.key, required this.sessionId});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _sessionsService = SessionsService();
  final _studentsService = StudentsService();
  final _attendanceService = AttendanceService();
  
  Session? _session;  // Reloaded session with proper types
  List<Student> _students = [];
  Map<String, AttendanceStatus> _attendanceMap = {};
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Reload session from server to ensure proper types
      _session = await _sessionsService.getSession(widget.sessionId);
      
      // Load students for this group
      final students = await _studentsService.getAllStudents(
        group: _session?.groupName ?? '',
      );
      
      // Load existing attendance for this session
      final existingAttendance = await _attendanceService.getSessionAttendance(widget.sessionId);
      
      final Map<String, AttendanceStatus> attendanceMap = {};
      for (var a in existingAttendance) {
        attendanceMap[a.studentId] = a.status;
      }

      if (mounted) {
        setState(() {
          _students = students;
          _attendanceMap = attendanceMap;
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

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this session? Attendance will be finalized.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await _sessionsService.endSession(widget.sessionId);
      if (mounted) {
        context.pop(); // Go back to dashboard/sessions list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e')),
        );
      }
    }
  }

  Future<void> _markAttendance(String studentId, AttendanceStatus status) async {
    // Optimistic update
    final oldStatus = _attendanceMap[studentId];
    setState(() {
      _attendanceMap[studentId] = status;
    });

    try {
      await _attendanceService.markAttendance(
        sessionId: widget.sessionId,
        studentId: studentId,
        status: status,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        if (oldStatus != null) {
          _attendanceMap[studentId] = oldStatus;
        } else {
          _attendanceMap.remove(studentId);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark attendance: $e')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final isSessionActive = session?.status == SessionStatus.inProgress;

    return Scaffold(
      appBar: AppBar(
        title: session != null ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.moduleName, style: const TextStyle(fontSize: 16)),
            Text('${session.groupName} • ${session.typeString}', 
                 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ) : const Text('Attendance'),
        actions: [
          if (isSessionActive)
            TextButton.icon(
              onPressed: _isSaving ? null : _endSession,
              icon: const Icon(Icons.stop_circle, color: AppColors.error, size: 20),
              label: const Text('End', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(child: Text('No students found in this group.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final currentStatus = _attendanceMap[student.id];
        
        return _StudentAttendanceCard(
          student: student,
          currentStatus: currentStatus,
          onStatusChanged: (status) => _markAttendance(student.id, status),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final presentCount = _attendanceMap.values.where((s) => s == AttendanceStatus.present).length;
    final total = _students.length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progress', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('$presentCount / $total Present', 
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final Student student;
  final AttendanceStatus? currentStatus;
  final Function(AttendanceStatus) onStatusChanged;

  const _StudentAttendanceCard({
    required this.student,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(student.fullName.substring(0, 1), style: const TextStyle(color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(student.studentId ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          _buildStatusButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusButton(
          label: 'P',
          color: AppColors.success,
          isSelected: currentStatus == AttendanceStatus.present,
          onTap: () => onStatusChanged(AttendanceStatus.present),
        ),
        const SizedBox(width: 8),
        _StatusButton(
          label: 'L',
          color: AppColors.warning,
          isSelected: currentStatus == AttendanceStatus.late,
          onTap: () => onStatusChanged(AttendanceStatus.late),
        ),
        const SizedBox(width: 8),
        _StatusButton(
          label: 'A',
          color: AppColors.error,
          isSelected: currentStatus == AttendanceStatus.absent,
          onTap: () => onStatusChanged(AttendanceStatus.absent),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
