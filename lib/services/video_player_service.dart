import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../utils/video_url_utils.dart';
import 'video_cache_service.dart';

class PlayableVideoSource {
  final String label;
  final String value;
  final bool isNetwork;

  const PlayableVideoSource({
    required this.label,
    required this.value,
    required this.isNetwork,
  });

  const PlayableVideoSource.network(this.label, this.value)
      : isNetwork = true;

  const PlayableVideoSource.asset(this.label, this.value)
      : isNetwork = false;
}

class VideoPlayerService {
  static const _initTimeout = Duration(seconds: 12);

  static List<PlayableVideoSource> buildSources({
    required String videoUrl,
    required String videoAsset,
  }) {
    final sources = <PlayableVideoSource>[];
    final proxyUrl = backendProxyVideoUrl(videoUrl);
    final backendAssetUrl = backendVideoUrl(videoAsset);
    final directUrl = normalizePlayableVideoUrl(videoUrl);

    if (proxyUrl != null) {
      sources.add(PlayableVideoSource.network('cached backend video', proxyUrl));
    }
    if (backendAssetUrl != null &&
        backendAssetUrl != proxyUrl &&
        backendAssetUrl != directUrl) {
      sources.add(PlayableVideoSource.network('backend asset', backendAssetUrl));
    }
    if (isBundledVideoAsset(videoAsset)) {
      sources.add(PlayableVideoSource.asset('bundled asset', videoAsset));
    }
    if (directUrl.isNotEmpty &&
        directUrl != proxyUrl &&
        directUrl != backendAssetUrl) {
      sources.add(PlayableVideoSource.network('direct video URL', directUrl));
    }

    return sources;
  }

  static Future<VideoPlayerController> createController({
    required List<PlayableVideoSource> sources,
    bool autoplay = true,
    bool looping = false,
    double volume = 1.0,
    double playbackSpeed = 1.0,
  }) async {
    final errors = <String>[];

    for (final source in sources) {
      VideoPlayerController? controller;
      try {
        if (source.isNetwork) {
          final cached = await VideoCacheService.instance.getCachedFile(source.value);
          if (cached != null) {
            controller = VideoPlayerController.file(cached);
          } else {
            controller = VideoPlayerController.networkUrl(Uri.parse(source.value));
          }
        } else {
          controller = VideoPlayerController.asset(source.value);
        }

        await controller.initialize().timeout(_initTimeout);
        await controller.setLooping(looping);
        await controller.setVolume(volume);
        await controller.setPlaybackSpeed(playbackSpeed);
        if (autoplay) {
          await controller.play();
        }

        if (source.isNetwork) {
          VideoCacheService.instance.prefetch(source.value);
        }

        return controller;
      } catch (error, stackTrace) {
        errors.add('${source.label}: $error');
        debugPrint('Video failed from ${source.label}: $error');
        debugPrintStack(stackTrace: stackTrace);
        await controller?.dispose();
      }
    }

    throw VideoLoadException(errors);
  }
}

class VideoLoadException implements Exception {
  final List<String> errors;

  const VideoLoadException(this.errors);

  @override
  String toString() => errors.join('\n');
}
