import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class ModulesService {
  final ApiClient _client = ApiClient();

  Future<List<Module>> getAllModules() async {
    try {
      final response = await _client.get(ApiConstants.modules);
      final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? response.data['modules'] ?? []);
      return data.map((json) => Module.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Module>> getModulesByTeacher(String teacherId) async {
    try {
      final response = await _client.get(
        ApiConstants.modulesTeacher.replaceFirst(':id', teacherId),
        queryParameters: {'limit': 100},
      );
      final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? response.data['modules'] ?? []);
      return data.map((json) => Module.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Module> createModule(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.modules, data: data);
      return Module.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Module> updateModule(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.patch(
        ApiConstants.modulesId.replaceFirst(':id', id),
        data: data,
      );
      return Module.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteModule(String id) async {
    try {
      await _client.delete(ApiConstants.modulesId.replaceFirst(':id', id));
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
        return e.response?.data?['message'] ?? 'An error occurred.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
