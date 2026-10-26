class UserProfile {
  final String id;
  final String? username;
  final String? email;
  final String? photoUrl;
  final String? coverPhotoUrl;
  final int stars;
  final int coins;
  final List<int> unlockedLevels;
  final String address;
  final String contactNumber;
  final String sex;
  final int? age;
  final AppFeedback appFeedback;
  final AvatarPreferences avatarPreferences;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.photoUrl,
    this.coverPhotoUrl,
    required this.stars,
    required this.coins,
    required this.unlockedLevels,
    required this.address,
    required this.contactNumber,
    required this.sex,
    required this.age,
    required this.appFeedback,
    required this.avatarPreferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar_preferences'];
    return UserProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      username: json['username']?.toString(),
      email: json['email']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      coverPhotoUrl: json['cover_photo_url']?.toString(),
      stars: (json['stars'] ?? 0) as int,
      coins: (json['coins'] ?? 0) as int,
      unlockedLevels: ((json['unlocked_levels'] ?? const <dynamic>[1]) as List)
          .map((e) => int.tryParse(e.toString()) ?? 1)
          .toList(),
      address: (json['address'] ?? '').toString(),
      contactNumber: (json['contact_number'] ?? '').toString(),
      sex: (json['sex'] ?? '').toString(),
      age: json['age'] == null ? null : int.tryParse(json['age'].toString()),
      appFeedback: AppFeedback.fromJson(
        json['app_feedback'] is Map<String, dynamic>
            ? json['app_feedback'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      avatarPreferences: AvatarPreferences.fromJson(
        avatarJson is Map<String, dynamic>
            ? avatarJson
            : const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'photo_url': photoUrl,
      'cover_photo_url': coverPhotoUrl,
      'stars': stars,
      'coins': coins,
      'unlocked_levels': unlockedLevels,
      'address': address,
      'contact_number': contactNumber,
      'sex': sex,
      'age': age,
      'app_feedback': appFeedback.toJson(),
      'avatar_preferences': avatarPreferences.toJson(),
    };
  }
}

class AppFeedback {
  final int rating;
  final String review;
  final DateTime? updatedAt;

  const AppFeedback({
    required this.rating,
    required this.review,
    required this.updatedAt,
  });

  factory AppFeedback.fromJson(Map<String, dynamic> json) {
    final parsedRating = int.tryParse((json['rating'] ?? 0).toString()) ?? 0;
    final clampedRating = parsedRating < 0 ? 0 : parsedRating > 5 ? 5 : parsedRating;
    return AppFeedback(
      rating: clampedRating,
      review: (json['review'] ?? '').toString(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'review': review,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class AvatarPreferences {
  final String character;
  final String skinTone;
  final String outfit;

  const AvatarPreferences({
    required this.character,
    required this.skinTone,
    required this.outfit,
  });

  factory AvatarPreferences.fromJson(Map<String, dynamic> json) {
    return AvatarPreferences(
      character: (json['character'] ?? 'hera').toString(),
      skinTone: (json['skin_tone'] ?? 'default').toString(),
      outfit: (json['outfit'] ?? 'school').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character': character,
      'skin_tone': skinTone,
      'outfit': outfit,
    };
  }
}
