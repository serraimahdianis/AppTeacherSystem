import 'dart:convert';
import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class SessionsService {
  final ApiClient _client = ApiClient();

  Future<List<Session>> getTeacherSessions(String teacherId) async {
    try {
      final response = await _client.get(
        ApiConstants.sessionsTeacher.replaceFirst(':id', teacherId),
      );
      
      final List<dynamic> data = response.data is List ? response.data : response.data['sessions'] ?? [];
      return data.map((json) => Session.fromJson(_ensureMap(json))).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Session>> getAllSessions() async {
    try {
      final response = await _client.get(ApiConstants.sessions);
      
      final List<dynamic> data = response.data is List ? response.data : response.data['sessions'] ?? [];
      return data.map((json) => Session.fromJson(_ensureMap(json))).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Session> getSession(String id) async {
    try {
      final response = await _client.get(ApiConstants.sessionsId.replaceFirst(':id', id));
      return Session.fromJson(_ensureMap(response.data));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Session>> getTodaySessions(String teacherId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _client.get(
        ApiConstants.sessionsTeacherToday.replaceFirst(':id', teacherId),
        queryParameters: {'date': today},
      );
      
      final List<dynamic> data = response.data is List ? response.data : response.data['sessions'] ?? [];
      return data.map((json) => Session.fromJson(_ensureMap(json))).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Session> createSession(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.sessions, data: data);
      return Session.fromJson(_ensureMap(response.data));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Session> startSessionFromSchedule(String scheduleId) async {
    try {
      final response = await _client.post(
        ApiConstants.sessionsStart.replaceFirst(':scheduleId', scheduleId),
      );
      
      // Handle 409 - session already exists for today
      if (response.statusCode == 409) {
        throw 'A session for this schedule already exists for today.';
      }
      
      return Session.fromJson(_ensureMap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw 'A session for this schedule already exists for today.';
      }
      throw _handleError(e);
    }
  }

  Future<Session> updateSessionStatus(String id, String status) async {
    try {
      final response = await _client.patch(
        ApiConstants.sessionsStatus.replaceFirst(':id', id),
        data: {'status': status},
      );
      return Session.fromJson(_ensureMap(response.data));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await _client.delete(ApiConstants.sessionsId.replaceFirst(':id', id));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Session> endSession(String sessionId) async {
    try {
      final response = await _client.post(
        ApiConstants.sessionsEnd.replaceFirst(':id', sessionId),
      );
      return Session.fromJson(_ensureMap(response.data));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getNonce(String sessionId) async {
    try {
      final response = await _client.get(
        '${ApiConstants.sessions}/$sessionId/nonce',
      );
      return _ensureMap(response.data);
    } on DioException {
      return {'nonce': '', 'expiresAt': 0};
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
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please login again.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return 'Sessions not found.';
        }
        return e.response?.data?['message'] ?? 'An error occurred.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
