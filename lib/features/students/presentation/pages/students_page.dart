import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _searchController = TextEditingController();
  String _selectedYear = '';
  String _selectedGroup = '';
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  List<String> _uniqueYears = [];
  List<String> _uniqueGroups = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final _studentsService = StudentsService();

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

    await _loadStudents();
  }

  Future<void> _loadStudents({String? group, String? year}) async {
    try {
      final students = await _studentsService.getAllStudents(
        group: group,
        year: year,
      );
      if (mounted) {
        setState(() {
          _allStudents = students;
          final years = students.map((s) => s.year ?? '').where((y) => y.isNotEmpty).toSet().toList()..sort();
          _uniqueYears = years;
          final groups = students.map((s) => s.group).toSet().toList()..sort();
          _uniqueGroups = groups;
          _filter();
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



  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final matchesSearch = query.isEmpty ||
            student.fullName.toLowerCase().contains(query) ||
            (student.studentId?.toLowerCase().contains(query) ?? false) ||
            student.email.toLowerCase().contains(query) ||
            (student.rfidCode?.toLowerCase().contains(query) ?? false);
        final matchesYear = _selectedYear.isEmpty || student.year == _selectedYear;
        final matchesGroup = _selectedGroup.isEmpty || student.group == _selectedGroup;
        return matchesSearch && matchesYear && matchesGroup;
      }).toList();
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedYear = '';
      _selectedGroup = '';
    });
    _loadStudents();
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty ||
      _selectedYear.isNotEmpty ||
      _selectedGroup.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          _buildSearchAndFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_filteredStudents.length}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                '${_allStudents.length} total students',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          if (_hasActiveFilters)
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 14, color: AppColors.error),
                    SizedBox(width: 4),
                    Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, ID, email, or RFID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _filter();
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (_) => _filter(),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 340;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            value: _selectedYear,
                            hint: 'All Years',
                            items: _uniqueYears,
                            onChanged: (v) {
                              setState(() => _selectedYear = v);
                              _filter();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            value: _selectedGroup,
                            hint: 'All Groups',
                            items: _uniqueGroups,
                            onChanged: (v) {
                              setState(() => _selectedGroup = v);
                              _filter();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedYear,
                      hint: 'All Years',
                      items: _uniqueYears,
                      onChanged: (v) {
                        setState(() => _selectedYear = v);
                        _filter();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedGroup,
                      hint: 'All Groups',
                      items: _uniqueGroups,
                      onChanged: (v) {
                        setState(() => _selectedGroup = v);
                        _filter();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          if (_uniqueGroups.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _uniqueGroups.length,
                itemBuilder: (context, index) {
                  final group = _uniqueGroups[index];
                  final isSelected = group == _selectedGroup;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedGroup = isSelected ? '' : group);
                      _filter();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            group,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String hint,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          isExpanded: true,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
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
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'No students found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filters.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_hasActiveFilters)
              OutlinedButton(
                onPressed: _clearFilters,
                child: const Text('Reset Filters'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) => _buildStudentCard(_filteredStudents[index]),
    );
  }

  Widget _buildStudentCard(Student student) {
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
          onTap: () => _showStudentDetail(student),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    student.fullName.isNotEmpty ? student.fullName.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.email,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (student.year != null && student.year!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                student.year!,
                                style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              student.group,
                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (student.rfidCode != null && student.rfidCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.credit_card, size: 10, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(
                                    student.rfidCode!,
                                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (student.studentId != null)
                      Text(
                        student.studentId!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    if (student.speciality != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        student.speciality!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentDetail(Student student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                student.fullName.isNotEmpty ? student.fullName.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(student.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(student.email, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            _detailRow(Icons.badge, 'Student ID', student.studentId ?? '—'),
            _detailRow(Icons.school, 'Year', student.year ?? '—'),
            _detailRow(Icons.group, 'Group', student.group),
            _detailRow(Icons.work, 'Speciality', student.speciality ?? '—'),
            if (student.rfidCode != null)
              _detailRow(Icons.credit_card, 'RFID', student.rfidCode!),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const Spacer(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}