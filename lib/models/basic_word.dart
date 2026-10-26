class BasicWord {
  final String id;
  final String key;
  final String title;
  final String category;
  final String imageAsset;
  final String imageUrl;
  final String videoAsset;
  final String videoUrl;
  final String frontVideoUrl;
  final String leftVideoUrl;
  final String rightVideoUrl;
  final String description;
  final int sortOrder;
  final bool isActive;

  const BasicWord({
    required this.id,
    required this.key,
    required this.title,
    required this.category,
    required this.imageAsset,
    required this.imageUrl,
    required this.videoAsset,
    required this.videoUrl,
    required this.frontVideoUrl,
    required this.leftVideoUrl,
    required this.rightVideoUrl,
    required this.description,
    required this.sortOrder,
    required this.isActive,
  });

  factory BasicWord.fromJson(Map<String, dynamic> json) {
    return BasicWord(
      id: (json['id'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      imageAsset: (json['image_asset'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      videoAsset: (json['video_asset'] ?? '').toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      frontVideoUrl: (json['front_video_url'] ?? '').toString(),
      leftVideoUrl: (json['left_video_url'] ?? '').toString(),
      rightVideoUrl: (json['right_video_url'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sortOrder: int.tryParse((json['sort_order'] ?? '').toString()) ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}
