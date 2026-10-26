import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/basic_word.dart';
import 'api_config.dart';
import '../utils/video_url_utils.dart';

class BasicWordService {
  static const _excludedCategories = {
    'alphabet',
    'alphabets',
    'number',
    'numbers'
  };
  final Dio _dio;

  BasicWordService._(this._dio);

  factory BasicWordService() {
    final baseUrl = ApiConfig.requireBaseUrl();

    return BasicWordService._(
      Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Content-Type': 'application/json'},
        ),
      ),
    );
  }

  Future<List<BasicWord>> listBasicWords() async {
    try {
      final res = await _dio.get('/basic-words');
      final data = res.data;
      if (data is! List) {
        throw Exception('Invalid basic words response from server.');
      }
      if (_containsGoogleDriveUrl(data)) {
        return _loadBundledBasicWords();
      }
      return _parseAndSort(data);
    } catch (_) {
      return _loadBundledBasicWords();
    }
  }

  Future<List<BasicWord>> listAllBasicWords() async {
    final res = await _dio.get('/basic-words/admin');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid basic words admin response from server.');
    }
    return _parseAndSort(data);
  }

  Future<BasicWord> createBasicWord(Map<String, dynamic> payload) async {
    final res = await _dio.post('/basic-words', data: payload);
    return BasicWord.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<BasicWord> updateBasicWord(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/basic-words/$id', data: payload);
    return BasicWord.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteBasicWord(String id) async {
    await _dio.delete('/basic-words/$id');
  }

  /// Matches the records users can actually open in Basic Words.
  static bool isVisibleToUsers(BasicWord word) {
    if (!word.isActive ||
        _excludedCategories.contains(word.category.trim().toLowerCase())) {
      return false;
    }
    return hasPlayableVideoSource(
      videoAsset: word.videoAsset,
      videoUrl: word.videoUrl,
      frontVideoUrl: word.frontVideoUrl,
      leftVideoUrl: word.leftVideoUrl,
      rightVideoUrl: word.rightVideoUrl,
    );
  }

  Future<List<BasicWord>> _loadBundledBasicWords() async {
    final raw = await rootBundle.loadString('backend/data/basic-words.json');
    final data = jsonDecode(raw);
    if (data is! List) {
      throw Exception('Invalid bundled basic words data.');
    }
    return _parseAndSort(data);
  }

  List<BasicWord> _parseAndSort(List<dynamic> data) {
    return data
        .whereType<Map>()
        .map((item) => BasicWord.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
  }

  bool _containsGoogleDriveUrl(List<dynamic> data) {
    return data.any((item) {
      if (item is Map) {
        final category = (item['category'] ?? '').toString().toLowerCase();
        if (category == 'alphabet' ||
            category == 'number' ||
            category == 'numbers') {
          return false;
        }
      }

      final value = item.toString().toLowerCase();
      return value.contains('drive.google') ||
          value.contains('drive.usercontent.google') ||
          value.contains('docs.google');
    });
  }
}
