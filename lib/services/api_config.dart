import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final fromBuild = _definedApiBaseUrl.trim();
    if (fromBuild.isNotEmpty) return _trimTrailingSlash(fromBuild);

    final fromEnv = dotenv.env['API_BASE_URL']?.trim() ?? '';
    return _trimTrailingSlash(fromEnv);
  }

  static String requireBaseUrl() {
    final value = baseUrl;
    if (value.isEmpty) {
      throw Exception(
        'Missing API_BASE_URL. Set it in lib/.env or pass'
        '--dart-define=API_BASE_URL=https://your-public-api.example.com',
      );
    }
    return value;
  }

  static String _trimTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
