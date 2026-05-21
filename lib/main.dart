import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'core/api/api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved token
  final apiClient = ApiClient();
  await apiClient.loadToken();
  
  // Navigate to login on 401
  apiClient.onUnauthorized = () {
    appRouter.go('/login');
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
