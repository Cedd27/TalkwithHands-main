import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/alphabet_sign.dart';
import '../services/alphabet_service.dart';
import '../services/background_music_service.dart';
import '../services/progress_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../utils/video_url_utils.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);
const kCardBlue = Color(0xFF2563EB); // card footer blue (matches mockup)

class AlphabetsScreen extends StatefulWidget {
  final String userName;

  const AlphabetsScreen({
    super.key,
    required this.userName,
  });

  @override
  State<AlphabetsScreen> createState() => _AlphabetsScreenState();
}

class _AlphabetsScreenState extends State<AlphabetsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  List<AlphabetSign> _allSigns = [];
  bool _isLoading = true;
  String? _loadError;
  String _query = '';

  Future<void> _recordLearned(AlphabetSign sign) async {
    try {
      await ProgressService().recordActivity(
        category: 'alphabet',
        itemKey: sign.letter,
      );
    } catch (_) {
      // Progress sync should never block opening the lesson.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSigns();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _loadSigns() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final signs = await AlphabetService().listAlphabetSigns();
      setState(() {
        _allSigns = signs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => _loadSigns();

  List<AlphabetSign> get _filteredSigns {
    final query = _normalizeSearch(_query);
    if (query.isEmpty) return _allSigns;

    return _allSigns.where((s) {
      final letter = _normalizeSearch(s.letter);
      final title = _normalizeSearch(s.title);

      if (query.length == 1) {
        return letter == query || title == query;
      }

      return letter.startsWith(query) ||
          title == query ||
          title.endsWith(' $query');
    }).toList();
  }

  String _normalizeSearch(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _openTutorial(AlphabetSign sign) {
    if (!hasPlayableVideoSource(
      videoAsset: sign.videoAsset,
      videoUrl: sign.videoUrl,
      frontVideoUrl: sign.frontVideoUrl,
      leftVideoUrl: sign.leftVideoUrl,
      rightVideoUrl: sign.rightVideoUrl,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No tutorial video has been uploaded for this lesson yet.'),
        ),
      );
      return;
    }

    _recordLearned(sign);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialVideoScreen(
          title: sign.letter,
          imageAsset: sign.imageAsset,
          imageUrl: sign.imageUrl,
          videoAsset: sign.videoAsset,
          videoUrl: sign.videoUrl,
          frontVideoUrl: sign.frontVideoUrl,
          leftVideoUrl: sign.leftVideoUrl,
          rightVideoUrl: sign.rightVideoUrl,
          activityCategory: 'alphabet',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Alphabets',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/NEW BACKGROUND/new alphabet.png',
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
                    // ── Top bar ──────────────────────────────────────────────────
                    AppTopBar(
                      onBack: () => Navigator.of(context).pop(),
                      onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),

                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        'ALPHABETS',
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

                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Column(
                            children: [
                              // ── Search + Practice row ──────────────────────────
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _SearchField(
                                        controller: _searchController,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _PracticeButton(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SignDetectorScreen(
                                            initialMode: DetectionMode.az,
                                            lockMode: true,
                                            captureKind: CaptureKind.image,
                                            title: 'Alphabet Practice',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // ── Character illustration banner ──────────────────
                              const SizedBox(
                                height: 150,
                                width: double.infinity,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    TransparentSignVideoOverlay(
                                      videoAsset: 'assets/Alpha.mp4',
                                      fit: BoxFit.contain,
                                      volume: 0,
                                      threshold: 0.34,
                                      smoothing: 0.08,
                                    ),
                                    Positioned(
                                      left: 24,
                                      top: 8,
                                      child: _AlphabetBadge(
                                          letter: 'A',
                                          color: Color(0xFF8B3FBE)),
                                    ),
                                    Positioned(
                                      left: 62,
                                      bottom: 8,
                                      child: _AlphabetBadge(
                                          letter: 'B',
                                          color: Color(0xFFE0317A)),
                                    ),
                                    Positioned(
                                      right: 62,
                                      top: 8,
                                      child: _AlphabetBadge(
                                          letter: 'C',
                                          color: Color(0xFFF0B000)),
                                    ),
                                    Positioned(
                                      right: 18,
                                      bottom: 8,
                                      child: _AlphabetBadge(
                                          letter: 'D',
                                          color: Color(0xFF2196F3)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // ── Grid container (rounded card panel) ────────────
                              Expanded(
                                child: Container(
                                  margin:
                                      const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 4, 51, 98)
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                              255, 156, 156, 156)
                                          .withValues(alpha: 0.55),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color.fromARGB(
                                                255, 186, 182, 182)
                                            .withValues(alpha: 0.08),
                                        blurRadius: 18,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: _buildGrid(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_loadError != null) {
      return _ErrorState(
        message: 'Cannot load alphabets. Make sure the backend is running.',
        onRetry: _reload,
      );
    }
    final signs = _filteredSigns;
    if (signs.isEmpty && _query.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No results for "$_query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (signs.isEmpty) {
      return _ErrorState(
        message: 'No alphabet signs found.',
        onRetry: _reload,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: signs.length,
        itemBuilder: (context, i) => _AlphabetCard(
          sign: signs[i],
          onView: () => _showAlphabetDetails(context, signs[i]),
        ),
      ),
    );
  }

  void _showAlphabetDetails(BuildContext context, AlphabetSign sign) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 38),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color.fromARGB(255, 216, 215, 221),
                      width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: Text(
                        sign.letter,
                        style: const TextStyle(
                          color: Color(0xFF071A3F),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: _AlphabetImage(sign: sign, fit: BoxFit.contain),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      color: const Color.fromARGB(255, 4, 51, 98),
                      child: Center(
                        child: _TutorialButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            _openTutorial(sign);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Material(
                  color: const Color(0xFFFF2F2F),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlphabetBadge extends StatelessWidget {
  final String letter;
  final Color color;

  const _AlphabetBadge({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: TextStyle(
        color: color,
        fontSize: 30,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Colors.white, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
    );
  }
}

// ── Tutorial button ───────────────────────────────────────────────────────────
class _TutorialButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TutorialButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kVividBlue,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 156,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: const Color.fromARGB(255, 235, 236, 238), width: 2),
          ),
          child: const Text(
            'VIDEO TUTORIAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatefulWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black26, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child:
                Icon(Icons.search_rounded, color: Color(0xFF9DA4AD), size: 18),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Color(0xFF9DA4AD)),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: () => widget.controller.clear(),
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.close_rounded,
                    color: Color(0xFF9DA4AD), size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Practice button ───────────────────────────────────────────────────────────
class _PracticeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PracticeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kGreen,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Practice',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Alphabet card ─────────────────────────────────────────────────────────────
class _AlphabetCard extends StatelessWidget {
  final AlphabetSign sign;
  final VoidCallback onView;

  const _AlphabetCard({required this.sign, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 156, 38, 38),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // image area — tappable
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF5F8FF),
                padding: const EdgeInsets.all(6),
                child: _AlphabetImage(sign: sign, fit: BoxFit.contain),
              ),
            ),
          ),
          // footer
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 20, 74, 190),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sign.letter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: onView,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded,
                            color: Colors.white, size: 9),
                        SizedBox(width: 3),
                        Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Alphabet image ────────────────────────────────────────────────────────────
class _AlphabetImage extends StatelessWidget {
  final AlphabetSign sign;
  final BoxFit fit;

  const _AlphabetImage({required this.sign, required this.fit});

  @override
  Widget build(BuildContext context) {
    if (sign.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getOptimizedUrl(sign.imageUrl, width: 400),
        fit: fit,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _ImageFallback(letter: sign.letter),
      );
    }
    return Image.asset(
      sign.imageAsset,
      fit: fit,
      errorBuilder: (_, __, ___) => _ImageFallback(letter: sign.letter),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final String letter;
  const _ImageFallback({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _RetryButton(onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kVividBlue,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black, width: 1.4),
          ),
          child: const Text(
            'Retry',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Decorative floating bubbles for the background ──────────────────────────
// Purely visual, non-interactive layer — sits behind all existing screen
// content and does not change any other part of the design.
const List<Color> _bubbleColors = [
  kVividBlue,
  kAccent,
  kGreen,
  Color(0xFF0B8FFF),
  Color(0xFF9C27B0),
];

class _BubbleSpec {
  final double dx; // horizontal anchor, 0..1 fraction of width
  final double size;
  final double speed; // relative rise speed
  final double phase; // 0..1 start offset so bubbles don't move in sync
  final double wobble; // horizontal sway amount in logical pixels
  final Color color;
  final bool outline; // some bubbles are soft rings instead of filled dots

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

    // Fixed seed so the layout is stable across rebuilds/hot reloads
    // instead of jumping to a new random arrangement every time.
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
      // t travels 0 -> 1 -> 0 (loops) at each bubble's own speed/offset.
      final t = (progress * b.speed + b.phase) % 1.0;
      final y = size.height * (1 - t);
      final wobbleX = math.sin((t * 2 * math.pi) + b.phase * 10) * b.wobble;
      final x = size.width * b.dx + wobbleX;
      final radius = b.size / 2;

      // Fades in near the bottom, fades out near the top so bubbles never
      // pop in/out abruptly.
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

      // Tiny glossy highlight so bubbles read as bubbles, not flat dots.
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
