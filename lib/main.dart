import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'core/api/api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved token
  final apiClient = ApiClient();
  await apiClient.loadToken();
  
  // Set up unauthorized callback to refresh router
  apiClient.onUnauthorized = () {
    // The router's redirect will handle navigation
    // We just need to notify that auth state changed
  };
  
  runApp(const TeacherApp());
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Attendance',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
