import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language_app/data/panorama_hotspot_data.dart';
import 'package:sign_language_app/models/panorama_scene.dart';

void main() {
  const scene = PanoramaScene(
    id: 'classroom',
    key: 'classroom',
    title: 'Classroom',
    imageAsset: 'assets/360/Classroom.png',
    imageUrl: '',
    icon: 'classroom',
    sortOrder: 1,
    hotspots: [
      PanoramaHotspot(
        id: 'chair',
        key: 'chair',
        label: 'Chair',
        videoAsset: '',
        videoUrl: '',
        yaw: 10,
        pitch: 2,
        size: 1,
        sortOrder: 0,
      ),
    ],
  );

  test('saved hotspot data overrides and adds scene-specific hotspots', () {
    final data = PanoramaHotspotData.fromJson({
      'hotspots': [
        {
          'sceneId': 'classroom',
          'id': 'chair',
          'key': 'chair',
          'label': 'Chair video',
          'videoAsset': 'assets/chair.mp4',
          'videoUrl': '',
          'yaw': 25,
          'pitch': -5,
          'size': 1.2,
          'sortOrder': 0,
        },
        {
          'sceneId': 'classroom',
          'id': 'window',
          'key': 'window',
          'label': 'Window',
          'videoAsset': 'assets/window.mp4',
          'videoUrl': '',
          'yaw': 50,
          'pitch': 0,
          'size': 1,
          'sortOrder': 1,
        },
      ],
      'deletedHotspotIds': [],
    });

    final result = applyPanoramaHotspotData([scene], data).single.hotspots;
    expect(result, hasLength(2));
    expect(result.first.label, 'Chair video');
    expect(result.first.yaw, 25);
    expect(result.last.id, 'window');
  });

  test('saved deleted IDs hide matching API hotspots', () {
    final data = PanoramaHotspotData.fromJson({
      'hotspots': [],
      'deletedHotspotIds': ['chair'],
    });

    expect(applyPanoramaHotspotData([scene], data).single.hotspots, isEmpty);
  });

  test('hotspot JSON round-trips scene coordinates and video path', () {
    final data = PanoramaHotspotData.fromJson({
      'hotspots': [
        {
          'sceneId': 'classroom',
          'id': 'chair',
          'key': 'chair',
          'label': 'Chair',
          'videoAsset': 'assets/chair.mp4',
          'videoUrl': '',
          'yaw': 42.5,
          'pitch': -7.25,
          'size': 1.2,
          'sortOrder': 0,
        },
      ],
      'deletedHotspotIds': ['old'],
    });

    final restored = PanoramaHotspotData.fromJson(data.toJson());
    expect(restored.hotspots.single.sceneId, 'classroom');
    expect(restored.hotspots.single.hotspot.yaw, 42.5);
    expect(restored.hotspots.single.hotspot.pitch, -7.25);
    expect(restored.hotspots.single.hotspot.videoAsset, 'assets/chair.mp4');
    expect(restored.deletedHotspotIds, {'old'});
  });
}
