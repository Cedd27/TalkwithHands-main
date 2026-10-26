class PanoramaHotspot {
  final String id;
  final String key;
  final String label;
  final String videoAsset;
  final String videoUrl;
  final double yaw;
  final double pitch;
  final double size;
  final int sortOrder;

  const PanoramaHotspot({
    required this.id,
    required this.key,
    required this.label,
    required this.videoAsset,
    required this.videoUrl,
    required this.yaw,
    required this.pitch,
    required this.size,
    required this.sortOrder,
  });

  factory PanoramaHotspot.fromJson(Map<String, dynamic> json) {
    return PanoramaHotspot(
      id: (json['id'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      videoAsset: (json['video_asset'] ?? '').toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      yaw: double.tryParse((json['yaw'] ?? '').toString()) ?? 0,
      pitch: double.tryParse((json['pitch'] ?? '').toString()) ?? 0,
      size: double.tryParse((json['size'] ?? '').toString()) ?? 1,
      sortOrder: int.tryParse((json['sort_order'] ?? '').toString()) ?? 0,
    );
  }

  Map<String, dynamic> toViewerJson() {
    return {
      'id': id,
      'label': label,
      'videoAsset': videoAsset,
      'videoUrl': videoUrl,
      'yaw': yaw,
      'pitch': pitch,
      'size': size,
    };
  }
}

class PanoramaScene {
  final String id;
  final String key;
  final String title;
  final String imageAsset;
  final String imageUrl;
  final String icon;
  final int sortOrder;
  final List<PanoramaHotspot> hotspots;

  const PanoramaScene({
    required this.id,
    required this.key,
    required this.title,
    required this.imageAsset,
    required this.imageUrl,
    required this.icon,
    required this.sortOrder,
    required this.hotspots,
  });

  factory PanoramaScene.fromJson(Map<String, dynamic> json) {
    final hotspots = json['hotspots'];
    return PanoramaScene(
      id: (json['id'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageAsset: (json['image_asset'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      sortOrder: int.tryParse((json['sort_order'] ?? '').toString()) ?? 0,
      hotspots: hotspots is List
          ? hotspots
              .whereType<Map>()
              .map(
                (item) =>
                    PanoramaHotspot.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
          : const [],
    );
  }
}
