# Smart Attendance - Teacher App

A Flutter-based mobile application for university teachers to manage student attendance, sessions, and schedules. Built with Flutter and integrated with a NestJS backend.

## Features

- **Authentication** - Teacher registration with OTP verification, login/logout
- **Dashboard** - Overview of attendance statistics, today's sessions, and recent activity
- **Student Management** - View, search, and filter students by group with attendance rates
- **Session Management** - Track class sessions (Cours/TD/TP) with start/end functionality
- **Schedule** - Weekly class schedule with day-wise filtering
- **Reports** - Attendance reports and statistics
- **Settings** - Profile management and app preferences

## Tech Stack

- **Frontend**: Flutter (Dart)
- **State Management**: StatefulWidget with setState
- **Routing**: go_router with ShellRoute for bottom navigation
- **HTTP Client**: Dio with interceptors for auth token management
- **Storage**: shared_preferences for token persistence
- **Backend**: NestJS with MongoDB/Mongoose (separate repository)

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── router/
│   └── app_router.dart               # GoRouter configuration with auth guards
├── core/
│   ├── api/
│   │   ├── api.dart                  # Barrel exports
│   │   ├── api_client.dart           # Singleton Dio client with auth interceptors
│   │   ├── constants.dart            # API endpoints (matches NestJS backend)
│   │   ├── models/                  # Data models with fromJson/toJson
│   │   │   ├── teacher_model.dart
│   │   │   ├── student_model.dart
│   │   │   ├── session_model.dart
│   │   │   ├── schedule_model.dart
│   │   │   └── attendance_model.dart
│   │   └── services/                # API service classes
│   │       ├── auth_service.dart
│   │       ├── students_service.dart
│   │       ├── sessions_service.dart
│   │       ├── schedule_service.dart
│   │       └── attendance_service.dart
│   ├── constants/
│   │   └── app_colors.dart          # App color palette
│   └── theme/
│       └── app_theme.dart           # Material3 theme configuration
├── features/
│   ├── auth/
│   │   └── presentation/pages/
│   │       ├── login_page.dart
│   │       └── register_page.dart
│   ├── dashboard/
│   │   └── presentation/pages/
│   │       └── dashboard_page.dart
│   ├── students/
│   │   └── presentation/pages/
│   │       └── students_page.dart
│   ├── sessions/
│   │   └── presentation/pages/
│   │       └── sessions_page.dart
│   ├── schedule/
│   │   └── presentation/pages/
│   │       └── schedule_page.dart
│   ├── reports/
│   │   └── presentation/pages/
│   │       └── reports_page.dart
│   └── settings/
│       └── presentation/pages/
│           └── settings_page.dart
└── shared/                          # Reusable widgets (if needed)
```

## Setup Instructions

### Prerequisites
- Flutter SDK (located at `D:\flutter` on this machine)
- NestJS backend running at `http://localhost:3000`
- Android/iOS emulator or physical device

### Installation

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd teacher-app
   ```

2. **Add Flutter to PATH** (Windows PowerShell)
   ```powershell
   $env:PATH = "D:\flutter\bin;$env:PATH"
   ```

3. **Install dependencies**
   ```bash
   flutter.bat pub get
   ```

4. **Run the app**
   ```bash
   flutter.bat run
   ```

## Backend API Integration

The app connects to a NestJS backend with the following configuration:

**Base URL**: `http://localhost:3000` (configured in `lib/core/api/constants.dart`)

**Authentication Endpoints**:
- `POST /auth/teacher/register` - Register new teacher
- `POST /auth/teacher/verify-otp` - Verify OTP
- `POST /auth/teacher/login` - Teacher login
- `GET /auth/teacher/profile` - Get teacher profile

**Resource Endpoints**:
- `GET/POST /teachers` - Teacher management
- `GET/POST /students` - Student management
- `GET/POST /sessions` - Session management
- `GET/POST /schedules` - Schedule management
- `GET/POST /attendance` - Attendance tracking

**Auth Flow**:
1. Teacher registers → receives OTP via email
2. Verifies OTP → receives JWT token
3. Token stored in SharedPreferences
4. Token attached to all subsequent API requests via Dio interceptor
5. 401 responses trigger automatic logout

## Build & Development Commands

### Running the App
```bash
flutter.bat run                    # Debug mode
flutter.bat run -d <device_id>    # Run on specific device
flutter.bat run --release         # Release mode
```

### Building APK
```bash
flutter.bat build apk             # Debug APK
flutter.bat build apk --release  # Signed release APK
```

### Testing
```bash
flutter.bat test                       # Run all tests
flutter.bat test test/widget_test.dart # Run single test file
flutter.bat test --name "test name"     # Run tests matching pattern
flutter.bat test --reporter expanded   # Detailed output
```

### Linting & Maintenance
```bash
flutter.bat analyze   # Static analysis
flutter.bat fix       # Auto-fix lint issues
flutter.bat clean     # Clean build artifacts
flutter.bat pub get   # Update dependencies
```

## Code Style Guidelines

### Naming Conventions
- **Files**: `snake_case` (e.g., `students_page.dart`)
- **Classes**: `PascalCase` (e.g., `StudentsPage`)
- **Functions/Variables**: `camelCase` (e.g., `getStudents()`)
- **Private members**: underscore prefix (e.g., `_loadData()`)
- **Constants**: `lowerCamelCase` or `SCREAMING_SNAKE_CASE`

### Imports Order
```dart
import 'dart:async';                                    // 1. Dart SDK
import 'package:flutter/material.dart';                 // 2. Flutter
import 'package:go_router/go_router.dart';            // 3. Third-party
import 'core/theme/app_theme.dart';                     // 4. Local (relative)
import '../constants/app_colors.dart';                  // 5. Parent directory
```

### Formatting
- 2 spaces indentation
- Trailing commas for multi-line constructs
- Use `const` constructors when possible
- Use `withValues(alpha: 0.1)` for color opacity

### Types & Null Safety
```dart
final String name = 'John';           // Explicit types preferred
final int count = 0;
final List<Student> students = [];
String? optionalValue;                // Nullable with ?
final value = optional ?? 'default'; // Default with ??
```

### Error Handling
**API Services** - Catch `DioException`:
```dart
try {
  final response = await _client.get('/students');
  return Student.fromJson(response.data);
} on DioException catch (e) {
  throw _handleError(e);
}
```

**UI** - Use setState with error state:
```dart
try {
  final data = await _loadData();
  setState(() { _data = data; _isLoading = false; });
} catch (e) {
  setState(() { _errorMessage = e.toString(); _isLoading = false; });
}
```

## Lint Rules

Inherits `package:flutter_lints/flutter.yaml` with additional rules:
- `always_declare_return_types`
- `prefer_const_constructors`
- `prefer_single_quotes`
- `use_key_in_widget_constructors`
- `use_rethrow_when_possible`

Excludes generated files (`*.g.dart`, `*.freezed.dart`).

## State Management

Currently uses **StatefulWidget with setState**. The BLoC package is included in dependencies but not yet implemented.

## Common Patterns

### API Client (Singleton)
```dart
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late final Dio _dio;
  String? _token;
}
```

### Data Models
```dart
class Student {
  final String id, firstName, lastName;
  
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] ?? '',
    firstName: json['firstName'] ?? '',
    lastName: json['lastName'] ?? '',
  );
  
  Map<String, dynamic> toJson() => {...};
}
```

### Routing (go_router with ShellRoute)
```dart
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    // Auth guard logic
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [...],
    ),
  ],
);
```

## Troubleshooting

- **Flutter command not found**: Add `D:\flutter\bin` to your PATH
- **Connection timeout**: Ensure NestJS backend is running on `http://localhost:3000`
- **401 Unauthorized**: Token may be expired, app will auto-redirect to login
- **Build failures**: Run `flutter.bat clean` then `flutter.bat pub get`

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
#   A p p T e a c h e r S y s t e m -  
 