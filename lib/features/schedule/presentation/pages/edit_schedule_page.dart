import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class EditSchedulePage extends StatefulWidget {
  final String scheduleId;
  const EditSchedulePage({super.key, required this.scheduleId});

  @override
  State<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends State<EditSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleService = ScheduleService();
  final _modulesService = ModulesService();

  List<Module> _modules = [];
  Module? _selectedModule;

  String _type = 'cours';
  String _year = 'L2';
  String _group = '';
  String _dayOfWeek = 'Monday';
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  String _room = '';

  bool _isLoading = true;
  bool _isSaving = false;

  final _groupController = TextEditingController();
  final _roomController = TextEditingController();

  final _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final _types = ['cours', 'td', 'tp'];
  final _years = ['L1', 'L2', 'L3', 'M1', 'M2'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _groupController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teacherId = ApiClient().user?.id ?? '';
      final results = await Future.wait([
        _scheduleService.getAllSchedules(),
        _modulesService.getModulesByTeacher(teacherId),
      ]);

      final schedules = results[0] as List<Schedule>;
      final modules = results[1] as List<Module>;

      final schedule = schedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => throw Exception('Schedule not found'),
      );

      final module = modules.firstWhere(
        (m) => m.name == schedule.moduleName,
        orElse: () => modules.isNotEmpty ? modules.first : Module(id: '', name: '', teacherId: '', year: ''),
      );

      if (mounted) {
        setState(() {
          _modules = modules;
          _selectedModule = module;

        _type = schedule.type.toLowerCase();
        _year = schedule.year;
        _group = schedule.groupName;
        _dayOfWeek = schedule.dayOfWeek;
        _startTime = _parseTimeString(schedule.startTime);
        _endTime = _parseTimeString(schedule.endTime);
        _room = schedule.room;

        _groupController.text = _group;
        _roomController.text = _room;

        _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedule: $e')),
        );
        context.pop();
      }
    }
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedModule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a module')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _scheduleService.updateSchedule(widget.scheduleId, {
        'teacherId': ApiClient().user?.id ?? '',
        'moduleId': _selectedModule!.id,
        'type': _type,
        'year': _year,
        'group': _type == 'cours' ? null : _group,
        'dayOfWeek': _dayOfWeek,
        'startTime': _formatTime(_startTime),
        'endTime': _formatTime(_endTime),
        'room': _room,
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await _scheduleService.deleteSchedule(widget.scheduleId);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Schedule'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: _isSaving ? null : _deleteSchedule,
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveSchedule,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDropdown<Module>(
                    label: 'Module',
                    value: _selectedModule,
                    items: _modules,
                    itemLabel: (m) => m.toString(),
                    onChanged: (v) => setState(() => _selectedModule = v),
                    validator: (_) => _selectedModule == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    label: 'Type',
                    value: _type,
                    items: _types,
                    itemLabel: (t) => t.toUpperCase(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    label: 'Year',
                    value: _year,
                    items: _years,
                    itemLabel: (y) => y,
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _groupController,
                    decoration: const InputDecoration(
                      labelText: 'Group (optional for Cours)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _group = v,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    label: 'Day of Week',
                    value: _dayOfWeek,
                    items: _days,
                    itemLabel: (d) => d,
                    onChanged: (v) => setState(() => _dayOfWeek = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'Start Time',
                          time: _startTime,
                          onTap: () => _selectTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          label: 'End Time',
                          time: _endTime,
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    onChanged: (v) => _room = v,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(itemLabel(item)),
      )).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
      ),
      controller: TextEditingController(
        text: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      ),
    );
  }
}
