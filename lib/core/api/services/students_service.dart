import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class StudentsService {
  final ApiClient _client = ApiClient();

  Future<List<Student>> getAllStudents({String? group, String? year}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (group != null && group.isNotEmpty) {
        queryParams['group'] = group;
      }
      if (year != null && year.isNotEmpty) {
        queryParams['year'] = year;
      }
      queryParams['limit'] = 500;

      final response = await _client.get(
        ApiConstants.students,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final List<dynamic> data;
      if (response.data is List) {
        data = response.data;
      } else if (response.data is Map && response.data['data'] is List) {
        data = response.data['data'];
      } else if (response.data is Map && response.data['students'] is List) {
        data = response.data['students'];
      } else {
        data = [];
      }
      return data.map((json) => Student.fromJson(json as Map<String, dynamic>)).toList();
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

  /// Find a student by their RFID card or personal QR code.
  Future<Student> getStudentByRfid(String code) async {
    try {
      final response = await _client.get(
        ApiConstants.studentsRfid.replaceFirst(':rfidCode', code),
      );
      return Student.fromJson(response.data);
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