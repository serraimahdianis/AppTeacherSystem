# AGENTS.md - Teacher App Guidelines

Root: `../AGENTS.md` for monorepo-wide commands and cross-project context.

## 1. Setup & Commands
Flutter SDK at `D:\flutter`, use `flutter.bat` in project root.

### Run & Build
```bash
flutter.bat run                    # Debug mode (Chrome default)
flutter.bat run -d <device_id>    # Run on specific device (get IDs with flutter devices)
flutter.bat build apk --release  # Signed release APK
flutter.bat build web             # Web build for production
flutter.bat devices               # List available devices
```

### Test Commands
```bash
# Run all tests
flutter.bat test

# Run a single test file
flutter.bat test test/widget_test.dart

# Run tests matching a name pattern
flutter.bat test --name "Login test"

# Run with detailed output
flutter.bat test --reporter expanded

# Run with coverage
flutter.bat test --coverage
```

### Lint & Maintain
```bash
flutter.bat analyze       # Static analysis
flutter.bat fix           # Auto-fix lint issues
flutter.bat clean         # Clean build artifacts
flutter.bat pub get       # Update dependencies
flutter.bat pub upgrade   # Upgrade dependencies
flutter.bat doctor        # Check Flutter health
```

---

## 2. Code Style Guidelines

### Project Structure
```
lib/
├── main.dart              # Entry point
├── router/                # GoRouter config (app_router.dart)
├── core/
│   ├── api/
│   │   ├── api_client.dart      # Singleton Dio client with auth interceptors
│   │   ├── constants.dart        # API endpoints
│   │   ├── models/              # Data models
│   │   │   ├── teacher_model.dart
│   │   │   ├── student_model.dart
│   │   │   ├── session_model.dart
│   │   │   ├── schedule_model.dart
│   │   │   ├── attendance_model.dart
│   │   │   └── module_model.dart    # NEW: Module model
│   │   └── services/
│   │       ├── auth_service.dart
│   │       ├── students_service.dart
│   │       ├── sessions_service.dart
│   │       ├── schedule_service.dart
│   │       ├── attendance_service.dart
│   │       └── modules_service.dart  # NEW: Modules API service
│   ├── constants/         # AppColors, AppStrings
│   └── theme/             # AppTheme, Material3 config
├── features/
│   ├── auth/              # Login, register
│   ├── dashboard/         # Main dashboard
│   ├── students/          # Student management
│   ├── sessions/          # Session tracking
│   │   └── presentation/pages/
│   │       ├── sessions_page.dart
│   │       ├── attendance_page.dart
│   │       └── new_session_page.dart  # NEW: Create session form
│   ├── schedule/          # Class scheduling
│   │   └── presentation/pages/
│   │       ├── schedule_page.dart
│   │       ├── add_schedule_page.dart   # NEW: Create schedule form
│   │       └── edit_schedule_page.dart  # NEW: Edit schedule form
│   ├── reports/
│   └── settings/
└── shared/                # Reusable widgets, utils
```

### Naming Conventions
- **Files**: `snake_case.dart` (e.g., `sessions_page.dart`, `auth_service.dart`)
- **Classes**: `PascalCase` (e.g., `SessionsPage`, `ApiClient`, `ScheduleService`)
- **Variables/functions**: `camelCase` (e.g., `getStudents()`, `isLoading`, `_token`)
- **Private members**: `_underscore` prefix (e.g., `_loadData()`, `_token`, `_selectedDay`)
- **Constants**: `lowerCamelCase` or `UPPER_SNAKE_CASE` for static const
- **Enums**: `PascalCase` with `PascalCase` values

### Import Order
1. Dart SDK (`dart:...`)
2. Flutter (`package:flutter/...`)
3. Third-party packages (`package:go_router`, `package:dio`)
4. Local project files (`package:teacher_app/...`)
5. Relative imports (`../../core/api/api.dart`)

Example:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api.dart';
import '../models/student_model.dart';
```

### Formatting Rules
- **Indentation**: 2 spaces (not tabs)
- **Trailing commas**: Use for multi-line calls, widget trees, lists
- **Line length**: Max 80 characters
- **Quotes**: Prefer single quotes (`'text'`)
- **Const constructors**: Use `const` wherever possible

### Type Safety
- Use **explicit types** for public APIs
- Leverage **null safety**: `?`, `!`, `??`
- Use `late` sparingly, prefer proper initialization
- Generic types should be specified when not inferable

### Error Handling
- **API calls**: Catch `DioException`, check `e.response?.statusCode`
- **401 errors**: Redirect to login via `context.go('/login')`
- **UI states**: Handle loading/error/success with `setState`
- **Async errors**: Use try-catch in `Future` methods
- **Print statements**: Remove before production

---

## 3. Lint Rules
Inherits `package:flutter_lints/flutter.yaml` with additional rules:
- `always_declare_return_types`
- `prefer_const_constructors`
- `prefer_single_quotes`
- `use_key_in_widget_constructors`
- `use_rethrow_when_possible`

Excludes: `*.g.dart`, `*.freezed.dart`

---

## 4. State Management
Uses `StatefulWidget` with `setState` for local state.
BLoC package is included but not yet implemented.
For new features, continue using `setState` unless complexity warrants BLoC.

---

## 5. Backend Integration (NestJS)
Flutter app connects to NestJS backend at `http://localhost:3000`.
Swagger docs at `http://localhost:3000/api`. Backend uses MongoDB, JWT auth.

### Key API Endpoints

**Authentication:**
- `POST /auth/teacher/login`
- `POST /auth/teacher/register`
- `POST /auth/teacher/verify-otp`

**Modules (NEW):**
- `GET /modules` - Get all modules
- `GET /modules/teacher/:id` - Get modules by teacher
- `POST /modules` - Create module
- `PATCH /modules/:id` - Update module
- `DELETE /modules/:id` - Delete module

**Schedules:**
- `GET /schedules` - Get all schedules
- `POST /schedules` - Create schedule
- `PATCH /schedules/:id` - Update schedule
- `DELETE /schedules/:id` - Delete schedule

**Sessions:**
- `GET /sessions` - Get all sessions
- `POST /sessions` - Create session
- `POST /sessions/start/:scheduleId` - Start session from schedule
- `PATCH /sessions/:id/status` - Update session status
- `POST /sessions/:id/end` - End session
- `DELETE /sessions/:id` - Delete session

**Attendance:**
- `GET /attendance/session/:id` - Get session attendance
- `POST /attendance/mark` - Mark attendance
- `GET /attendance/stats` - Get attendance statistics

API base URL configured in `lib/core/api/constants.dart`.

---

## 6. Router Configuration
Uses GoRouter with ShellRoute for bottom navigation.

### Routes
- `/login` - Login page
- `/register` - Register page
- `/dashboard` - Main dashboard
- `/schedule` - Schedule list
  - `/schedule/add` - **NEW**: Add schedule form
  - `/schedule/edit/:id` - **NEW**: Edit schedule form
- `/sessions` - Sessions list
  - `/sessions/new` - **NEW**: Create new session
  - `/sessions/attendance` - Attendance marking page
- `/students` - Student management
- `/reports` - Reports page
- `/settings` - Settings page

---

## 7. Common Patterns

### API Client (Singleton)
```dart
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() { _initDio(); }

  late final Dio _dio;
  String? _token;

  void setToken(String token) { _token = token; }
  bool get isAuthenticated => _token != null;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }
}
```

### Data Models (JSON Serialization)
```dart
class Session {
  final String id;
  final String? scheduleId;  // Links session to original schedule
  final String moduleName;
  final SessionType type;
  final SessionStatus status;

  factory Session.fromJson(Map<String, dynamic> json) {
    // Handle nested objects, nulls, and type conversions
  }

  Map<String, dynamic> toJson() => {...};
}
```

### Creating/Editing Resources
All create/edit pages follow the same pattern:
1. Load required data (modules, schedules) in `initState`
2. Use `Form` with `GlobalKey<FormState>`
3. Validate with `validator` callbacks
4. Call API service on save
5. Navigate back with refresh on success

Example (AddSchedulePage):
```dart
Future<void> _saveSchedule() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSaving = true);
  try {
    await _scheduleService.createSchedule({...});
    if (mounted) context.pop();
  } catch (e) {
    // Show error
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}
```

---

## 8. Recent Changes (2026-05-05)
- Added `Module` model and `ModulesService`
- Added `scheduleId` field to `Session` model
- Added CRUD methods to `ScheduleService` and `SessionsService`
- Created `AddSchedulePage`, `EditSchedulePage`, `NewSessionPage`
- Fixed schedule popup menu (edit/start/delete actions)
- Fixed sessions "New Session" FAB navigation
- Fixed dashboard session action to use `updateSessionStatus`
- Updated router with new routes for create/edit pages
