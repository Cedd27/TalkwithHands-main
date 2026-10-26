class AlphabetSign {
  final String id;
  final String letter;
  final String title;
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

  const AlphabetSign({
    required this.id,
    required this.letter,
    required this.title,
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

  factory AlphabetSign.fromJson(Map<String, dynamic> json) {
    return AlphabetSign(
      id: (json['id'] ?? '').toString(),
      letter: (json['letter'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageAsset: (json['image_asset'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      videoAsset: (json['video_asset'] ?? '').toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      frontVideoUrl: (json['front_video_url'] ?? '').toString(),
      leftVideoUrl: (json['left_video_url'] ?? '').toString(),
      rightVideoUrl: (json['right_video_url'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sortOrder: int.tryParse((json['sort_order'] ?? '').toString()) ?? 0,
      isActive: json['is_active'] == true ||
          json['is_active']?.toString().toLowerCase() == 'true',
    );
  }
}
