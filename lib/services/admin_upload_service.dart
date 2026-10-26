import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class AdminUploadService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  AdminUploadService._(this._dio);

  factory AdminUploadService() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.requireBaseUrl(),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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

    return AdminUploadService._(dio);
  }

  Future<String> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(RegExp(r'[\\/]')).last,
      ),
    });

    final res = await _dio.post(
      '/admin/uploads',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final url = (res.data['url'] ?? '').toString();
    if (url.isEmpty) {
      throw Exception('Upload succeeded but the server did not return a URL.');
    }
    return url;
  }
}
