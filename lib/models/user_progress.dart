class UserProgress {
  final ProgressStats stats;
  final List<ProgressUsageItem> usage;
  final List<GameProgressItem> gameBreakdown;
  final List<MonthlyProgressPoint> monthlyActivity;
  final DateTime? updatedAt;

  const UserProgress({
    required this.stats,
    required this.usage,
    required this.gameBreakdown,
    required this.monthlyActivity,
    required this.updatedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      stats: ProgressStats.fromJson(
        json['stats'] is Map<String, dynamic>
            ? json['stats'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      usage: (json['usage'] is List ? json['usage'] as List : const [])
          .whereType<Map>()
          .map((item) =>
              ProgressUsageItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      gameBreakdown: (json['game_breakdown'] is List
              ? json['game_breakdown'] as List
              : const [])
          .whereType<Map>()
          .map((item) =>
              GameProgressItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      monthlyActivity: (json['monthly_activity'] is List
              ? json['monthly_activity'] as List
              : const [])
          .whereType<Map>()
          .map((item) =>
              MonthlyProgressPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  factory UserProgress.fromUserProfileJson(Map<String, dynamic> json) {
    final unlockedLevels = (json['unlocked_levels'] is List
            ? json['unlocked_levels'] as List
            : const [])
        .map((level) => level.toString())
        .toSet()
        .length;
    final stars = _asInt(json['stars']);
    final coins = _asInt(json['coins']);

    return UserProgress(
      stats: ProgressStats(
        signsLearned: unlockedLevels,
        totalSigns: 0,
        gamesPlayed: 0,
        secondsSpent: 0,
        streakDays: 0,
      ),
      usage: [
        ProgressUsageItem(
          category: 'alphabet_number',
          label: 'Alphabets & Numbers',
          count: unlockedLevels,
        ),
        ProgressUsageItem(
          category: 'basic_word',
          label: 'Basic Words',
          count: stars,
        ),
        ProgressUsageItem(
          category: 'detector',
          label: 'Sign Detector',
          count: coins,
        ),
        const ProgressUsageItem(
          category: 'game',
          label: 'Sign Games',
          count: 0,
        ),
      ],
      gameBreakdown: const [
        GameProgressItem(key: 'guess_asl', label: 'Guess ASL', count: 0),
        GameProgressItem(key: 'guess_me', label: 'Guess Me', count: 0),
        GameProgressItem(key: 'calculator', label: 'Calculator', count: 0),
      ],
      monthlyActivity: const [
        MonthlyProgressPoint(month: 'Jan', events: 0),
        MonthlyProgressPoint(month: 'Feb', events: 0),
        MonthlyProgressPoint(month: 'Mar', events: 0),
        MonthlyProgressPoint(month: 'Apr', events: 0),
        MonthlyProgressPoint(month: 'May', events: 0),
      ],
      updatedAt: null,
    );
  }

  UserProgress copyWith({
    ProgressStats? stats,
    List<ProgressUsageItem>? usage,
    List<GameProgressItem>? gameBreakdown,
    List<MonthlyProgressPoint>? monthlyActivity,
    DateTime? updatedAt,
  }) {
    return UserProgress(
      stats: stats ?? this.stats,
      usage: usage ?? this.usage,
      gameBreakdown: gameBreakdown ?? this.gameBreakdown,
      monthlyActivity: monthlyActivity ?? this.monthlyActivity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class GameProgressItem {
  final String key;
  final String label;
  final int count;

  const GameProgressItem({
    required this.key,
    required this.label,
    required this.count,
  });

  factory GameProgressItem.fromJson(Map<String, dynamic> json) {
    return GameProgressItem(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      count: _asInt(json['count']),
    );
  }
}

class ProgressStats {
  final int signsLearned;
  final int totalSigns;
  final int gamesPlayed;
  final int secondsSpent;
  final int streakDays;

  const ProgressStats({
    required this.signsLearned,
    required this.totalSigns,
    required this.gamesPlayed,
    required this.secondsSpent,
    required this.streakDays,
  });

  factory ProgressStats.fromJson(Map<String, dynamic> json) {
    return ProgressStats(
      signsLearned: _asInt(json['signs_learned']),
      totalSigns: _asInt(json['total_signs']),
      gamesPlayed: _asInt(json['games_played']),
      secondsSpent: _asInt(json['seconds_spent']),
      streakDays: _asInt(json['streak_days']),
    );
  }

  ProgressStats copyWith({
    int? signsLearned,
    int? totalSigns,
    int? gamesPlayed,
    int? secondsSpent,
    int? streakDays,
  }) {
    return ProgressStats(
      signsLearned: signsLearned ?? this.signsLearned,
      totalSigns: totalSigns ?? this.totalSigns,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      secondsSpent: secondsSpent ?? this.secondsSpent,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

class ProgressUsageItem {
  final String category;
  final String label;
  final int count;

  const ProgressUsageItem({
    required this.category,
    required this.label,
    required this.count,
  });

  factory ProgressUsageItem.fromJson(Map<String, dynamic> json) {
    return ProgressUsageItem(
      category: (json['category'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      count: _asInt(json['count']),
    );
  }
}

class MonthlyProgressPoint {
  final String month;
  final int events;

  const MonthlyProgressPoint({
    required this.month,
    required this.events,
  });

  factory MonthlyProgressPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyProgressPoint(
      month: (json['month'] ?? '').toString(),
      events: _asInt(json['events']),
    );
  }
}

int _asInt(Object? value) => int.tryParse((value ?? 0).toString()) ?? 0;
