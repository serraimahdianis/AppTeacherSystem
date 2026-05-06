import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/schedule/presentation/pages/schedule_page.dart';
import '../features/sessions/presentation/pages/sessions_page.dart';
import '../features/students/presentation/pages/students_page.dart';
import '../features/reports/presentation/pages/reports_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/sessions/presentation/pages/attendance_page.dart';
import '../features/sessions/presentation/pages/new_session_page.dart';
import '../features/schedule/presentation/pages/add_schedule_page.dart';
import '../features/schedule/presentation/pages/edit_schedule_page.dart';
import '../../core/api/api.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final isAuthenticated = ApiClient().isAuthenticated;
    final location = state.matchedLocation;
    final isGoingToAuth = location == '/login' || location == '/register';

    if (isAuthenticated && isGoingToAuth) {
      return '/dashboard';
    }
    if (!isAuthenticated && !isGoingToAuth) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: LoginPage(),
      ),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: RegisterPage(),
      ),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardPage(),
          ),
        ),
        GoRoute(
          path: '/schedule',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SchedulePage(),
          ),
          routes: [
            GoRoute(
              path: 'add',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AddSchedulePage(),
              ),
            ),
            GoRoute(
              path: 'edit/:id',
              pageBuilder: (context, state) => NoTransitionPage(
                child: EditSchedulePage(scheduleId: state.pathParameters['id']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/sessions',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SessionsPage(),
          ),
          routes: [
            GoRoute(
            path: 'attendance/:sessionId',
            builder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return AttendancePage(sessionId: sessionId);
            },
            ),
            GoRoute(
              path: 'new',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: NewSessionPage(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/students',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StudentsPage(),
          ),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ReportsPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),
  ],
);

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/schedule')) return 1;
    if (location.startsWith('/sessions')) return 2;
    if (location.startsWith('/students')) return 3;
    if (location.startsWith('/reports')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  final _items = const [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', path: '/dashboard'),
    (icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Schedule', path: '/schedule'),
    (icon: Icons.play_circle_outline, activeIcon: Icons.play_circle, label: 'Sessions', path: '/sessions'),
    (icon: Icons.people_outline, activeIcon: Icons.people, label: 'Students', path: '/students'),
    (icon: Icons.assessment_outlined, activeIcon: Icons.assessment, label: 'Reports', path: '/reports'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(_items[index].path);
        },
        destinations: _items.map((item) => NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.activeIcon),
          label: item.label,
        )).toList(),
      ),
    );
  }
}
