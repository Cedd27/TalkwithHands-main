class AdminAnalytics {
  final AnalyticsSummary summary;
  final List<MonthlyUsersPoint> monthlyUsers;
  final List<AnalyticsCount> sexCounts;
  final List<AnalyticsCount> ageCounts;
  final List<AnalyticsCount> usageCounts;
  final List<AnalyticsUser> users;
  final List<AnalyticsReview> reviews;

  const AdminAnalytics({
    required this.summary,
    required this.monthlyUsers,
    required this.sexCounts,
    required this.ageCounts,
    required this.usageCounts,
    required this.users,
    required this.reviews,
  });

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    return AdminAnalytics(
      summary: AnalyticsSummary.fromJson(
        json['summary'] is Map<String, dynamic>
            ? json['summary'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      monthlyUsers: _list(json['monthly_users'])
          .map((item) => MonthlyUsersPoint.fromJson(item))
          .toList(),
      sexCounts: _list(json['sex_counts'])
          .map((item) => AnalyticsCount.fromJson(item))
          .toList(),
      ageCounts: _list(json['age_counts'])
          .map((item) => AnalyticsCount.fromJson(item))
          .toList(),
      usageCounts: _list(json['usage_counts'])
          .map((item) => AnalyticsCount.fromJson(item))
          .toList(),
      users: _list(json['users'])
          .map((item) => AnalyticsUser.fromJson(item))
          .toList(),
      reviews: _list(json['reviews'])
          .map((item) => AnalyticsReview.fromJson(item))
          .toList(),
    );
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class AnalyticsSummary {
  final int totalUsers;
  final double averageRating;
  final int ratingCount;

  const AnalyticsSummary({
    required this.totalUsers,
    required this.averageRating,
    required this.ratingCount,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalUsers: int.tryParse((json['total_users'] ?? 0).toString()) ?? 0,
      averageRating:
          double.tryParse((json['average_rating'] ?? 0).toString()) ?? 0,
      ratingCount: int.tryParse((json['rating_count'] ?? 0).toString()) ?? 0,
    );
  }
}

class MonthlyUsersPoint {
  final String key;
  final String label;
  final int count;

  const MonthlyUsersPoint({
    required this.key,
    required this.label,
    required this.count,
  });

  factory MonthlyUsersPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyUsersPoint(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      count: int.tryParse((json['count'] ?? 0).toString()) ?? 0,
    );
  }
}

class AnalyticsCount {
  final String label;
  final int count;

  const AnalyticsCount({
    required this.label,
    required this.count,
  });

  factory AnalyticsCount.fromJson(Map<String, dynamic> json) {
    return AnalyticsCount(
      label: (json['label'] ?? '').toString(),
      count: int.tryParse((json['count'] ?? 0).toString()) ?? 0,
    );
  }
}

class AnalyticsUser {
  final String id;
  final String name;
  final String email;
  final String address;
  final String phone;
  final String sex;
  final int? age;
  final DateTime? date;
  final int stars;
  final int coins;

  const AnalyticsUser({
    required this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.phone,
    required this.sex,
    required this.age,
    required this.date,
    required this.stars,
    required this.coins,
  });

  factory AnalyticsUser.fromJson(Map<String, dynamic> json) {
    return AnalyticsUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      sex: (json['sex'] ?? '').toString(),
      age: json['age'] == null ? null : int.tryParse(json['age'].toString()),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      stars: int.tryParse((json['stars'] ?? 0).toString()) ?? 0,
      coins: int.tryParse((json['coins'] ?? 0).toString()) ?? 0,
    );
  }
}

class AnalyticsReview {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final int rating;
  final String review;
  final DateTime? date;

  const AnalyticsReview({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.rating,
    required this.review,
    required this.date,
  });

  factory AnalyticsReview.fromJson(Map<String, dynamic> json) {
    return AnalyticsReview(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      photoUrl: (json['photo_url'] ?? '').toString(),
      rating: int.tryParse((json['rating'] ?? 0).toString()) ?? 0,
      review: (json['review'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
    );
  }
}
