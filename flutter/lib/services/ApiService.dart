import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_jdshop/config/Config.dart';
import 'package:flutter_jdshop/model/RequestModel.dart';
import 'package:flutter_jdshop/services/StorageService.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getUserToken();
          if (token != null) {
            final tokenStr = token.toString();
            if (tokenStr.isNotEmpty && tokenStr != 'null') {
              options.headers['Authorization'] = _normalizeToken(tokenStr);
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: Config.domain,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ));
  final StorageService _storageService = StorageService();

  String _normalizeToken(String token) {
    if (token.startsWith('Bearer ')) return token;
    return 'Bearer $token';
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      
      if (fromJson != null) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromJson,
        );
      }
      
      return ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
      );
      
      if (fromJson != null) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromJson,
        );
      }
      
      return ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<T>> postForm<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      Map<String, dynamic>? nextHeaders = headers;
      final auth = headers?['Authorization'];
      if (auth is String && auth.isNotEmpty) {
        nextHeaders = Map<String, dynamic>.from(headers ?? {});
        nextHeaders['Authorization'] = _normalizeToken(auth);
      }
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: nextHeaders,
        ),
      );

      if (fromJson != null) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromJson,
        );
      }

      return ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
      );
      
      if (fromJson != null) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromJson,
        );
      }
      
      return ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<T>> putForm<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      Map<String, dynamic>? nextHeaders = headers;
      final auth = headers?['Authorization'];
      if (auth is String && auth.isNotEmpty) {
        nextHeaders = Map<String, dynamic>.from(headers ?? {});
        nextHeaders['Authorization'] = _normalizeToken(auth);
      }
      final response = await _dio.put(
        path,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: nextHeaders,
        ),
      );

      if (fromJson != null) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromJson,
        );
      }

      return ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
      );
      
      if (fromJson != null) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromJson,
        );
      }
      
      return ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<dynamic>> getRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> postRaw(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.post(
      path,
      data: data,
      options: options,
    );
  }

  Future<Response<dynamic>> putRaw(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.put(
      path,
      data: data,
      options: options,
    );
  }

  Future<Response<dynamic>> deleteRaw(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.delete(
      path,
      data: data,
      options: options,
    );
  }
}
