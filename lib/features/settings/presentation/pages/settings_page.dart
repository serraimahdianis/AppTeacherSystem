import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Teacher? _teacher;
  // _isLoading and _errorMessage removed - not needed since we don't load profile
  
  @override
  void initState() {
    super.initState();
    _teacher = ApiClient().user;
  }

  Future<void> _handleLogout() async {
    await AuthService().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(context, 'Profile Information'),
        _buildProfileCard(),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Security'),
        _buildPasswordCard(),
        const SizedBox(height: 32),
        _buildLogoutButton(context),
      ],
    );
  }

  Widget _buildProfileCard() {
    final teacher = _teacher;
    final name = teacher != null ? teacher.fullName : '';
    final email = teacher?.email ?? '';
    final department = teacher?.department ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputField('Full Name', name),
            const SizedBox(height: 16),
            _buildInputField('Email', email, enabled: false),
            const SizedBox(height: 16),
            _buildInputField('Department', department),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile saved')),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputField('Current Password', '', isPassword: true),
            const SizedBox(height: 16),
            _buildInputField('New Password', '', isPassword: true),
            const SizedBox(height: 16),
            _buildInputField('Confirm Password', '', isPassword: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Update Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String value, {bool enabled = true, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          enabled: enabled,
          obscureText: isPassword,
          decoration: InputDecoration(
            isDense: true,
            filled: !enabled,
            fillColor: enabled ? AppColors.surface : AppColors.background,
          ),
        ),
      ],
    );
  }

  // Replaced by _buildProfileCard and _buildPasswordCard

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  // Removed generic settings tiles

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _handleLogout,
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text('Logout', style: TextStyle(color: AppColors.error)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
