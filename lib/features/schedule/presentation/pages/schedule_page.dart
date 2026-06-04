import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/api/api.dart';
import '../../../../core/constants/app_colors.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Schedule> _schedules = [];
  List<Module> _modules = [];
  bool _isLoading = true;
  String _errorMessage = '';

  String? _typeFilter;
  String? _yearFilter;
  String? _dayFilter;

  final _scheduleService = ScheduleService();
  final _modulesService = ModulesService();
  final _sessionsService = SessionsService();

  final _years = ['L1', 'L2', 'L3', 'M1', 'M2'];
  final _types = ['cours', 'td', 'tp'];
  final _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final teacherId = ApiClient().user?.id;
      if (teacherId == null) throw 'Teacher ID not found.';
      final results = await Future.wait([
        _scheduleService.getTeacherSchedule(teacherId),
        _modulesService.getModulesByTeacher(teacherId),
      ]);
      if (mounted) {
        setState(() {
          _schedules = results[0] as List<Schedule>;
          _modules = results[1] as List<Module>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('Session expired') && mounted) { context.go('/login'); return; }
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  List<Schedule> get _filtered {
    return _schedules.where((s) {
      if (_typeFilter != null && s.type.toLowerCase() != _typeFilter!.toLowerCase()) return false;
      if (_yearFilter != null && s.year != _yearFilter) return false;
      if (_dayFilter != null && s.dayOfWeek != _dayFilter) return false;
      return true;
    }).toList();
  }

  String get _moduleLabel {
    final parts = <String>[];
    if (_typeFilter != null) parts.add(_typeFilter!.toUpperCase());
    if (_yearFilter != null) parts.add(_yearFilter!);
    if (_dayFilter != null) parts.add(_dayFilter!);
    return parts.isEmpty ? 'All schedules' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule'), actions: [
        IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: _filtersEmpty ? _loadData : _resetFilters),
        IconButton(icon: const Icon(Icons.add_rounded), onPressed: _showAddSheet),
      ]),
      body: _buildBody(),
    );
  }

  bool get _filtersEmpty => _typeFilter == null && _yearFilter == null && _dayFilter == null;

  void _resetFilters() => setState(() { _typeFilter = null; _yearFilter = null; _dayFilter = null; });

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
      const SizedBox(height: 16), Text(_errorMessage, style: const TextStyle(color: AppColors.error)),
      const SizedBox(height: 16), ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
    ]));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildFilters()),
        if (_filtered.isEmpty)
          const SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16), Text('No schedules match your filters', style: TextStyle(color: AppColors.textMuted)),
          ])))
        else ...[
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_moduleLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              Text('${_filtered.length} schedule${_filtered.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ]),
          )),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final schedule = _filtered[index];
              return _ScheduleCard(
                schedule: schedule,
                onStart: () => _startSession(schedule),
                onDelete: () => _deleteSchedule(schedule),
              ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1);
            }, childCount: _filtered.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ]),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(children: [
        Expanded(child: _buildDropdown('Type', _types.map((t) => (t.toUpperCase(), t)).toList(), _typeFilter, (v) => setState(() => _typeFilter = v))),
        const SizedBox(width: 12),
        Expanded(child: _buildDropdown('Year', _years.map((y) => (y, y)).toList(), _yearFilter, (v) => setState(() => _yearFilter = v))),
        const SizedBox(width: 12),
        Expanded(child: _buildDropdown('Day', _days.map((d) => (d.substring(0, 3), d)).toList(), _dayFilter, (v) => setState(() => _dayFilter = v))),
      ]),
    );
  }

  Widget _buildDropdown(String label, List<(String, String)> options, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value,
        hint: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 18),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        items: [const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
          ...options.map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1))),
        ],
        onChanged: onChanged,
      )),
    );
  }

  Future<void> _startSession(Schedule schedule) async {
    try {
      setState(() => _isLoading = true);
      final session = await _sessionsService.startSessionFromSchedule(schedule.id);
      if (mounted) context.push('/sessions/attendance/${session.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) _loadData();
    }
  }

  Future<void> _deleteSchedule(Schedule schedule) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Schedule'),
      content: Text('Remove "${schedule.moduleName}" on ${schedule.dayOfWeek}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Delete')),
      ],
    ));
    if (confirm != true) return;
    try {
      await _scheduleService.deleteSchedule(schedule.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule deleted'))); _loadData(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => _AddScheduleSheet(
        modules: _modules,
        onSaved: () { Navigator.pop(sheetContext); _loadData(); },
        onModuleCreated: () => _loadModules(),
      ),
    );
  }

  Future<void> _loadModules() async {
    try {
      final modules = await _modulesService.getAllModules();
      if (mounted) setState(() => _modules = modules);
    } catch (_) {}
  }
}

class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _ScheduleCard({required this.schedule, required this.onStart, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (schedule.type.toUpperCase()) { 'TD' => AppColors.success, 'TP' => Colors.blue, _ => AppColors.primary };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 4, height: 72, decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(schedule.type.toUpperCase(), style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold))),
              Text(schedule.year, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              if (schedule.groupName.isNotEmpty) Text('• ${schedule.groupName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 6),
            Text(schedule.moduleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('${schedule.startTime} - ${schedule.endTime}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.room, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(schedule.room, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
            onSelected: (v) => v == 'start' ? onStart() : onDelete(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'start', child: Row(children: [Icon(Icons.play_arrow, size: 18, color: AppColors.success), SizedBox(width: 8), Text('Start Session')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Delete')])),
            ],
          ),
        ]),
      ),
    );
  }
}

class _AddScheduleSheet extends StatefulWidget {
  final List<Module> modules;
  final VoidCallback onSaved;
  final VoidCallback onModuleCreated;

  const _AddScheduleSheet({required this.modules, required this.onSaved, required this.onModuleCreated});

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _error;

  String? _moduleId;
  String _type = 'cours';
  String _year = 'L1';
  String? _group;
  String _dayOfWeek = 'Monday';
  final _startTimeController = TextEditingController(text: '08:00');
  final _endTimeController = TextEditingController(text: '09:30');
  final _roomController = TextEditingController();

  final _scheduleService = ScheduleService();

  final _years = ['L1', 'L2', 'L3', 'M1', 'M2'];
  final _types = ['cours', 'td', 'tp'];
  final _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  bool get _showGroup => _type == 'td' || _type == 'tp';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      final teacherId = ApiClient().user?.id ?? '';
      if (teacherId.isEmpty) throw 'Teacher ID not found. Please re-login.';
      await _scheduleService.createSchedule({
        'teacherId': teacherId,
        'moduleId': _moduleId,
        'type': _type,
        'year': _year,
        'group': _showGroup ? _group : null,
        'dayOfWeek': _dayOfWeek,
        'startTime': _startTimeController.text,
        'endTime': _endTimeController.text,
        'room': _roomController.text,
      });
      widget.onSaved();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCreateModule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _CreateModuleSheet(
        onCreated: (module) {
          Navigator.pop(sheetCtx);
          widget.onModuleCreated();
          setState(() => _moduleId = module.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('New Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            const Text('Add a recurring class to your timetable.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            if (_error != null) Container(
              width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
            Row(children: [
              Expanded(child: _buildDropdown('Module', widget.modules.map((m) => (m.name, m.id)).toList(), _moduleId, (v) => setState(() => _moduleId = v))),
              const SizedBox(width: 8),
              IconButton(onPressed: _showCreateModule, icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), tooltip: 'New Module'),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _buildDropdown('Type', _types.map((t) => (t.toUpperCase(), t)).toList(), _type, (v) => setState(() => _type = v!))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('Year', _years.map((y) => (y, y)).toList(), _year, (v) => setState(() => _year = v!))),
            ]),
            const SizedBox(height: 16),
            if (_showGroup) TextFormField(
              decoration: const InputDecoration(labelText: 'Group', hintText: 'e.g. Group 2A'),
              onChanged: (v) => _group = v,
            ),
            if (_showGroup) const SizedBox(height: 16),
            _buildDropdown('Day', _days.map((d) => (d, d)).toList(), _dayOfWeek, (v) => setState(() => _dayOfWeek = v!)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _startTimeController, decoration: const InputDecoration(labelText: 'Start Time'), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: AppColors.textMuted))),
              Expanded(child: TextFormField(controller: _endTimeController, decoration: const InputDecoration(labelText: 'End Time'), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _roomController, decoration: const InputDecoration(labelText: 'Room', hintText: 'e.g. Room A101'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Create Schedule', style: TextStyle(fontSize: 16)),
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

class _CreateModuleSheet extends StatefulWidget {
  final void Function(Module module) onCreated;

  const _CreateModuleSheet({required this.onCreated});

  @override
  State<_CreateModuleSheet> createState() => _CreateModuleSheetState();
}

class _CreateModuleSheetState extends State<_CreateModuleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _year = 'L1';
  bool _isSaving = false;
  String? _error;

  final _modulesService = ModulesService();

  final _years = ['L1', 'L2', 'L3', 'M1', 'M2'];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      final teacherId = ApiClient().user?.id ?? '';
      if (teacherId.isEmpty) throw 'Teacher ID not found.';
      final module = await _modulesService.createModule({
        'name': _nameController.text.trim(),
        'year': _year,
        'teacherId': teacherId,
      });
      widget.onCreated(module);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('New Module', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 20),
            if (_error != null) Container(
              width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Module Name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null, autofocus: true),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _year, decoration: const InputDecoration(labelText: 'Year'),
              items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) => setState(() => _year = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Create Module', style: TextStyle(fontSize: 16)),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
