# Smart Attendance - Teacher App

A Flutter-based mobile application for university teachers to manage student attendance, sessions, and schedules. It integrates with a NestJS backend.

## Project Overview
This application provides teachers with tools to manage their academic duties, including:
- **Authentication**: Registration with OTP verification and secure login.
- **Dashboard**: High-level overview of daily activities and stats.
- **Attendance Tracking**: Managing student attendance for different session types (Cours, TD, TP).
- **Schedule Management**: Viewing and filtering weekly class schedules.
- **Reports**: Generating and viewing attendance reports.

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: `StatefulWidget` with `setState` for UI logic. Global state (Teacher profile, Auth token) is managed via a singleton `ApiClient` with `SharedPreferences` persistence.
- **Networking**: `dio` for HTTP requests with custom interceptors for auth.
- **Navigation**: `go_router` with nested routes for feature sub-pages (e.g., `/sessions/attendance`).
- **Persistence**: `shared_preferences` for tokens and user profiles.

## Architecture
The project follows a feature-first organization:
- `lib/core/`: Shared logic, API clients, constants, and global models.
- `lib/features/`: Feature-specific logic and UI (Auth, Dashboard, Sessions, Students, Reports, Settings).
- `lib/router/`: Centralized routing with auth guards.

## Key Files & Directories
- `lib/main.dart`: Initializes the system.
- `lib/core/api/api_client.dart`: Singleton handling Auth, User Profile, and Dio requests.
- `lib/features/sessions/presentation/pages/attendance_page.dart`: Core UI for real-time attendance marking.
- `lib/router/app_router.dart`: Defines navigation structure and deep links.

## Core Workflows
### Auth & Profile
- Token and `Teacher` profile are persisted in `SharedPreferences`.
- `ApiClient().user` provides global access to the logged-in teacher's data.

### Session Lifecycle
- **Planned**: Sessions can be started from the Dashboard or Sessions list.
- **In Progress**: Active sessions provide a "View Live Session" action leading to the `AttendancePage`.
- **Completed**: Finalized sessions show historical attendance data.

### Attendance Marking
- `AttendancePage` uses **optimistic UI updates**: clicking a status (P, L, A) updates the UI immediately while syncing with the backend in the background. Errors are handled with automatic rollbacks.

## Development & Build Commands
Use `flutter.bat` for commands on this machine.

| Task | Command |
| :--- | :--- |
| **Run (Debug)** | `flutter.bat run` |
| **Install Dependencies** | `flutter.bat pub get` |
| **Clean Project** | `flutter.bat clean` |
| **Run Tests** | `flutter.bat test` |
| **Static Analysis** | `flutter.bat analyze` |
| **Build APK (Release)** | `flutter.bat build apk --release` |

## Coding Standards
- **Naming**:
    - Files: `snake_case` (e.g., `student_model.dart`).
    - Classes: `PascalCase` (e.g., `StudentModel`).
    - Variables/Methods: `camelCase` (e.g., `loadStudents`).
    - Private members: Start with `_` (e.g., `_isLoading`).
- **Imports**: Prefer relative imports for local files. Order: Dart SDK -> Flutter -> Third-party -> Local.
- **Safety**: Always use null-safety features (`?`, `!`, `??`).
- **UI**: Use `const` constructors where possible to improve performance.

## Auth Flow
1. **Login/Register**: Token is received from the backend.
2. **Persistence**: `ApiClient` saves the token to `SharedPreferences`.
3. **Interceptors**: `ApiClient` automatically attaches the Bearer token to all requests.
4. **Unauthorized**: If a 401 error occurs, the token is cleared, and the app redirects to the login page via `go_router` logic.
