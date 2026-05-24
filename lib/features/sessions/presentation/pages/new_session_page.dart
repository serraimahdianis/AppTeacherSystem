import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class NewSessionPage extends StatefulWidget {
  const NewSessionPage({super.key});

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _sessionsService = SessionsService();
  final _modulesService = ModulesService();
  final _schedulesService = ScheduleService();

  List<Module> _modules = [];
  List<Schedule> _schedules = [];
  Module? _selectedModule;
  Schedule? _selectedSchedule;

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  String _type = 'cours';
  String _group = '';
  String _status = 'planned';
  bool _isReplacement = false;
  String _reason = '';

  bool _isLoading = false;
  bool _isSaving = false;

  final _groupController = TextEditingController();
  final _reasonController = TextEditingController();

  final _types = ['cours', 'td', 'tp'];
  final _statuses = ['planned', 'active', 'closed'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _groupController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teacherId = ApiClient().user?.id ?? '';
      final results = await Future.wait([
        _modulesService.getModulesByTeacher(teacherId),
        _schedulesService.getAllSchedules(),
      ]);

      if (mounted) {
        setState(() {
          _modules = results[0] as List<Module>;
          _schedules = results[1] as List<Schedule>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedModule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a module')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final teacherId = ApiClient().user?.id ?? '';
      await _sessionsService.createSession({
        'teacherId': teacherId,
        'moduleId': _selectedModule!.id,
        'date': _formatDate(_date),
        'startTime': _formatTime(_startTime),
        'endTime': _formatTime(_endTime),
        'type': _type,
        'group': _group.isEmpty ? null : _group,
        'scheduleId': _selectedSchedule?.id,
        'status': _status,
        'isReplacement': _isReplacement,
        if (_isReplacement && _reason.isNotEmpty) 'reasonForReplacement': _reason,
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create session: $e')),
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
        title: const Text('New Session'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSession,
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
                    label: 'Module *',
                    value: _selectedModule,
                    items: _modules,
                    itemLabel: (m) => m.toString(),
                    onChanged: (v) => setState(() => _selectedModule = v),
                    validator: (_) => _selectedModule == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<Schedule>(
                    label: 'Link to Schedule (optional)',
                    value: _selectedSchedule,
                    items: _schedules,
                    itemLabel: (s) => '${s.moduleName} - ${s.dayOfWeek} (${s.startTime}-${s.endTime})',
                    onChanged: (v) => setState(() => _selectedSchedule = v),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'Start Time *',
                          time: _startTime,
                          onTap: () => _selectTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          label: 'End Time *',
                          time: _endTime,
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    label: 'Type *',
                    value: _type,
                    items: _types,
                    itemLabel: (t) => t.toUpperCase(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _groupController,
                    decoration: const InputDecoration(
                      labelText: 'Group (optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _group = v,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<String>(
                    label: 'Status *',
                    value: _status,
                    items: _statuses,
                    itemLabel: (s) => s[0].toUpperCase() + s.substring(1),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _isReplacement,
                    onChanged: (v) => setState(() => _isReplacement = v ?? false),
                    title: const Text('Is Replacement Session'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isReplacement) ...[
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Replacement',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (v) => _reason = v,
                    ),
                  ],
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
