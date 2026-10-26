import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class VideoCacheService {
  VideoCacheService._();

  static final VideoCacheService instance = VideoCacheService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  final Map<String, Future<File?>> _inflight = {};

  Future<File?> getCachedFile(String url) async {
    final file = await _cacheFileFor(url);
    if (await file.exists() && await file.length() > 0) {
      return file;
    }
    return null;
  }

  Future<File?> downloadToCache(String url) {
    return _inflight.putIfAbsent(url, () async {
      try {
        final file = await _cacheFileFor(url);
        await file.parent.create(recursive: true);
        final temp = File('${file.path}.partial');
        await _dio.download(url, temp.path);
        if (await file.exists()) {
          await temp.delete();
        } else {
          await temp.rename(file.path);
        }
        return file;
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(url);
      }
    });
  }

  void prefetch(String url) {
    unawaited(downloadToCache(url));
  }

  Future<File> _cacheFileFor(String url) async {
    final dir = await getTemporaryDirectory();
    final digest = md5.convert(utf8.encode(url)).toString();
    return File('${dir.path}/video_cache/$digest.mp4');
  }
}
