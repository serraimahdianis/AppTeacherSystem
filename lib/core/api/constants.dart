import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static String baseUrl = _getInitialBaseUrl();

  static String _getInitialBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }
  static const String authLogin = '/auth/teacher/login';
  static const String authRegister = '/auth/teacher/register';
  static const String authVerifyOtp = '/auth/teacher/verify-otp';
  static const String authChangePassword = '/auth/teacher/change-password';
  
  static const String teachers = '/teachers';
  static const String teachersMe = '/teachers/me';
  static const String teachersId = '/teachers/:id';
  
  static const String students = '/students';
  static const String studentsId = '/students/:id';
  static const String studentsRfid = '/students/rfid/:rfidCode';
  
  static const String sessions = '/sessions';
  static const String sessionsTeacher = '/sessions/teacher/:id';
  static const String sessionsTeacherToday = '/sessions/teacher/:id/today';
  static const String sessionsId = '/sessions/:id';
  static const String sessionsStart = '/sessions/start/:scheduleId';
  static const String sessionsEnd = '/sessions/:id/end';
  static const String sessionsStatus = '/sessions/:id/status';
  
  static const String schedules = '/schedules';
  static const String schedulesTeacher = '/schedules/teacher/:id';
  static const String schedulesId = '/schedules/:id';

  static const String modules = '/modules';
  static const String modulesTeacher = '/modules/teacher/:id';
  static const String modulesId = '/modules/:id';
  
  static const String attendance = '/attendance';
  static const String attendanceSession = '/attendance/session/:id';
  static const String attendanceScan = '/attendance/scan';
  static const String attendanceStats = '/attendance/stats';
}
