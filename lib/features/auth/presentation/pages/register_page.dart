import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/api/api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deptController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _serverError;
  String? _successMsg;
  int _step = 1;
  String _pendingEmail = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deptController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _serverError = null; });
    try {
      await _authService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        department: _deptController.text.trim(),
      );
      if (mounted) {
        setState(() { _pendingEmail = _emailController.text.trim(); _step = 2; _isLoading = false; _successMsg = 'OTP sent to $_pendingEmail'; });
      }
    } catch (e) {
      if (mounted) setState(() { _serverError = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length < 4) {
      setState(() => _serverError = 'Enter the 6-digit code');
      return;
    }
    setState(() { _isLoading = true; _serverError = null; });
    try {
      await _authService.verifyOtp(email: _pendingEmail, otp: _otpController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account verified! Please login.')));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) setState(() { _serverError = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
                ).animate().fade().scaleXY(begin: 0.8, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(_step == 1 ? 'Create Account' : 'Verify Email', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(_step == 1 ? 'Register to get started' : 'Enter the code sent to $_pendingEmail', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 32),
                if (_serverError != null)
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20), const SizedBox(width: 8),
                      Expanded(child: Text(_serverError!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    ]),
                  ),
                if (_successMsg != null)
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20), const SizedBox(width: 8),
                      Expanded(child: Text(_successMsg!, style: const TextStyle(color: AppColors.success, fontSize: 13))),
                    ]),
                  ),
                if (_step == 1) _buildRegisterForm(),
                if (_step == 2) _buildOtpForm(),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_step == 1 ? 'Already have an account? ' : 'Wrong email? ', style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => _step == 1 ? context.go('/login') : setState(() { _step = 1; _serverError = null; _successMsg = null; }),
                    child: Text(_step == 1 ? 'Sign In' : 'Register again', style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
          ).animate().fade(delay: 100.ms).slideX(begin: 0.1),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ).animate().fade(delay: 150.ms).slideX(begin: 0.1),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deptController, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business_outlined)),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter your department' : null,
          ).animate().fade(delay: 200.ms).slideX(begin: 0.1),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController, obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => v == null || v.length < 6 ? 'At least 6 characters' : null,
          ).animate().fade(delay: 250.ms).slideX(begin: 0.1),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Register', style: TextStyle(fontSize: 16)),
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return Column(
      children: [
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', labelText: 'OTP Code', hintText: '------'),
        ).animate().fade().scaleXY(begin: 0.9),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Verify & Login', style: TextStyle(fontSize: 16)),
          ),
        ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
      ],
    );
  }
}
