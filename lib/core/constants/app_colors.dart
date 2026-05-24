import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGlass = Color(0xCCFFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0x3310B981);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0x33F59E0B);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0x33EF4444);

  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  static const Color sidebarBg = Color(0xFFF8FAFC);
  static const Color sidebarActiveBg = Color(0xFFEEF2FF);
  static const Color sidebarActiveText = Color(0xFF6366F1);
  static const Color sidebarInactiveText = Color(0xFF64748B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
