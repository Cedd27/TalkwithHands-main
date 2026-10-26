import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/number_sign.dart';
import 'api_config.dart';

class NumberService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  NumberService._(this._dio);

  factory NumberService() {
    final baseUrl = ApiConfig.requireBaseUrl();

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
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

    return NumberService._(dio);
  }

  Future<List<NumberSign>> listNumberSigns() async {
    final res = await _dio.get('/number-signs');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid number response from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => NumberSign.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<List<NumberSign>> listAllNumberSigns() async {
    final res = await _dio.get('/number-signs/admin');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid number admin response from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => NumberSign.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<NumberSign> createNumberSign(Map<String, dynamic> payload) async {
    final res = await _dio.post('/number-signs', data: payload);
    return NumberSign.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<NumberSign> updateNumberSign(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/number-signs/$id', data: payload);
    return NumberSign.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteNumberSign(String id) async {
    await _dio.delete('/number-signs/$id');
  }
}
