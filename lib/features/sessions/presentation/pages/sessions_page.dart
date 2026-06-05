import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/api/api.dart';
import '../../../../core/constants/app_colors.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Session> _sessions = [];
  List<Schedule> _schedules = [];
  List<Module> _modules = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _moduleFilter;

  final _sessionsService = SessionsService();
  final _scheduleService = ScheduleService();
  final _modulesService = ModulesService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final teacherId = ApiClient().user?.id ?? '';
      final results = await Future.wait([
        if (teacherId.isNotEmpty)
          _sessionsService.getTeacherSessions(teacherId)
        else
          Future.value(<Session>[]),
        if (teacherId.isNotEmpty) ...[
          _scheduleService.getTeacherSchedule(teacherId),
          _modulesService.getModulesByTeacher(teacherId),
        ] else ...[
          Future.value(<Schedule>[]),
          Future.value(<Module>[]),
        ],
      ]);
      if (mounted) {
        setState(() {
          _sessions = results[0] as List<Session>;
          _schedules = results.length > 1 ? results[1] as List<Schedule> : [];
          _modules = results.length > 2 ? results[2] as List<Module> : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('Session expired') && mounted) { context.go('/login'); return; }
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  List<dynamic> get _displayItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todaySessions = _sessions.where((s) =>
      DateTime(s.date.year, s.date.month, s.date.day) == today
    ).toList();

    final todaySessionScheduleIds = todaySessions
      .where((s) => s.scheduleId != null)
      .map((s) => s.scheduleId)
      .toSet();

    final items = <dynamic>[];
    items.addAll(_sessions);

    for (final schedule in _schedules) {
      if (!todaySessionScheduleIds.contains(schedule.id)) {
        final scheduleDate = today;
        final scheduleDayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];
        if (schedule.dayOfWeek == scheduleDayName) {
          items.add(_ScheduleOnlySession(schedule, date: scheduleDate));
        }
      }
    }

    return items;
  }

  List<dynamic> get _filteredItems {
    final items = _displayItems.where((item) {
      if (_moduleFilter != null) {
        final name = item is Session ? item.moduleName : (item as _ScheduleOnlySession).moduleName;
        if (name != _moduleFilter) return false;
      }

      if (_tabController.index == 0) {
        if (item is Session) return item.status == SessionStatus.planned || item.status == SessionStatus.inProgress;
        return true;
      } else if (_tabController.index == 1) {
        if (item is Session) return item.status == SessionStatus.completed;
        return false;
      } else {
        if (item is Session) return item.status == SessionStatus.canceled;
        return false;
      }
    }).toList();

    if (_tabController.index == 0) {
      items.sort((a, b) {
        final aStatus = a is Session ? a.status : SessionStatus.planned;
        final bStatus = b is Session ? b.status : SessionStatus.planned;
        if (aStatus == SessionStatus.inProgress && bStatus != SessionStatus.inProgress) return -1;
        if (bStatus == SessionStatus.inProgress && aStatus != SessionStatus.inProgress) return 1;
        final aDate = a is Session ? a.date : (a as _ScheduleOnlySession).date;
        final bDate = b is Session ? b.date : (b as _ScheduleOnlySession).date;
        final cmp = aDate.compareTo(bDate);
        if (cmp != 0) return cmp;
        final aTime = a is Session ? a.startTimeStr : (a as _ScheduleOnlySession).startTime;
        final bTime = b is Session ? b.startTimeStr : (b as _ScheduleOnlySession).startTime;
        return aTime.compareTo(bTime);
      });
    } else {
      items.sort((a, b) {
        final aDate = a is Session ? a.date : (a as _ScheduleOnlySession).date;
        final bDate = b is Session ? b.date : (b as _ScheduleOnlySession).date;
        return bDate.compareTo(aDate);
      });
    }

    return items;
  }

  Set<String> get _moduleNames {
    final names = <String>{};
    for (final s in _sessions) {
      if (s.moduleName.isNotEmpty) names.add(s.moduleName);
    }
    for (final module in _modules) {
      if (module.name.isNotEmpty) names.add(module.name);
    }
    return names;
  }

  Future<void> _startSession(dynamic item) async {
    try {
      setState(() => _isLoading = true);
      if (item is _ScheduleOnlySession) {
        final session = await _sessionsService.startSessionFromSchedule(item.scheduleId);
        if (mounted) context.push('/sessions/attendance/${session.id}');
      } else {
        final sessionId = item.id.toString();
        if (item.status == SessionStatus.planned) {
          await _sessionsService.updateSessionStatus(sessionId, 'active');
        }
        if (mounted) context.push('/sessions/attendance/$sessionId');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) _loadData();
    }
  }

  Future<void> _deleteSession(Session session) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Session'),
      content: Text('Delete "${session.moduleName}" on ${session.date.month}/${session.date.day}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Delete')),
      ],
    ));
    if (confirm != true) return;
    try {
      await _sessionsService.deleteSession(session.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session deleted'))); _loadData(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _showExtraSessionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ExtraSessionSheet(
        modules: _modules,
        onSaved: () { Navigator.pop(ctx); _loadData(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Canceled'),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExtraSessionSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Extra Session', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
        const SizedBox(height: 16), Text(_errorMessage, style: const TextStyle(color: AppColors.error)),
        const SizedBox(height: 16), ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
      ]));
    }

    final items = _filteredItems;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(slivers: [
        if (_moduleNames.isNotEmpty) SliverToBoxAdapter(child: _buildModuleFilter()),
        if (items.isEmpty)
          const SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16), Text('No sessions', style: TextStyle(color: AppColors.textMuted)),
          ])))
        else ...[
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text('${items.length} session${items.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          )),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return _SessionCardItem(
                item: item,
                onStart: () => _startSession(item),
                onDelete: item is Session ? () => _deleteSession(item) : null,
                onView: item is Session ? () => context.push('/sessions/attendance/${item.id}') : null,
              ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1);
            }, childCount: items.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ]),
    );
  }

  Widget _buildModuleFilter() {
    final names = _moduleNames.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _moduleFilter,
          hint: const Text('All Modules', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          items: [const DropdownMenuItem(value: null, child: Text('All Modules', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
            ...names.map((n) => DropdownMenuItem(value: n, child: Text(n))),
          ],
          onChanged: (v) => setState(() => _moduleFilter = v),
        )),
      ),
    );
  }
}

class _ScheduleOnlySession {
  final String scheduleId;
  final String moduleName;
  final String type;
  final String groupName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String room;

  _ScheduleOnlySession(Schedule s, {required this.date}) :
    scheduleId = s.id,
    moduleName = s.moduleName,
    type = s.type,
    groupName = s.groupName,
    startTime = s.startTime,
    endTime = s.endTime,
    room = s.room;

  String get timeRange => '$startTime - $endTime';
}

class _SessionCardItem extends StatelessWidget {
  final dynamic item;
  final VoidCallback onStart;
  final VoidCallback? onDelete;
  final VoidCallback? onView;

  const _SessionCardItem({required this.item, required this.onStart, this.onDelete, this.onView});

  @override
  Widget build(BuildContext context) {
    final isSchedule = item is _ScheduleOnlySession;
    final session = item is Session ? item as Session : null;

    final moduleName = isSchedule ? item.moduleName : session!.moduleName;
    final groupName = isSchedule ? item.groupName : session!.groupName;
    final type = isSchedule ? item.type : session!.type;
    final date = isSchedule ? item.date : session!.date;
    final startTime = isSchedule ? item.startTime : session!.startTimeStr;
    final endTime = isSchedule ? item.endTime : session!.endTimeStr;
    final room = isSchedule ? item.room : session!.room;
    final isReplacement = session?.isReplacement ?? false;

    SessionStatus status;
    int presentCount = 0, totalStudents = 0;
    if (isSchedule) {
      status = SessionStatus.planned;
    } else {
      status = session!.status;
      presentCount = session.presentCount;
      totalStudents = session.totalStudents;
    }

    final typeLabel = type is SessionType ? type.name.toUpperCase() : type.toString().toUpperCase();
    final typeColor = switch (typeLabel) { 'TD' => AppColors.success, 'TP' => Colors.blue, _ => AppColors.primary };

    Color statusColor;
    String statusText;
    Color statusBg;
    switch (status) {
      case SessionStatus.inProgress:
        statusColor = AppColors.success; statusText = 'Active'; statusBg = AppColors.successLight;
      case SessionStatus.completed:
        statusColor = AppColors.textSecondary; statusText = 'Completed'; statusBg = AppColors.background;
      case SessionStatus.canceled:
        statusColor = AppColors.error; statusText = 'Canceled'; statusBg = AppColors.errorLight;
      default:
        statusColor = AppColors.warning; statusText = 'Planned'; statusBg = AppColors.warningLight;
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: status == SessionStatus.inProgress ? AppColors.success.withValues(alpha: 0.4) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold))),
                if (isSchedule) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Schedule', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600))),
                if (isReplacement) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Extra', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 6),
              Text(moduleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('${months[date.month - 1]} ${date.day}, ${date.year} (${days[date.weekday % 7]})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 2),
              Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('$startTime - $endTime', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                ]),
                if (room.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.room, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Flexible(child: Text(room, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600))),
              if (status == SessionStatus.inProgress || status == SessionStatus.completed) ...[
                const SizedBox(height: 6),
                Text('$presentCount/$totalStudents', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
          if (groupName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(groupName, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 12),
          Row(children: [
            if (isSchedule || status == SessionStatus.planned)
              Expanded(child: SizedBox(height: 40, child: ElevatedButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Start'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
            if (status == SessionStatus.inProgress)
              Expanded(child: SizedBox(height: 40, child: ElevatedButton.icon(onPressed: onView, icon: const Icon(Icons.visibility, size: 18), label: const Text('Live'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
            if (status == SessionStatus.completed)
              Expanded(child: SizedBox(height: 40, child: OutlinedButton.icon(onPressed: onView, icon: const Icon(Icons.visibility, size: 18), label: const Text('View'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
            if (onDelete != null && (status == SessionStatus.planned || status == SessionStatus.canceled)) ...[
              const SizedBox(width: 8),
              SizedBox(height: 40, child: OutlinedButton(onPressed: onDelete, style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.errorLight), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Icon(Icons.delete_outline, size: 18))),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _ExtraSessionSheet extends StatefulWidget {
  final List<Module> modules;
  final VoidCallback onSaved;

  const _ExtraSessionSheet({required this.modules, required this.onSaved});

  @override
  State<_ExtraSessionSheet> createState() => _ExtraSessionSheetState();
}

class _ExtraSessionSheetState extends State<_ExtraSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _error;

  String? _moduleId;
  String _type = 'cours';
  String _year = 'L1';
  String? _group;
  String? _speciality;
  DateTime _date = DateTime.now();
  final _startTimeController = TextEditingController(text: '08:00');
  final _endTimeController = TextEditingController(text: '09:30');
  final _reasonController = TextEditingController();

  final _sessionsService = SessionsService();
  final _types = ['cours', 'td', 'tp'];
  final _years = ['L1', 'L2', 'L3', 'M1', 'M2'];

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime(2027));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      final teacherId = ApiClient().user?.id ?? '';
      if (teacherId.isEmpty) throw 'Teacher ID not found.';
      await _sessionsService.createSession({
        'teacherId': teacherId,
        'moduleId': _moduleId,
        'type': _type,
        'date': _date.toIso8601String().split('T')[0],
        'startTime': _startTimeController.text,
        'endTime': _endTimeController.text,
        'year': _year,
        'group': _group,
        'speciality': _speciality?.isNotEmpty == true ? _speciality : null,
        'isReplacement': true,
        'reasonForReplacement': _reasonController.text.isNotEmpty ? _reasonController.text : 'Extra session',
        'status': 'planned',
      });
      widget.onSaved();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Extra Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 4),
            const Text('Create a one-time session outside your schedule.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            if (_error != null) Container(
              width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
            _buildDropdown('Module', widget.modules.map((m) => (m.name, m.id)).toList(), _moduleId, (v) => setState(() => _moduleId = v)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _buildDropdown('Type', _types.map((t) => (t.toUpperCase(), t)).toList(), _type, (v) => setState(() => _type = v!))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('Year', _years.map((y) => (y, y)).toList(), _year, (v) => setState(() => _year = v!))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Group (optional)'), onChanged: (v) => _group = v)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Speciality (optional)'), onChanged: (v) => _speciality = v)),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text('${months[_date.month - 1]} ${_date.day}, ${_date.year}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _startTimeController, decoration: const InputDecoration(labelText: 'Start'), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: AppColors.textMuted))),
              Expanded(child: TextFormField(controller: _endTimeController, decoration: const InputDecoration(labelText: 'End'), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _reasonController, decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'e.g. Replacement class')),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Create Session', style: TextStyle(fontSize: 16)),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<(String, String)> options, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value,
        hint: Text(label, style: const TextStyle(color: AppColors.textMuted)),
        isExpanded: true,
        style: const TextStyle(color: AppColors.textPrimary),
        items: options.map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1))).toList(),
        onChanged: onChanged,
      )),
    );
  }
}
