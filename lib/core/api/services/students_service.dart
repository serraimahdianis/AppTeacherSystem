import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class StudentsService {
  final ApiClient _client = ApiClient();

  Future<List<Student>> getAllStudents({String? group}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (group != null && group.isNotEmpty && group != 'All') {
        queryParams['group'] = group;
      }
      
      final response = await _client.get(
        ApiConstants.students,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final List<dynamic> data = response.data is List ? response.data : response.data['students'] ?? [];
      return data.map((json) => Student.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Student> getStudent(String id) async {
    try {
      final response = await _client.get(ApiConstants.studentsId.replaceFirst(':id', id));
      return Student.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Student>> searchStudents(String query) async {
    try {
      final response = await _client.get(
        ApiConstants.students,
        queryParameters: {'search': query},
      );
      
      final List<dynamic> data = response.data is List ? response.data : response.data['students'] ?? [];
      return data.map((json) => Student.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentStats() async {
    try {
      final response = await _client.get(ApiConstants.studentsStats);
      return response.data ?? {};
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
          return 'Students not found.';
        }
        return e.response?.data?['message'] ?? 'An error occurred.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}