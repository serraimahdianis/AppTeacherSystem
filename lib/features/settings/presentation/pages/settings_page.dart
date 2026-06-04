import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _isSavingProfile = false;
  bool _profileSaved = false;
  String? _profileError;

  List<String> _selectedGroups = [];
  List<String> _selectedYears = [];
  List<String> _selectedSpecialities = [];

  List<dynamic> _allGroups = [];
  List<dynamic> _allYears = [];
  List<dynamic> _allSpecialities = [];

  Teacher? _teacher;
  final _authService = AuthService();
  final _client = ApiClient();

  @override
  void initState() {
    super.initState();
    _teacher = _client.user;
    _nameController.text = _teacher?.fullName ?? '';
    _departmentController.text = _teacher?.department ?? '';
    _selectedGroups = List<String>.from(_teacher?.groups ?? []);
    _selectedYears = List<String>.from(_teacher?.years ?? []);
    _selectedSpecialities = List<String>.from(_teacher?.specialities ?? []);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final gRes = await _client.get('/metadata/groups');
      final yRes = await _client.get('/metadata/years');
      final sRes = await _client.get('/metadata/specialities');
      setState(() {
        _allGroups = gRes.data['data'] ?? [];
        _allYears = yRes.data['data'] ?? [];
        _allSpecialities = sRes.data['data'] ?? [];
      });
    } catch (_) {}
  }



  Future<void> _saveProfile() async {
    setState(() {
      _isSavingProfile = true;
      _profileError = null;
      _profileSaved = false;
    });

    try {
      final teacherId = _client.teacherId;
      if (teacherId == null) throw 'Teacher ID not found.';

      await _client.patch(
        ApiConstants.teachersId.replaceFirst(':id', teacherId),
        data: {
          'fullName': _nameController.text.trim(),
          'department': _departmentController.text.trim(),
          'groups': _selectedGroups,
          'years': _selectedYears,
          'specialities': _selectedSpecialities,
        },
      );

      setState(() {
        _profileSaved = true;
        _isSavingProfile = false;
      });
    } on DioException catch (e) {
      setState(() {
        _profileError = e.response?.data?['message']?.toString() ?? 'Failed to save profile.';
        _isSavingProfile = false;
      });
    } catch (e) {
      setState(() {
        _profileError = e.toString();
        _isSavingProfile = false;
      });
    }
  }



  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Profile Information'),
          const SizedBox(height: 12),
          _buildProfileCard(),

          const SizedBox(height: 32),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_profileError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_profileError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          if (_profileSaved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Profile saved successfully!', style: TextStyle(color: AppColors.success, fontSize: 13)),
                ],
              ),
            ),
          _buildField('Full Name', _nameController),
          const SizedBox(height: 16),
          _buildField('Email', TextEditingController(text: _teacher?.email ?? ''), enabled: false),
          const SizedBox(height: 16),
          _buildField('Department', _departmentController),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _buildMultiSelectField('Assigned Years', _allYears, _selectedYears, (val) {
            setState(() {
              _selectedYears.contains(val) ? _selectedYears.remove(val) : _selectedYears.add(val);
            });
          }),
          const SizedBox(height: 16),
          _buildMultiSelectField('Assigned Groups', _allGroups, _selectedGroups, (val) {
            setState(() {
              _selectedGroups.contains(val) ? _selectedGroups.remove(val) : _selectedGroups.add(val);
            });
          }),
          const SizedBox(height: 16),
          _buildMultiSelectField('Assigned Specialities', _allSpecialities, _selectedSpecialities, (val) {
            setState(() {
              _selectedSpecialities.contains(val) ? _selectedSpecialities.remove(val) : _selectedSpecialities.add(val);
            });
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingProfile ? null : _saveProfile,
              child: _isSavingProfile
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildField(String label, TextEditingController controller, {bool enabled = true, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: isPassword,
          decoration: InputDecoration(
            isDense: true,
            filled: !enabled,
            fillColor: enabled ? AppColors.surface : AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField(String label, List<dynamic> options, List<String> selected, Function(String) onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final name = opt['name']?.toString() ?? '';
            final isSelected = selected.contains(name);
            return GestureDetector(
              onTap: () => onToggle(name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: _handleLogout,
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text('Logout', style: TextStyle(color: AppColors.error)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}