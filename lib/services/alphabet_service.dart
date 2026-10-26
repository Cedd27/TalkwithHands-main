import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/alphabet_sign.dart';
import 'api_config.dart';

class AlphabetService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  AlphabetService._(this._dio);

  factory AlphabetService() {
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

    return AlphabetService._(dio);
  }

  Future<List<AlphabetSign>> listAlphabetSigns() async {
    final res = await _dio.get('/alphabet-signs');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid alphabet response from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => AlphabetSign.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<List<AlphabetSign>> listAllAlphabetSigns() async {
    final res = await _dio.get('/alphabet-signs/admin');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid alphabet admin response from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => AlphabetSign.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<AlphabetSign> createAlphabetSign(Map<String, dynamic> payload) async {
    final res = await _dio.post('/alphabet-signs', data: payload);
    return AlphabetSign.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<AlphabetSign> updateAlphabetSign(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/alphabet-signs/$id', data: payload);
    return AlphabetSign.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteAlphabetSign(String id) async {
    await _dio.delete('/alphabet-signs/$id');
  }
}
