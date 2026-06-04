import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';
import '../../../../core/socket/socket_service.dart';

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
  final _socketService = SocketService();

  Session? _session;
  List<Student> _students = [];
  Map<String, AttendanceStatus> _attendanceMap = {};
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSaving = false;
  String _searchQuery = '';

  Timer? _elapsedTimer;
  DateTime? _sessionStart;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _socketService.connect();
    _socketService.joinSession(widget.sessionId);
    _socketService.onAttendanceScan = ({required String sessionId, required String studentId, required String studentName, required String status, required String scanTime}) {
      if (mounted) setState(() => _attendanceMap[studentId] = _parseStatus(status));
    };
    _socketService.onAttendanceStatusChanged = ({required String sessionId, required String studentId, required String newStatus}) {
      if (mounted) setState(() => _attendanceMap[studentId] = _parseStatus(newStatus));
    };
  }

  AttendanceStatus _parseStatus(String status) {
    switch (status) {
      case 'present': return AttendanceStatus.present;
      case 'late': return AttendanceStatus.late;
      default: return AttendanceStatus.absent;
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _socketService.leaveSession(widget.sessionId);
    _socketService.onAttendanceScan = null;
    _socketService.onAttendanceStatusChanged = null;
    super.dispose();
  }

  void _startTimer() {
    if (_session?.status == SessionStatus.inProgress) {
      _sessionStart = DateTime.now();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _sessionStart != null) {
          setState(() => _elapsed = DateTime.now().difference(_sessionStart!));
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      _session = await _sessionsService.getSession(widget.sessionId);
      final students = await _studentsService.getAllStudents(
        group: _session?.groupName ?? '',
        year: _session?.year ?? '',
      );
      final existingAttendance = await _attendanceService.getSessionAttendance(widget.sessionId);
      final attendanceMap = <String, AttendanceStatus>{};
      for (var a in existingAttendance) {
        attendanceMap[a.studentId] = a.status;
      }
      if (mounted) {
        setState(() {
          _students = students;
          _attendanceMap = attendanceMap;
          _isLoading = false;
        });
        if (_session?.status == SessionStatus.inProgress) _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('End Session'),
      content: const Text('Attendance will be finalized.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('End Session')),
      ],
    ));
    if (confirm != true) return;
    setState(() => _isSaving = true);
    try {
      await _sessionsService.endSession(widget.sessionId);
      _elapsedTimer?.cancel();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) { setState(() => _isSaving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
    }
  }

  Future<void> _markAttendance(String studentId, AttendanceStatus status) async {
    final oldStatus = _attendanceMap[studentId];
    setState(() => _attendanceMap[studentId] = status);
    try {
      await _attendanceService.markAttendance(sessionId: widget.sessionId, studentId: studentId, status: status);
    } catch (e) {
      if (mounted) {
        setState(() { if (oldStatus != null) { _attendanceMap[studentId] = oldStatus; } else { _attendanceMap.remove(studentId); } });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showTeacherScannerDialog() {
    showDialog(context: context, barrierDismissible: true,
      builder: (ctx) => _TeacherScannerDialog(sessionId: widget.sessionId, onClose: () => Navigator.pop(ctx),
        onScanSuccess: (name, status) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name — $status'))); },
        getScanStatus: () {
          if (_session == null) return AttendanceStatus.present;
          final now = DateTime.now();
          final startMins = _session!.startTime.hour * 60 + _session!.startTime.minute;
          return now.hour * 60 + now.minute > startMins + 15 ? AttendanceStatus.late : AttendanceStatus.present;
        },
      ));
  }

  int get _presentCount => _attendanceMap.values.where((s) => s == AttendanceStatus.present).length;
  int get _lateCount => _attendanceMap.values.where((s) => s == AttendanceStatus.late).length;
  int get _absentCount => _attendanceMap.values.where((s) => s == AttendanceStatus.absent).length;

  String get _elapsedStr {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final isActive = session?.status == SessionStatus.inProgress;

    return Scaffold(
      appBar: AppBar(
        title: session != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.moduleName, style: const TextStyle(fontSize: 16)),
                Text('${session.groupName} • ${session.typeString}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
              ])
            : const Text('Attendance'),
        actions: [
          if (isActive) ...[
            TextButton.icon(
              onPressed: _isSaving ? null : _endSession,
              icon: const Icon(Icons.stop_circle, color: AppColors.error, size: 20),
              label: const Text('End', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
      // Primary action: teacher scans student QR codes
      floatingActionButton: isActive
          ? FloatingActionButton.extended(
              onPressed: _showTeacherScannerDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Scan Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final isActive = _session?.status == SessionStatus.inProgress;
    final filtered = _students.where((s) => s.fullName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return CustomScrollView(slivers: [
      // Session info header
      SliverToBoxAdapter(child: _buildSessionHeader(context, isActive)),
      // Stats row
      SliverToBoxAdapter(child: _buildStatsRow()),
      // Pie chart
      SliverToBoxAdapter(child: _buildPieChart()),
      // Search
      SliverToBoxAdapter(child: _buildSearch()),
      // Student list
      if (filtered.isEmpty)
        const SliverFillRemaining(child: Center(child: Text('No students', style: TextStyle(color: AppColors.textMuted))))
      else
        SliverList(delegate: SliverChildBuilderDelegate((context, index) {
          final student = filtered[index];
          final status = _attendanceMap[student.id];
          return _StudentAttendanceCard(student: student, currentStatus: status, isActive: isActive,
            onStatusChanged: (s) => _markAttendance(student.id, s),
          ).animate().fade(delay: (50 * index).ms).slideY(begin: 0.1);
        }, childCount: filtered.length)),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
    ]);
  }

  Widget _buildSessionHeader(BuildContext context, bool isActive) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive ? AppColors.primaryGradient : const LinearGradient(colors: [AppColors.textSecondary, AppColors.textMuted]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_session!.typeString, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_session!.moduleName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.people_outline, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(_session!.groupName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 16),
            const Icon(Icons.room_outlined, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(_session!.room, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(_session!.timeRange, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          if (isActive) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _showTeacherScannerDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Scan Student QR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            ),
          ],
        ])),
        if (isActive) Column(children: [
          Text(_elapsedStr, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
          const Text('elapsed', style: TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final total = _students.length;
    final marked = _presentCount + _lateCount + _absentCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _StatPill(label: 'Present', count: _presentCount, color: AppColors.success),
        _StatPill(label: 'Late', count: _lateCount, color: AppColors.warning),
        _StatPill(label: 'Absent', count: _absentCount, color: AppColors.error),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Text('$marked/$total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    );
  }

  Widget _buildPieChart() {
    final total = _presentCount + _lateCount + _absentCount;
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        height: 140,
        child: Row(children: [
          SizedBox(width: 100, height: 100, child: PieChart(PieChartData(
            sectionsSpace: 2, centerSpaceRadius: 28,
            sections: [
              if (_presentCount > 0) PieChartSectionData(value: _presentCount.toDouble(), color: AppColors.success, radius: 32, title: '${(_presentCount / total * 100).round()}%', titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              if (_lateCount > 0) PieChartSectionData(value: _lateCount.toDouble(), color: AppColors.warning, radius: 32, title: '${(_lateCount / total * 100).round()}%', titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              if (_absentCount > 0) PieChartSectionData(value: _absentCount.toDouble(), color: AppColors.error, radius: 32, title: '${(_absentCount / total * 100).round()}%', titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ))),
          const SizedBox(width: 16),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LegendRow(color: AppColors.success, label: 'Present', value: '$_presentCount'),
            const SizedBox(height: 4),
            _LegendRow(color: AppColors.warning, label: 'Late', value: '$_lateCount'),
            const SizedBox(height: 4),
            _LegendRow(color: AppColors.error, label: 'Absent', value: '$_absentCount'),
          ])),
        ]),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search students...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = '')) : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)))),
      child: SafeArea(child: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Progress', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
              Text('${_presentCount + _lateCount}/${_students.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              _MiniStat(label: 'P', count: _presentCount, color: AppColors.success),
              _MiniStat(label: 'L', count: _lateCount, color: AppColors.warning),
              _MiniStat(label: 'A', count: _absentCount, color: AppColors.error),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        ElevatedButton(onPressed: () => context.pop(), child: const Text('Done')),
      ])),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label; final int count; final Color color;
  const _StatPill({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$count', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color; final String label; final String value;
  const _LegendRow({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), const Spacer(),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label; final int count; final Color color;
  const _MiniStat({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text('$label:$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }
}



// --- Student Attendance Card ---

class _StudentAttendanceCard extends StatelessWidget {
  final Student student;
  final AttendanceStatus? currentStatus;
  final bool isActive;
  final Function(AttendanceStatus) onStatusChanged;

  const _StudentAttendanceCard({required this.student, required this.currentStatus, required this.isActive, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: currentStatus == AttendanceStatus.present ? AppColors.success.withValues(alpha: 0.3) : (currentStatus == AttendanceStatus.late ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border)),
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
          if (student.studentId != null && student.studentId!.isNotEmpty)
            Text(student.studentId!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
        if (isActive) _buildStatusButtons(),
      ]),
    );
  }

  Widget _buildStatusButtons() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _StatusButton(label: 'P', color: AppColors.success, isSelected: currentStatus == AttendanceStatus.present, onTap: () => onStatusChanged(AttendanceStatus.present)),
      const SizedBox(width: 6),
      _StatusButton(label: 'L', color: AppColors.warning, isSelected: currentStatus == AttendanceStatus.late, onTap: () => onStatusChanged(AttendanceStatus.late)),
      const SizedBox(width: 6),
      _StatusButton(label: 'A', color: AppColors.error, isSelected: currentStatus == AttendanceStatus.absent, onTap: () => onStatusChanged(AttendanceStatus.absent)),
    ]);
  }
}

class _StatusButton extends StatelessWidget {
  final String label; final Color color; final bool isSelected; final VoidCallback onTap;
  const _StatusButton({required this.label, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: isSelected ? color : Colors.transparent, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : []),
        child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 14))),
      ),
    );
  }
}

// --- Teacher Scanner Dialog ---

class _TeacherScannerDialog extends StatefulWidget {
  final String sessionId;
  final VoidCallback onClose;
  final Function(String, String) onScanSuccess;
  final AttendanceStatus Function() getScanStatus;

  const _TeacherScannerDialog({required this.sessionId, required this.onClose, required this.onScanSuccess, required this.getScanStatus});

  @override
  State<_TeacherScannerDialog> createState() => _TeacherScannerDialogState();
}

class _TeacherScannerDialogState extends State<_TeacherScannerDialog> with SingleTickerProviderStateMixin {
  final _studentsService = StudentsService();
  final _attendanceService = AttendanceService();
  late final MobileScannerController _scannerController;
  late final TabController _tabController;
  final _manualController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isProcessing = false;
  String _message = 'Point camera at student QR code';
  bool _isError = false;
  bool _isSuccess = false;
  final List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _tabController.dispose();
    _manualController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processCode(String code) async {
    if (_isProcessing || code.trim().isEmpty) return;
    setState(() { _isProcessing = true; _message = 'Looking up student...'; _isError = false; _isSuccess = false; });
    try {
      final student = await _studentsService.getStudentByRfid(code.trim());
      final status = widget.getScanStatus();
      await _attendanceService.markAttendance(sessionId: widget.sessionId, studentId: student.id, status: status);
      final label = status == AttendanceStatus.late ? 'Late' : 'Present';
      widget.onScanSuccess(student.fullName, label);
      if (mounted) {
        setState(() {
          _message = '✓ ${student.fullName} — $label';
          _isSuccess = true;
          _recentScans.insert(0, {'name': student.fullName, 'status': label, 'id': student.studentId ?? ''});
          if (_recentScans.length > 5) _recentScans.removeLast();
          _manualController.clear();
        });
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _isProcessing = false; _message = 'Point camera at student QR code'; _isSuccess = false; });
      });
    } catch (e) {
      if (mounted) setState(() { _message = e.toString().replaceAll('Exception: ', ''); _isError = true; });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() { _message = 'Point camera at student QR code'; _isError = false; _isProcessing = false; });
      });
    }
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;
    _processCode(barcodes.first.rawValue!);
  }

  Color get _statusColor => _isError ? AppColors.error : (_isSuccess ? AppColors.success : AppColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 50, offset: const Offset(0, 15))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Scan Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Mark attendance by scanning QR code', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15))),
              ]),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.camera_alt, size: 18), text: 'Camera'),
                  Tab(icon: Icon(Icons.keyboard, size: 18), text: 'Manual Entry'),
                ],
              ),
            ]),
          ),

          // Tab Content
          SizedBox(
            height: 300,
            child: TabBarView(controller: _tabController, children: [
              // --- Camera Tab ---
              Stack(alignment: Alignment.center, children: [
                ClipRRect(child: MobileScanner(controller: _scannerController, onDetect: _handleDetect)),
                // Aim overlay with corner accents
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _isSuccess ? AppColors.success : (_isError ? AppColors.error : Colors.white), width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      // Corner accents
                      ...[-1, 1].expand((hSign) => [-1, 1].map((vSign) => Positioned(
                        left: hSign == -1 ? 0 : null,
                        right: hSign == 1 ? 0 : null,
                        top: vSign == -1 ? 0 : null,
                        bottom: vSign == 1 ? 0 : null,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border(
                              left: hSign == -1 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
                              right: hSign == 1 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
                              top: vSign == -1 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
                              bottom: vSign == 1 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
                            ),
                          ),
                        ),
                      ))),
                    ],
                  ),
                ),
                if (_isProcessing && !_isSuccess && !_isError)
                  Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
              ]),

              // --- Manual Entry Tab ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(children: [
                  const Text('Enter student ID, RFID code, or QR value', textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _processCode,
                    decoration: InputDecoration(
                      hintText: 'e.g. ST1001 or scan code...',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      suffixIcon: _isProcessing
                          ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : IconButton(
                              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                              onPressed: () => _processCode(_manualController.text),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _processCode(_manualController.text),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Attendance'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          // Status bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _isError ? AppColors.error.withValues(alpha: 0.08) : (_isSuccess ? AppColors.success.withValues(alpha: 0.08) : Colors.transparent),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_isSuccess) const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              if (_isError) const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              if (_isSuccess || _isError) const SizedBox(width: 8),
              Flexible(child: Text(_message, textAlign: TextAlign.center,
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
          ),

          // Recent scans history
          if (_recentScans.isNotEmpty) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(children: [
                Icon(Icons.history, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('Recent', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            ...(_recentScans.take(3).map((scan) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: scan['status'] == 'Present' ? AppColors.success : AppColors.warning,
                  shape: BoxShape.circle,
                )),
                const SizedBox(width: 10),
                Expanded(child: Text(scan['name'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (scan['status'] == 'Present' ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(scan['status'] as String,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: scan['status'] == 'Present' ? AppColors.success : AppColors.warning)),
                ),
              ]),
            ))),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

