import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/admin_analytics.dart';
import 'api_config.dart';

class AdminAnalyticsUnavailableException implements Exception {
  final Uri uri;
  final int? statusCode;
  final DioExceptionType? failureType;

  const AdminAnalyticsUnavailableException({
    required this.uri,
    required this.statusCode,
    required this.failureType,
  });

  @override
  String toString() =>
      'Analytics request failed (${statusCode ?? 'unknown'}): $uri';
}

class AdminAnalyticsService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;
  final Uri _analyticsUri;

  AdminAnalyticsService._(this._dio, this._analyticsUri);

  factory AdminAnalyticsService() {
    final baseUrl = ApiConfig.requireBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        // Render can take longer than 20 seconds to wake a sleeping service.
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 90),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _jwtKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return AdminAnalyticsService._(
      dio,
      Uri.parse('$normalizedBase/admin/analytics'),
    );
  }

  Future<AdminAnalytics> getAnalytics() async {
    try {
      final res = await _dio.getUri(_analyticsUri);
      return AdminAnalytics.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        try {
          final res = await _dio.getUri(_analyticsUri);
          return AdminAnalytics.fromJson(
            Map<String, dynamic>.from(res.data as Map),
          );
        } on DioException {
          // Surface the original failure below with its exact endpoint.
        }
      }
      // Keep the full endpoint in debug logs while presenting a clear UI state.
      debugPrint(
        'Analytics request failed: ${error.requestOptions.method} '
        '${error.requestOptions.uri} (${error.response?.statusCode})',
      );
      throw AdminAnalyticsUnavailableException(
        uri: error.requestOptions.uri,
        statusCode: error.response?.statusCode,
        failureType: error.type,
      );
    }
  }
}
