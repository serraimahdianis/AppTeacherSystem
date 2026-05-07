import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  Session? _session;
  List<Student> _students = [];
  Map<String, AttendanceStatus> _attendanceMap = {};
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSaving = false;

  // QR code refresh timer
  Timer? _qrRefreshTimer;
  int _qrTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    super.dispose();
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
      final existingAttendance =
          await _attendanceService.getSessionAttendance(widget.sessionId);

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
        content: const Text(
            'Are you sure you want to end this session? '
            'Attendance will be finalized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
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
        context.pop();
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

  Future<void> _markAttendance(
      String studentId, AttendanceStatus status) async {
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
      if (mounted) {
        setState(() {
          if (oldStatus != null) {
            _attendanceMap[studentId] = oldStatus;
          } else {
            _attendanceMap.remove(studentId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark attendance: $e')),
        );
      }
    }
  }

  /// Generate QR code data string with session info and timestamp
  String _generateQrData() {
    return jsonEncode({
      'sessionId': widget.sessionId,
      'type': 'attendance',
      'timestamp': _qrTimestamp,
    });
  }

  /// Show the QR code dialog for students to scan
  void _showQrCodeDialog() {
    // Set initial timestamp
    _qrTimestamp =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Refresh QR code every 30 seconds for security
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _qrTimestamp =
              DateTime.now().millisecondsSinceEpoch ~/ 1000;
        });
      } else {
        timer.cancel();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _QrCodeDialog(
          session: _session,
          qrData: _generateQrData(),
          onClose: () {
            _qrRefreshTimer?.cancel();
            Navigator.pop(dialogContext);
            // Reload attendance data after QR display
            _loadData();
          },
        );
      },
    ).then((_) {
      // Cleanup timer when dialog is closed any way
      _qrRefreshTimer?.cancel();
      // Refresh attendance list after students may have scanned
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final isSessionActive =
        session?.status == SessionStatus.inProgress;

    return Scaffold(
      appBar: AppBar(
        title: session != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.moduleName,
                      style: const TextStyle(fontSize: 16)),
                  Text(
                    '${session.groupName} • ${session.typeString}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              )
            : const Text('Attendance'),
        actions: [
          // QR Code button — only show for active sessions
          if (isSessionActive)
            IconButton(
              onPressed: _showQrCodeDialog,
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'Show QR Code',
              style: IconButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          if (isSessionActive)
            TextButton.icon(
              onPressed: _isSaving ? null : _endSession,
              icon: const Icon(Icons.stop_circle,
                  color: AppColors.error, size: 20),
              label: const Text('End',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  )),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
      // FAB for quick QR access
      floatingActionButton: isSessionActive
          ? FloatingActionButton.extended(
              onPressed: _showQrCodeDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.qr_code_2,
                  color: Colors.white),
              label: const Text('Show QR',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
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
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(
        child: Text('No students found in this group.'),
      );
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
          onStatusChanged: (status) =>
              _markAttendance(student.id, status),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final presentCount = _attendanceMap.values
        .where((s) => s == AttendanceStatus.present)
        .length;
    final lateCount = _attendanceMap.values
        .where((s) => s == AttendanceStatus.late)
        .length;
    final absentCount = _attendanceMap.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
    final total = _students.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progress',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    )),
                Row(
                  children: [
                    Text(
                      '${presentCount + lateCount}/$total',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'P',
                      count: presentCount,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    _MiniStat(
                      label: 'L',
                      count: lateCount,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    _MiniStat(
                      label: 'A',
                      count: absentCount,
                      color: AppColors.error,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- QR Code Dialog ---

class _QrCodeDialog extends StatelessWidget {
  final Session? session;
  final String qrData;
  final VoidCallback onClose;

  const _QrCodeDialog({
    required this.session,
    required this.qrData,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth * 0.65).clamp(200.0, 320.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scan to Mark Attendance',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (session != null)
                              Text(
                                '${session!.moduleName} • '
                                '${session!.typeString}',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close,
                            color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            session!.groupName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.room_outlined,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            session!.room,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // QR Code area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border,
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: qrSize,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primaryDark,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            // Instructions
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Students open their app and scan '
                        'this QR code to mark present.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Auto-refresh notice
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'QR refreshes every 30s for security',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Mini Stat Pill (Bottom bar) ---

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label:$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// --- Student Attendance Card ---

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
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              student.fullName.substring(0, 1),
              style:
                  const TextStyle(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                Text(student.studentId ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    )),
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
          isSelected:
              currentStatus == AttendanceStatus.present,
          onTap: () =>
              onStatusChanged(AttendanceStatus.present),
        ),
        const SizedBox(width: 8),
        _StatusButton(
          label: 'L',
          color: AppColors.warning,
          isSelected:
              currentStatus == AttendanceStatus.late,
          onTap: () =>
              onStatusChanged(AttendanceStatus.late),
        ),
        const SizedBox(width: 8),
        _StatusButton(
          label: 'A',
          color: AppColors.error,
          isSelected:
              currentStatus == AttendanceStatus.absent,
          onTap: () =>
              onStatusChanged(AttendanceStatus.absent),
        ),
      ],
    );
  }
}

// --- Status Button ---

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
          border: Border.all(
            color: isSelected ? color : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : AppColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
