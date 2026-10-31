import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/panorama_scene.dart';

const String panoramaHotspotDataAsset = 'assets/data/panorama_hotspots.json';

class PanoramaHotspotRecord {
  final String sceneId;
  final PanoramaHotspot hotspot;

  const PanoramaHotspotRecord({
    required this.sceneId,
    required this.hotspot,
  });

  factory PanoramaHotspotRecord.fromJson(Map<String, dynamic> json) {
    final sceneId = (json['sceneId'] ?? '').toString().trim();
    final id = (json['id'] ?? '').toString().trim();
    if (sceneId.isEmpty || id.isEmpty) {
      throw const FormatException(
        'Each panorama hotspot needs a sceneId and id.',
      );
    }

    return PanoramaHotspotRecord(
      sceneId: sceneId,
      hotspot: PanoramaHotspot(
        id: id,
        key: (json['key'] ?? id).toString(),
        label: (json['label'] ?? id).toString(),
        videoAsset: (json['videoAsset'] ?? '').toString(),
        videoUrl: (json['videoUrl'] ?? '').toString(),
        yaw: _readDouble(json['yaw'], 'yaw'),
        pitch: _readDouble(json['pitch'], 'pitch'),
        size: _readDouble(json['size'] ?? 1, 'size'),
        sortOrder: _readInt(json['sortOrder'] ?? 0, 'sortOrder'),
      ),
    );
  }

  factory PanoramaHotspotRecord.fromHotspot(
    String sceneId,
    PanoramaHotspot hotspot,
  ) {
    return PanoramaHotspotRecord(sceneId: sceneId, hotspot: hotspot);
  }

  Map<String, Object> toJson() => {
        'sceneId': sceneId,
        'id': hotspot.id,
        'key': hotspot.key,
        'label': hotspot.label,
        'videoAsset': hotspot.videoAsset,
        'videoUrl': hotspot.videoUrl,
        'yaw': hotspot.yaw,
        'pitch': hotspot.pitch,
        'size': hotspot.size,
        'sortOrder': hotspot.sortOrder,
      };

  static double _readDouble(Object? value, String field) {
    final parsed = double.tryParse(value.toString());
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Panorama hotspot $field must be a finite number.');
    }
    return parsed;
  }

  static int _readInt(Object? value, String field) {
    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('Panorama hotspot $field must be an integer.');
    }
    return parsed;
  }
}

class PanoramaHotspotData {
  final List<PanoramaHotspotRecord> hotspots;
  final Set<String> deletedHotspotIds;

  const PanoramaHotspotData({
    this.hotspots = const [],
    this.deletedHotspotIds = const {},
  });

  factory PanoramaHotspotData.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException(
          'Panorama hotspot data must be a JSON object.');
    }
    final map = Map<String, dynamic>.from(value);
    final rawHotspots = map['hotspots'] ?? const [];
    final rawDeleted = map['deletedHotspotIds'] ?? const [];
    if (rawHotspots is! List || rawDeleted is! List) {
      throw const FormatException(
        'Panorama hotspot data needs hotspot and deleted ID lists.',
      );
    }

    return PanoramaHotspotData(
      hotspots: rawHotspots.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Each panorama hotspot must be a JSON object.',
          );
        }
        return PanoramaHotspotRecord.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList(growable: false),
      deletedHotspotIds: rawDeleted.map((item) => item.toString()).toSet(),
    );
  }

  Map<String, Object> toJson() => {
        'hotspots': hotspots.map((record) => record.toJson()).toList(),
        'deletedHotspotIds': deletedHotspotIds.toList()..sort(),
      };
}

Future<PanoramaHotspotData> loadPanoramaHotspotData() async {
  final contents = await rootBundle.loadString(panoramaHotspotDataAsset);
  return PanoramaHotspotData.fromJson(jsonDecode(contents));
}

List<PanoramaScene> applyPanoramaHotspotData(
  List<PanoramaScene> scenes,
  PanoramaHotspotData data,
) {
  return scenes.map((scene) {
    final hotspots = scene.hotspots
        .where((hotspot) => !data.deletedHotspotIds.contains(hotspot.id))
        .toList();
    for (final record
        in data.hotspots.where((item) => item.sceneId == scene.id)) {
      final index = hotspots.indexWhere((item) => item.id == record.hotspot.id);
      if (index == -1) {
        hotspots.add(record.hotspot);
      } else {
        hotspots[index] = record.hotspot;
      }
    }
    return PanoramaScene(
      id: scene.id,
      key: scene.key,
      title: scene.title,
      imageAsset: scene.imageAsset,
      imageUrl: scene.imageUrl,
      icon: scene.icon,
      sortOrder: scene.sortOrder,
      hotspots: hotspots,
    );
  }).toList(growable: false);
}
