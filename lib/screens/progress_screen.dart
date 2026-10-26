import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/user_progress.dart';
import '../services/activity_time_service.dart';
import '../services/background_music_service.dart';
import '../services/progress_service.dart';
import '../ui/app_shell.dart';
import '../ui/background_music_region.dart';
import '../widgets/transparent_sign_video_overlay.dart';

// ── Colour tokens (matching Alphabets screen) ────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);

class ProgressScreen extends StatefulWidget {
  final String userName;

  const ProgressScreen({
    super.key,
    required this.userName,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ProgressService _progressService;
  late Future<UserProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressService = ProgressService();
    _progressFuture = _progressService.getProgress();
  }

  Future<void> _refreshProgress() async {
    final future = _progressService.getProgress();
    setState(() {
      _progressFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Progress',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/NEW BACKGROUND/new progress.png',
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: _FloatingBubbles(),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // ── Top Bar ──────────────────────────────────────────────
                    AppTopBar(
                      onBack: () => Navigator.of(context).pop(),
                      onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),

                    // ── Big Bold Title ───────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        'PROGRESS',
                        style: TextStyle(
                          color: Color(0xFF1500C8),
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              offset: Offset(3, 4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Video Banner ─────────────────────────────────────────
                    // Decorative icons sit BEHIND the avatar video (added
                    // first = bottom of the Stack) and are pushed out to
                    // the corners so the avatar — which overflows its
                    // SizedBox a little — never covers them.
                    const SizedBox(
                      height: 128,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 6,
                            top: 4,
                            child: _BackgroundIcon(
                              icon: Icons.emoji_events_rounded,
                              color: Color(0xFFFFB800),
                              size: 22,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: _BackgroundIcon(
                              icon: Icons.auto_awesome_rounded,
                              color: kAccent,
                              size: 18,
                            ),
                          ),
                          Positioned(
                            left: 14,
                            bottom: 6,
                            child: _BackgroundIcon(
                              icon: Icons.star_rounded,
                              color: Color(0xFF8B3FBE),
                              size: 18,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 0,
                            child: _BackgroundIcon(
                              icon: Icons.favorite_rounded,
                              color: Color(0xFFFF6B8B),
                              size: 16,
                            ),
                          ),
                          Center(
                            child: SizedBox(
                              height: 140,
                              width: 235,
                              child: TransparentSignVideoOverlay(
                                videoAsset: 'assets/Progress.mp4',
                                fit: BoxFit.contain,
                                volume: 0,
                                threshold: 0.34,
                                smoothing: 0.08,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Main Panel ───────────────────────────────────────────
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 4, 51, 98)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color.fromARGB(255, 156, 156, 156)
                                .withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 186, 182, 182)
                                  .withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: RefreshIndicator(
                            onRefresh: _refreshProgress,
                            color: kVividBlue,
                            child: FutureBuilder<UserProgress>(
                              future: _progressFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  );
                                }
                                if (snapshot.hasError ||
                                    snapshot.data == null) {
                                  return _ProgressError(
                                    onRetry: _refreshProgress,
                                  );
                                }
                                return SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 16, 14, 20),
                                  child: _ProgressContent(
                                    firstName: _firstName,
                                    progress: snapshot.data!,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _firstName {
    final parts = widget.userName.trim().split(' ');
    final name = parts.isNotEmpty ? parts.first : widget.userName;
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }
}

// ── Main Content ─────────────────────────────────────────────────────────────
class _ProgressContent extends StatelessWidget {
  final String firstName;
  final UserProgress progress;

  const _ProgressContent({
    required this.firstName,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final stats = progress.stats;
    final usage = progress.usage;
    final games = progress.gameBreakdown;
    final monthly = progress.monthlyActivity;

    return Column(
      children: [
        _HeroCard(firstName: firstName, streak: stats.streakDays),
        const SizedBox(height: 14),
        _StatsRow(stats: stats, progress: progress),
        const SizedBox(height: 14),
        _SlidingChartRow(usage: usage, games: games, monthly: monthly),
        if (stats.signsLearned == 0 &&
            stats.gamesPlayed == 0 &&
            stats.secondsSpent == 0) ...[
          const SizedBox(height: 14),
          const _EmptyProgressCard(),
        ],
      ],
    );
  }
}

// ── Decorative icon behind the avatar video ──────────────────────────────────
// Plain and simple — no background shape, just a soft drop shadow so the
// icon still reads clearly against the busy background/video underneath.
class _BackgroundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _BackgroundIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color.withValues(alpha: 0.85),
      size: size,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }
}

// ── Hero Banner ──────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String firstName;
  final int streak;

  const _HeroCard({required this.firstName, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1747C4), Color(0xFF2E63E0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1747C4).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: 'Kumusta, ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        TextSpan(
                          text: '$firstName!',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep up the great work!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFFB800),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final dynamic stats;
  final UserProgress progress;

  const _StatsRow({
    required this.stats,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final totalSignsValue = stats.totalSigns > 0
        ? '${stats.signsLearned}/${stats.totalSigns}'
        : stats.signsLearned.toString();

    final rawTodaySeconds = stats.secondsSpent ?? 0;
    final int todayBaseSeconds =
        rawTodaySeconds >= 24 * 60 * 60 ? 0 : math.max(0, rawTodaySeconds);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_rounded,
            value: totalSignsValue,
            label: 'Signs Learned',
            color: const Color.fromARGB(255, 0, 104, 116),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.sports_esports_rounded,
            value: stats.gamesPlayed.toString(),
            label: 'Games Played',
            color: const Color.fromARGB(255, 93, 6, 151),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: ActivityTimeService.instance.liveSessionSeconds,
            builder: (context, liveSeconds, _) {
              final todayTotalSeconds = math
                  .max(todayBaseSeconds, liveSeconds)
                  .clamp(0, 24 * 60 * 60)
                  .toInt();
              return _StatCard(
                icon: Icons.timer_rounded,
                value: _formatDigitalTime(todayTotalSeconds),
                label: 'Time Spent Today',
                color: const Color.fromARGB(255, 0, 145, 37),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF071A3F),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  color: Color.fromARGB(255, 64, 72, 82),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sliding Chart Section ───────────────────────────────────────────────────
class _SlidingChartRow extends StatefulWidget {
  final List<ProgressUsageItem> usage;
  final List<GameProgressItem> games;
  final List<MonthlyProgressPoint> monthly;

  const _SlidingChartRow({
    required this.usage,
    required this.games,
    required this.monthly,
  });

  @override
  State<_SlidingChartRow> createState() => _SlidingChartRowState();
}

class _SlidingChartRowState extends State<_SlidingChartRow> {
  final PageController _pageController = PageController(viewportFraction: 0.96);
  int _currentPage = 0;
  int? _selectedDonutIndex;
  int? _selectedLineIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _CleanCard(
        title: 'Most Used',
        icon: Icons.donut_large_rounded,
        accent: const Color.fromARGB(255, 3, 143, 158),
        child: Row(
          children: [
            _TappableDonut(
              usage: widget.usage,
              selectedIndex: _selectedDonutIndex,
              onTap: (idx) => setState(() {
                _selectedDonutIndex = (_selectedDonutIndex == idx) ? null : idx;
              }),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.usage.length; i++) ...[
                    _LegendDot(
                      color: _usageColors[i % _usageColors.length],
                      label:
                          '${widget.usage[i].label} (${widget.usage[i].count})',
                      highlighted: _selectedDonutIndex == i,
                    ),
                    if (i != widget.usage.length - 1) const SizedBox(height: 8),
                  ],
                  if (widget.usage.isEmpty)
                    const Text(
                      'No activity recorded yet.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      _CleanCard(
        title: 'Games Played',
        icon: Icons.bar_chart_rounded,
        accent: const Color.fromARGB(255, 93, 6, 151),
        child: _GameBarChart(games: widget.games),
      ),
      _CleanCard(
        title: 'Monthly Activity',
        icon: Icons.show_chart_rounded,
        accent: const Color.fromARGB(255, 0, 157, 39),
        child: _TappableLineChart(
          monthly: widget.monthly,
          selectedIndex: _selectedLineIndex,
          onTap: (idx) => setState(() {
            _selectedLineIndex = (_selectedLineIndex == idx) ? null : idx;
          }),
        ),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: pages[index],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.white : Colors.white38,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Clean Card Outer Container ───────────────────────────────────────────────
class _CleanCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Color accent;

  const _CleanCard({
    required this.title,
    required this.child,
    this.icon,
    this.accent = kVividBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(179, 255, 255, 255),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDF1F7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 15),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF071A3F),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ProgressError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ProgressError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cannot load progress. Make sure the backend is running.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: kVividBlue,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12, width: 1.2),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProgressCard extends StatelessWidget {
  const _EmptyProgressCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 95,
      child: _CleanCard(
        title: 'Let\'s Get Started!',
        icon: Icons.rocket_launch_rounded,
        accent: kVividBlue,
        child: Text(
          'Start learning signs or playing games to record your overall progress.',
          style: TextStyle(
            color: Color(0xFF64748B),
            height: 1.35,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _GameBarChart extends StatelessWidget {
  final List<GameProgressItem> games;

  const _GameBarChart({required this.games});

  @override
  Widget build(BuildContext context) {
    final items = games.isEmpty
        ? const [
            GameProgressItem(key: 'guess_asl', label: 'Guess ASL', count: 0),
            GameProgressItem(key: 'guess_me', label: 'Guess Me', count: 0),
            GameProgressItem(key: 'calculator', label: 'Calculator', count: 0),
          ]
        : games;
    final maxCount = items.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _GameBar(
            item: items[i],
            color: _usageColors[(i + 1) % _usageColors.length],
            fraction: items[i].count / maxCount,
          ),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GameBar extends StatelessWidget {
  final GameProgressItem item;
  final Color color;
  final double fraction;

  const _GameBar({
    required this.item,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 18, color: const Color(0xFFE2E8F0)),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(height: 18, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            item.count.toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF071A3F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDigitalTime(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;

  final hStr = hours.toString().padLeft(2, '0');
  final mStr = minutes.toString().padLeft(2, '0');
  final sStr = seconds.toString().padLeft(2, '0');

  return '$hStr:$mStr:$sStr';
}

const _usageColors = [
  kAccent,
  kGreen,
  Color(0xFF8B3FBE),
  Color(0xFF2196F3),
];

// ── Legend Item ───────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool highlighted;

  const _LegendDot({
    required this.color,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: highlighted
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlighted
                    ? const Color(0xFF071A3F)
                    : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable Donut Widget ────────────────────────────────────────────────────
class _TappableDonut extends StatelessWidget {
  final List<ProgressUsageItem> usage;
  final int? selectedIndex;
  final ValueChanged<int?> onTap;

  const _TappableDonut({
    required this.usage,
    required this.selectedIndex,
    required this.onTap,
  });

  int? _hitTest(Offset localPos, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2.4;
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < radius - 16 || dist > radius + 16) return null;

    final total = usage.fold<int>(0, (sum, item) => sum + item.count);
    if (total <= 0) return null;

    var angle = math.atan2(dy, dx);
    angle = (angle + math.pi / 2 + math.pi * 2) % (math.pi * 2);

    var start = 0.0;
    for (var i = 0; i < usage.length; i++) {
      final sweep = math.pi * 2 * (usage[i].count / total);
      if (angle >= start && angle < start + sweep) return i;
      start += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final idx = _hitTest(local, box.size);
        if (idx != null) onTap(selectedIndex == idx ? null : idx);
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: CustomPaint(
          painter: _DonutPainter(usage, selectedIndex: selectedIndex),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<ProgressUsageItem> usage;
  final int? selectedIndex;

  const _DonutPainter(this.usage, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width / 2.4;
    final total = usage.fold<int>(0, (sum, item) => sum + item.count);

    if (total <= 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius),
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < usage.length; i++) {
      final sweep = math.pi * 2 * (usage[i].count / total);
      final isSelected = selectedIndex == i;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius),
        start,
        sweep,
        false,
        Paint()
          ..color = _usageColors[i % _usageColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 22.0 : 18.0
          ..strokeCap = StrokeCap.butt,
      );

      if (isSelected) {
        final pct = (usage[i].count / total * 100).round();
        final centerTp = TextPainter(
          text: TextSpan(
            text: '$pct%',
            style: TextStyle(
              color: _usageColors[i % _usageColors.length],
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        centerTp.paint(
          canvas,
          Offset(
            center.dx - centerTp.width / 2,
            center.dy - centerTp.height / 2,
          ),
        );
      }

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex || oldDelegate.usage != usage;
}

// ── Line Chart ───────────────────────────────────────────────────────────────
class _TappableLineChart extends StatelessWidget {
  final List<MonthlyProgressPoint> monthly;
  final int? selectedIndex;
  final ValueChanged<int?> onTap;

  const _TappableLineChart({
    required this.monthly,
    required this.selectedIndex,
    required this.onTap,
  });

  // Picks the month whose point is closest horizontally to the tap, so the
  // whole column around each point is tappable (not just a tiny circle).
  int? _hitTest(Offset localPos, Size size) {
    if (monthly.isEmpty) return null;
    final spacing =
        monthly.length == 1 ? size.width : size.width / (monthly.length - 1);
    final tolerance = spacing / 2 < 24 ? 24.0 : spacing / 2;
    int? nearest;
    double minDist = tolerance;
    for (var i = 0; i < monthly.length; i++) {
      final x = monthly.length == 1 ? size.width / 2 : spacing * i;
      final dist = (localPos.dx - x).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final idx = _hitTest(local, box.size);
        if (idx != null) onTap(selectedIndex == idx ? null : idx);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 100,
        child: CustomPaint(
          painter: _LineChartPainter(monthly, selectedIndex: selectedIndex),
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < monthly.length; i++)
                      Text(
                        monthly[i].month,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? const Color(0xFF071A3F)
                              : const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<MonthlyProgressPoint> points;
  final int? selectedIndex;

  const _LineChartPainter(this.points, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = kVividBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (points.isEmpty) return;

    final maxEvents = points.fold<int>(
      1,
      (max, point) => point.events > max ? point.events : max,
    );
    final chartPoints = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(
          points.length == 1
              ? size.width / 2
              : size.width * i / (points.length - 1),
          size.height * 0.8 -
              (size.height * 0.62 * (points[i].events / maxEvents)),
        ),
    ];

    final path = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (final p in chartPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    for (var i = 0; i < chartPoints.length; i++) {
      final p = chartPoints[i];
      final isSelected = selectedIndex == i;
      canvas.drawCircle(p, isSelected ? 5 : 3.5, Paint()..color = kVividBlue);
      canvas.drawCircle(p, isSelected ? 2 : 1.5, Paint()..color = Colors.white);

      if (isSelected) {
        final label = '${points[i].events}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        const padding = 4.0;
        final tooltipW = tp.width + padding * 2;
        final tooltipH = tp.height + padding * 1.5;
        var tooltipX = p.dx - tooltipW / 2;
        tooltipX = tooltipX.clamp(0, size.width - tooltipW);
        final tooltipY = p.dy - tooltipH - 6;

        final tooltipRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            tooltipX,
            tooltipY.clamp(0, size.height - tooltipH),
            tooltipW,
            tooltipH,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(tooltipRect, Paint()..color = const Color(0xFF071A3F));

        tp.paint(
          canvas,
          Offset(
            tooltipX + padding,
            tooltipRect.top + (tooltipH - tp.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.points != points;
}

// ── Decorative floating bubbles background layer ─────────────────────────────
const List<Color> _bubbleColors = [
  kVividBlue,
  kAccent,
  kGreen,
  Color(0xFF0B8FFF),
  Color(0xFF9C27B0),
];

class _BubbleSpec {
  final double dx;
  final double size;
  final double speed;
  final double phase;
  final double wobble;
  final Color color;
  final bool outline;

  const _BubbleSpec({
    required this.dx,
    required this.size,
    required this.speed,
    required this.phase,
    required this.wobble,
    required this.color,
    required this.outline,
  });
}

class _FloatingBubbles extends StatefulWidget {
  const _FloatingBubbles();

  @override
  State<_FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<_FloatingBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_BubbleSpec> _bubbles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    final rnd = math.Random(7);
    _bubbles = List.generate(16, (i) {
      final color = _bubbleColors[rnd.nextInt(_bubbleColors.length)];
      return _BubbleSpec(
        dx: rnd.nextDouble(),
        size: 14 + rnd.nextDouble() * 46,
        speed: 0.45 + rnd.nextDouble() * 0.85,
        phase: rnd.nextDouble(),
        wobble: 8 + rnd.nextDouble() * 18,
        color: color,
        outline: rnd.nextDouble() < 0.4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: canvasSize,
              painter: _BubblesPainter(
                bubbles: _bubbles,
                progress: _controller.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final List<_BubbleSpec> bubbles;
  final double progress;

  _BubblesPainter({required this.bubbles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (final b in bubbles) {
      final t = (progress * b.speed + b.phase) % 1.0;
      final y = size.height * (1 - t);
      final wobbleX = math.sin((t * 2 * math.pi) + b.phase * 10) * b.wobble;
      final x = size.width * b.dx + wobbleX;
      final radius = b.size / 2;

      final envelope = math.sin(math.pi * t).clamp(0.0, 1.0);
      final opacity = 0.08 + 0.16 * envelope;

      if (b.outline) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = b.color.withValues(alpha: opacity * 1.6);
        canvas.drawCircle(Offset(x, y), radius, ring);
      } else {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = b.color.withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), radius, fill);
      }

      final highlight = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: opacity * 1.4);
      canvas.drawCircle(
        Offset(x - radius * 0.32, y - radius * 0.32),
        radius * 0.22,
        highlight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
