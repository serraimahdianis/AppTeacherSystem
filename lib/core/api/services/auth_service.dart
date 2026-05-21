import 'package:dio/dio.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/models.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String department,
  }) async {
    try {
      await _client.post(
        ApiConstants.authRegister,
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'department': department,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<LoginResponse> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.authVerifyOtp,
        data: {'email': email, 'otp': otp},
      );

      final token = response.data['access_token'] ?? response.data['token'] ?? '';
      await _client.setToken(token);

      Teacher teacher;
      try {
        final profileResponse = await _client.get(ApiConstants.teachersMe);
        teacher = Teacher.fromJson(profileResponse.data);
      } catch (e) {
        rethrow;
      }

      await _client.setUser(teacher);
      return LoginResponse(token: token, teacher: teacher);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<LoginResponse> login(String email, String password) async {
    try {
      final response = await _client.post(
        ApiConstants.authLogin,
        data: {'email': email, 'password': password},
      );

      final token = response.data['access_token'] ?? response.data['token'] ?? '';
      await _client.setToken(token);

      Teacher teacher;
      try {
        final profileResponse = await _client.get(ApiConstants.teachersMe);
        teacher = Teacher.fromJson(profileResponse.data);
      } catch (e) {
        rethrow;
      }

      await _client.setUser(teacher);
      return LoginResponse(token: token, teacher: teacher);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _client.clearToken();
  }

  Future<Teacher> getProfile() async {
    try {
      final response = await _client.get(ApiConstants.teachersMe);
      return Teacher.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  bool get isAuthenticated => _client.isAuthenticated;

  String _handleError(DioException e) {
    if (e.response?.data != null && e.response?.data is Map) {
      final message = e.response?.data['message'];
      if (message != null) {
        return message.toString();
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'Invalid email or password.';
        } else if (statusCode == 403) {
          return 'Access denied.';
        } else if (statusCode == 404) {
          return 'Resource not found.';
        } else if (statusCode != null && statusCode >= 500) {
          return 'Server error. Please try again later.';
        }
        return e.response?.data?['message'] ?? 'An error occurred.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
