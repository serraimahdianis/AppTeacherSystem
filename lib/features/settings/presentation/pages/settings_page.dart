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
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isSavingPassword = false;
  bool _profileSaved = false;
  bool _passwordSaved = false;
  String? _profileError;
  String? _passwordError;

  Teacher? _teacher;
  final _authService = AuthService();
  final _client = ApiClient();

  @override
  void initState() {
    super.initState();
    _teacher = _client.user;
    _nameController.text = _teacher?.fullName ?? '';
    _departmentController.text = _teacher?.department ?? '';
  }

  bool get _passwordMeetsLength => _newPasswordController.text.length >= 8;
  bool get _passwordHasUppercase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _passwordHasNumber => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _passwordsMatch => _newPasswordController.text == _confirmPasswordController.text;
  bool get _passwordFormValid =>
      _currentPasswordController.text.isNotEmpty &&
      _newPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty &&
      _passwordsMatch &&
      _passwordMeetsLength &&
      _passwordHasUppercase &&
      _passwordHasNumber;

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

  Future<void> _changePassword() async {
    setState(() {
      _isSavingPassword = true;
      _passwordError = null;
      _passwordSaved = false;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      setState(() {
        _passwordSaved = true;
        _isSavingPassword = false;
      });
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on DioException catch (e) {
      setState(() {
        _passwordError = e.response?.data?['message']?.toString() ?? 'Failed to change password.';
        _isSavingPassword = false;
      });
    } catch (e) {
      setState(() {
        _passwordError = e.toString();
        _isSavingPassword = false;
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
          const SizedBox(height: 24),
          _buildSectionTitle('Security'),
          const SizedBox(height: 12),
          _buildPasswordCard(),
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

  Widget _buildPasswordCard() {
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
          if (_passwordError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_passwordError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          if (_passwordSaved)
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
                  Text('Password updated successfully!', style: TextStyle(color: AppColors.success, fontSize: 13)),
                ],
              ),
            ),
          _buildField('Current Password', _currentPasswordController, isPassword: true),
          const SizedBox(height: 16),
          _buildField('New Password', _newPasswordController, isPassword: true),
          const SizedBox(height: 16),
          _buildField('Confirm Password', _confirmPasswordController, isPassword: true),
          const SizedBox(height: 16),
          _buildPasswordRequirements(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (_isSavingPassword || !_passwordFormValid) ? null : _changePassword,
              child: _isSavingPassword
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Requirements:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _requirementRow('At least 8 characters', _passwordMeetsLength),
          _requirementRow('Contains uppercase letter', _passwordHasUppercase),
          _requirementRow('Contains a number', _passwordHasNumber),
          if (_newPasswordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty)
            _requirementRow('Passwords match', _passwordsMatch),
        ],
      ),
    );
  }

  Widget _requirementRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: met ? AppColors.textPrimary : AppColors.textSecondary,
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