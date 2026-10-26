import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_progress.dart';
import 'api_config.dart';
import 'auth_service.dart';

class ProgressService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  ProgressService._(this._dio);

  factory ProgressService() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.requireBaseUrl(),
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

    return ProgressService._(dio);
  }

  Future<UserProgress> getProgress() async {
    try {
      final res = await _dio.get('/progress');
      return _withLocalGameCounts(
        UserProgress.fromJson(Map<String, dynamic>.from(res.data as Map)),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final res = await _dio.get('/auth/me');
        return _withLocalGameCounts(
          UserProgress.fromUserProfileJson(
            Map<String, dynamic>.from(res.data as Map),
          ),
        );
      }

      dev.log(
        'ProgressService.getProgress failed',
        name: 'ProgressService',
        error: e,
      );
      dev.log(
        'Status: ${e.response?.statusCode}  Body: \${e.response?.data}',
        name: 'ProgressService',
      );
      rethrow;
    } catch (e) {
      dev.log(
        'ProgressService.getProgress unexpected error',
        name: 'ProgressService',
        error: e,
      );
      rethrow;
    }
  }

  Future<UserProgress> recordActivity({
    required String category,
    String? itemKey,
    int secondsSpent = 0,
    bool gameCompleted = false,
    bool countEvent = true,
  }) async {
    if (category == 'game' && gameCompleted && itemKey != null) {
      await _incrementLocalGameCount(itemKey);
    }
    final res = await _dio.post(
      '/progress/activity',
      data: {
        'category': category,
        if (itemKey != null) 'item_key': itemKey,
        'seconds_spent': secondsSpent,
        'game_completed': gameCompleted,
        'count_event': countEvent,
      },
    );
    return _withLocalGameCounts(
      UserProgress.fromJson(Map<String, dynamic>.from(res.data as Map)),
    );
  }

  Future<void> _incrementLocalGameCount(String gameKey) async {
    final preferences = await SharedPreferences.getInstance();
    final key = await _localGameCountKey(gameKey);
    await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
  }

  Future<UserProgress> _withLocalGameCounts(UserProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    final accountScope = await _accountScope();
    final todayKey = _todayKey(DateTime.now());
    final games = progress.gameBreakdown.isEmpty
        ? const [
            GameProgressItem(key: 'guess_asl', label: 'Guess ASL', count: 0),
            GameProgressItem(key: 'guess_me', label: 'Guess Me', count: 0),
            GameProgressItem(key: 'calculator', label: 'Calculator', count: 0),
          ]
        : progress.gameBreakdown;

    final mergedGames = games.map((game) {
      final localCount = preferences.getInt(
            _localGameCountKeySync(accountScope, todayKey, game.key),
          ) ??
          0;
      return GameProgressItem(
        key: game.key,
        label: game.label,
        count: game.count > localCount ? game.count : localCount,
      );
    }).toList(growable: false);
    final mergedTotal =
        mergedGames.fold<int>(0, (sum, game) => sum + game.count);
    return progress.copyWith(
      stats: progress.stats.copyWith(
        gamesPlayed: progress.stats.gamesPlayed > mergedTotal
            ? progress.stats.gamesPlayed
            : mergedTotal,
      ),
      gameBreakdown: mergedGames,
    );
  }

  Future<String> _localGameCountKey(String gameKey) async {
    final accountScope = await _accountScope();
    return _localGameCountKeySync(
      accountScope,
      _todayKey(DateTime.now()),
      gameKey,
    );
  }

  Future<String> _accountScope() async {
    final profile = await AuthService.cachedProfile();
    final raw = (profile?.id.trim().isNotEmpty ?? false)
        ? profile!.id.trim()
        : (profile?.email ?? '').trim();
    return _sanitizeScope(raw.isEmpty ? 'guest' : raw);
  }

  String _localGameCountKeySync(
    String accountScope,
    String dateKey,
    String gameKey,
  ) {
    return 'progress_game_count_${accountScope}_${dateKey}_$gameKey';
  }

  String _todayKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _sanitizeScope(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }
}
