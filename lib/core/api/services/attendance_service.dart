import 'dart:convert';
import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class AttendanceService {
  final ApiClient _client = ApiClient();

  Future<List<Attendance>> getSessionAttendance(String sessionId) async {
    try {
      final response = await _client.get(
        ApiConstants.attendanceSession.replaceFirst(':id', sessionId),
        queryParameters: {'limit': 1000},
      );

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['data'] ?? response.data['attendance'] ?? []);
      return data.map((json) => Attendance.fromJson(_ensureMap(json))).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Attendance> markAttendance({
    required String sessionId,
    required String studentId,
    required AttendanceStatus status,
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.attendanceScan,
        data: {
          'sessionId': sessionId,
          'studentId': studentId,
          'status': status.name,
          'scanTime': DateTime.now().toUtc().toIso8601String(),
        },
      );

      return Attendance.fromJson(_ensureMap(response.data));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAttendanceStats({
    String? sessionId,
    String? studentId,
    String? group,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sessionId != null) queryParams['sessionId'] = sessionId;
      if (studentId != null) queryParams['studentId'] = studentId;
      if (group != null) queryParams['group'] = group;

      final response = await _client.get(
        ApiConstants.attendanceStats,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return _ensureMap(response.data ?? {});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Helper to ensure proper Map<String, dynamic> type for web compatibility
  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    // If it's a JSON string, decode it
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    // Otherwise, re-encode and decode to fix web _JsonMap issues
    return jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return 'Attendance records not found.';
        }
        return e.response?.data?['message'] ?? 'An error occurred.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
