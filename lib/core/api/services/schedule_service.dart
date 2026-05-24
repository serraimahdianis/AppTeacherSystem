import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class ScheduleService {
  final ApiClient _client = ApiClient();

  Future<List<Schedule>> getTeacherSchedule(String teacherId) async {
    try {
      final response = await _client.get(
        ApiConstants.schedulesTeacher.replaceFirst(':id', teacherId),
        queryParameters: {'limit': 100},
      );
      
      final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? response.data['schedules'] ?? []);
      return data.map((json) => Schedule.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Schedule>> getAllSchedules() async {
    try {
      final response = await _client.get(ApiConstants.schedules);
      
      final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? response.data['schedules'] ?? []);
      return data.map((json) => Schedule.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.schedules, data: data);
      return Schedule.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.patch(
        ApiConstants.schedulesId.replaceFirst(':id', id),
        data: data,
      );
      return Schedule.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _client.delete(ApiConstants.schedulesId.replaceFirst(':id', id));
    } on DioException catch (e) {
      throw _handleError(e);
    }
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
          return 'Schedule not found.';
        }
        return e.response?.data?['message'] ?? 'An error occurred.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}