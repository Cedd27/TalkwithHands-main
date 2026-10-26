import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../models/user_profile.dart';
import 'api_config.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static const _jwtKey = 'auth_jwt';
  static const _cachedUserKey = 'auth_cached_user';
  static const _profilePhotoPrefix = 'profile_photo_';
  static const _coverPhotoPrefix = 'cover_photo_';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  AuthService._(this._dio);

  factory AuthService() {
    final baseUrl = ApiConfig.requireBaseUrl();

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
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

    return AuthService._(dio);
  }

  Future<void> _storeJwt(String token) async {
    await _storage.write(key: _jwtKey, value: token);
  }

  Future<void> _storeSession(String token, UserProfile profile) async {
    await _storeJwt(token);
    await cacheProfile(profile);
  }

  static Future<bool> hasStoredSession() async {
    final token = await _storage.read(key: _jwtKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> cacheProfile(UserProfile profile) async {
    await _storage.write(
      key: _cachedUserKey,
      value: jsonEncode(profile.toJson()),
    );
  }

  static Future<UserProfile?> cachedProfile() async {
    final raw = await _storage.read(key: _cachedUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return UserProfile.fromJson(json);
      }
      if (json is Map) {
        return UserProfile.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> cacheProfileImages({
    required String userId,
    String? photoUrl,
    String? coverPhotoUrl,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final photo = photoUrl?.trim() ?? '';
    final cover = coverPhotoUrl?.trim() ?? '';
    if (photo.isNotEmpty) {
      await _storage.write(key: '$_profilePhotoPrefix$id', value: photo);
    }
    if (cover.isNotEmpty) {
      await _storage.write(key: '$_coverPhotoPrefix$id', value: cover);
    }
  }

  static Future<String?> cachedProfilePhoto(String userId) {
    return _storage.read(key: '$_profilePhotoPrefix${userId.trim()}');
  }

  static Future<String?> cachedCoverPhoto(String userId) {
    return _storage.read(key: '$_coverPhotoPrefix${userId.trim()}');
  }

  static bool get isGoogleAuthEnabled =>
      dotenv.env['ENABLE_GOOGLE_AUTH']?.trim().toLowerCase() == 'true' &&
      (dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim().isNotEmpty ?? false);

  static bool get isFacebookAuthEnabled =>
      dotenv.env['ENABLE_FACEBOOK_AUTH']?.trim().toLowerCase() == 'true' &&
      (dotenv.env['FACEBOOK_APP_ID']?.trim().isNotEmpty ?? false) &&
      (dotenv.env['FACEBOOK_CLIENT_TOKEN']?.trim().isNotEmpty ?? false);

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException {
      // Local cleanup still matters if the network is unavailable.
    }
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _cachedUserKey);
    try {
      await GoogleSignIn().signOut();
    } on PlatformException {
      // Ignore provider cleanup failures during local logout.
    }
    try {
      await FacebookAuth.instance.logOut();
    } on PlatformException {
      // Ignore provider cleanup failures during local logout.
    }
  }

  Future<UserProfile> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/signup',
        data: {'username': username, 'email': email, 'password': password},
      );

      final token = (res.data['token'] ?? '').toString();
      if (token.isEmpty) throw AuthException('Missing token in response.');
      final profile = UserProfile.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storeSession(token, profile);

      return profile;
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final token = (res.data['token'] ?? '').toString();
      if (token.isEmpty) throw AuthException('Missing token in response.');
      final profile = UserProfile.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storeSession(token, profile);

      return profile;
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> loginWithGoogle() async {
    if (!isGoogleAuthEnabled) {
      throw AuthException('Google sign-in setup is not finished yet.');
    }

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim(),
        scopes: const ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) throw AuthException('Google sign-in cancelled.');

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw AuthException('Missing Google idToken.');
      }

      final res = await _dio.post(
        '/auth/google/mobile',
        data: {'idToken': idToken},
      );

      final token = (res.data['token'] ?? '').toString();
      if (token.isEmpty) throw AuthException('Missing token in response.');
      final profile = UserProfile.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storeSession(token, profile);

      return profile;
    } on PlatformException catch (e) {
      throw AuthException(_providerMessage('Google', e));
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> loginWithFacebook() async {
    if (!isFacebookAuthEnabled) {
      throw AuthException('Facebook login setup is not finished yet.');
    }

    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['public_profile', 'email'],
      );

      if (result.status != LoginStatus.success) {
        throw AuthException('Facebook sign-in failed: ${result.status.name}');
      }

      final accessToken = result.accessToken?.tokenString;
      if (accessToken == null || accessToken.isEmpty) {
        throw AuthException('Missing Facebook access token.');
      }

      final res = await _dio.post(
        '/auth/facebook/mobile',
        data: {'accessToken': accessToken},
      );

      final token = (res.data['token'] ?? '').toString();
      if (token.isEmpty) throw AuthException('Missing token in response.');
      final profile = UserProfile.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storeSession(token, profile);

      return profile;
    } on PlatformException catch (e) {
      throw AuthException(_providerMessage('Facebook', e));
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _dio.post('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/reset-password',
        data: {'email': email, 'token': token, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile?> me() async {
    try {
      final res = await _dio.get('/auth/me');
      final profile = UserProfile.fromJson(res.data as Map<String, dynamic>);
      await cacheProfile(profile);
      return profile;
    } on DioException {
      return null;
    }
  }

  Future<UserProfile> updateAvatar({
    required String character,
    String? skinTone,
    String? outfit,
  }) async {
    try {
      final res = await _dio.patch(
        '/auth/profile/avatar',
        data: {
          'character': character,
          if (skinTone != null) 'skin_tone': skinTone,
          if (outfit != null) 'outfit': outfit,
        },
      );
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> updateProfilePhoto({
    required String filePath,
    Uint8List? bytes,
    String? filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': bytes == null
            ? await MultipartFile.fromFile(
                filePath,
                filename: _fileNameFromPath(filePath),
              )
            : MultipartFile.fromBytes(
                bytes,
                filename: filename?.trim().isNotEmpty == true
                    ? filename!.trim()
                    : _fileNameFromPath(filePath),
              ),
      });
      final res = await _dio.patch(
        '/auth/profile/photo',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> updateCoverPhoto({
    required String filePath,
    Uint8List? bytes,
    String? filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': bytes == null
            ? await MultipartFile.fromFile(
                filePath,
                filename: _fileNameFromPath(filePath),
              )
            : MultipartFile.fromBytes(
                bytes,
                filename: filename?.trim().isNotEmpty == true
                    ? filename!.trim()
                    : _fileNameFromPath(filePath),
              ),
      });
      final res = await _dio.patch(
        '/auth/profile/cover-photo',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> updateSettings({
    required String username,
    required String email,
    required String address,
    required String contactNumber,
    required String sex,
    required String age,
  }) async {
    try {
      final res = await _dio.patch(
        '/auth/settings',
        data: {
          'username': username,
          'email': email,
          'address': address,
          'contact_number': contactNumber,
          'sex': sex,
          'age': age,
        },
      );
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  Future<UserProfile> updateFeedback({
    required int rating,
    required String review,
  }) async {
    try {
      final res = await _dio.patch(
        '/auth/feedback',
        data: {'rating': rating, 'review': review},
      );
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_dioMessage(e));
    }
  }

  static String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      final baseUrl =
        ApiConfig.baseUrl.isEmpty ? 'the API server' : ApiConfig.baseUrl;
      return 'The auth server at $baseUrl took too long to respond. '
        'Wait a minute for it to wake up, then try again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError) {
      final baseUrl =
          ApiConfig.baseUrl.isEmpty ? 'the API server' : ApiConfig.baseUrl;
      return 'Cannot reach the auth server at $baseUrl. '
          'Use a public HTTPS backend URL for access from any network.';
    }
    return e.message ?? 'Request failed.';
  }

  static String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'profile-photo.jpg' : name;
  }

  static String _providerMessage(String provider, PlatformException e) {
    final details = e.message ?? e.details?.toString() ?? e.code;
    if (provider == 'Google' && details.contains('ApiException: 10')) {
      return 'Google sign-in is not configured for this Android app yet.';
    }
    if (provider == 'Facebook' &&
        (details.contains('Invalid application ID') ||
            details.contains('YOUR_FACEBOOK_APP_ID'))) {
      return 'Facebook login is not configured yet.';
    }
    return '$provider sign-in failed. Please try again.';
  }
}
