import 'package:dio/dio.dart';

import '../models/panorama_scene.dart';
import 'api_config.dart';

class PanoramaService {
  final Dio _dio;

  PanoramaService._(this._dio);

  factory PanoramaService() {
    final baseUrl = ApiConfig.requireBaseUrl();

    return PanoramaService._(
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

  // ── LOCAL HOTSPOT POSITIONS ────────────────────────────────────────────
  // The backend sends the hotspot yaw/pitch, but anything listed here
  // REPLACES the backend values (matched by hotspot id). Edit the numbers,
  // then do a full restart (or tap reload on the screen) to see the change.
  //   yaw   : left/right  (0 = image center, + = right, - = left)
  //   pitch : up/down     (+ = up, - = down)
  // Delete an entry to use the backend value again.
  static const Map<String, ({double yaw, double pitch})> _localHotspots = {
    'bench-tricycle': (yaw: -14, pitch: 7),
    'bench-tricycle-2': (yaw: -12, pitch: 3),
    'bench-road': (yaw: -20, pitch: 2),
    'bench-car': (yaw: 68, pitch: 15),
  };

  static const Set<String> _hiddenHotspotIds = {
    'bench-motorcycle',
    'bench-rock',
  };

  static const Map<String, dynamic> _roadHotspot = {
    'id': 'bench-road',
    'key': 'road',
    'label': 'Road',
    'video_asset': '',
    'video_url':
        'https://res.cloudinary.com/dxbupqx6u/video/upload/v1785891631/Road_jj8n9b.mp4',
    'yaw': 17,
    'pitch': 1,
    'size': 1,
    'sort_order': 4,
    'front_video_url':
        'https://res.cloudinary.com/dxbupqx6u/video/upload/v1785891596/road_front_vamoas.mp4',
    'left_video_url': '',
    'right_video_url': '',
    'image_url':
        'https://res.cloudinary.com/dxbupqx6u/image/upload/v1785888554/road_bzcoen.jpg',
  };

  Map<String, dynamic> _applyLocalHotspots(Map<String, dynamic> scene) {
    final raw = scene['hotspots'];
    if (raw is! List) return scene;

    final patched = <dynamic>[];
    var hasRoadHotspot = false;
    for (final h in raw) {
      if (h is! Map) {
        patched.add(h);
        continue;
      }
      final hotspot = Map<String, dynamic>.from(h);
      final id = hotspot['id']?.toString();
      if (id != null && _hiddenHotspotIds.contains(id)) continue;
      if (id == _roadHotspot['id']) hasRoadHotspot = true;

      final o = _localHotspots[id];
      if (o != null) {
        hotspot['yaw'] = o.yaw;
        hotspot['pitch'] = o.pitch;
      }
      patched.add(hotspot);
    }

    if (scene['id']?.toString() == 'bench' && !hasRoadHotspot) {
      patched.add(Map<String, dynamic>.from(_roadHotspot));
    }

    return {...scene, 'hotspots': patched};
  }

  Future<List<PanoramaScene>> listPanoramaScenes() async {
    final res = await _dio.get('/panorama-scenes');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid panorama response from server.');
    }

    return data
        .whereType<Map>()
        .map(
          (item) => PanoramaScene.fromJson(
            _applyLocalHotspots(Map<String, dynamic>.from(item)),
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}
