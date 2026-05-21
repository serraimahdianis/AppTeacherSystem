import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';
import 'models/models.dart';

typedef UnauthorizedCallback = void Function();

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  String? _token;
  Teacher? _user;
  String? _teacherId;
  UnauthorizedCallback? onUnauthorized;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _handleUnauthorized();
        }
        return handler.next(error);
      },
    ));
  }

  void _handleUnauthorized() {
    _token = null;
    _user = null;
    _teacherId = null;
    _secureStorage.delete(key: 'auth_token');
    _secureStorage.delete(key: 'user_profile');
    onUnauthorized?.call();
  }

  Future<void> setToken(String token) async {
    _token = token;
    _extractTeacherIdFromToken();
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  void _extractTeacherIdFromToken() {
    if (_token == null) return;
    try {
      final parts = _token!.split('.');
      if (parts.length != 3) return;
      var payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      _teacherId = data['sub']?.toString();
    } catch (e) {
      // Silently handle token decode errors
    }
  }

  Future<void> setUser(Teacher teacher) async {
    _user = teacher;
    await _secureStorage.write(key: 'user_profile', value: jsonEncode(teacher.toJson()));
  }

  Future<void> loadToken() async {
    _token = await _secureStorage.read(key: 'auth_token');

    if (_token != null) {
      _extractTeacherIdFromToken();
    }

    final profileStr = await _secureStorage.read(key: 'user_profile');
    if (profileStr != null) {
      try {
        _user = Teacher.fromJson(jsonDecode(profileStr));
      } catch (e) {
        // Silently handle profile decode errors
      }
    }
  }

  Future<void> clearToken() async {
    _token = null;
    _user = null;
    _teacherId = null;
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_profile');
  }

  bool get isAuthenticated => _token != null;

  String? get token => _token;
  Teacher? get user => _user;
  String? get teacherId => _teacherId;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }
}
