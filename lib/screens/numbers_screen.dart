import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/number_sign.dart';
import '../services/number_service.dart';
import '../services/background_music_service.dart';
import '../services/progress_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../utils/video_url_utils.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);
const kCardBlue = Color(0xFF2563EB);

class NumbersScreen extends StatefulWidget {
  final String userName;

  const NumbersScreen({
    super.key,
    required this.userName,
  });

  @override
  State<NumbersScreen> createState() => _NumbersScreenState();
}

class _NumbersScreenState extends State<NumbersScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  late Future<List<NumberSign>> _numberFuture;
  String _query = '';

  Future<void> _recordLearned(NumberSign sign) async {
    try {
      await ProgressService().recordActivity(
        category: 'number',
        itemKey: sign.number.toString(),
      );
    } catch (_) {
      // Progress sync should never block opening the lesson.
    }
  }

  @override
  void initState() {
    super.initState();
    _numberFuture = NumberService().listNumberSigns();
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _numberFuture = NumberService().listNumberSigns();
      });

  List<NumberSign> _filter(List<NumberSign> signs) {
    if (_query.isEmpty) return signs;
    return signs
        .where((s) =>
            s.title.toLowerCase().contains(_query) ||
            s.number.toString().contains(_query) ||
            s.description.toLowerCase().contains(_query))
        .toList();
  }

  void _openTutorial(NumberSign sign) {
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
          title: sign.title,
          imageAsset: sign.imageAsset,
          imageUrl: sign.imageUrl,
          videoAsset: sign.videoAsset,
          videoUrl: sign.videoUrl,
          frontVideoUrl: sign.frontVideoUrl,
          leftVideoUrl: sign.leftVideoUrl,
          rightVideoUrl: sign.rightVideoUrl,
          activityCategory: 'number',
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
        activeScreen: 'Numbers',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/NEW BACKGROUND/new number.png',
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
                    AppTopBar(
                      onBack: () => Navigator.of(context).pop(),
                      onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        'NUMBERS',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                              child:
                                  _SearchField(controller: _searchController)),
                          const SizedBox(width: 12),
                          _PracticeButton(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignDetectorScreen(
                                  initialMode: DetectionMode.num,
                                  lockMode: true,
                                  captureKind: CaptureKind.image,
                                  title: 'Number Practice',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(
                      height: 170,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 10,
                            top: 8,
                            child: _StickerNumber(
                              number: '1',
                              color: Color.fromARGB(185, 139, 63, 190),
                              angle: -0.18,
                              size: 38,
                            ),
                          ),
                          Positioned(
                            left: 52,
                            bottom: 12,
                            child: _StickerNumber(
                              number: '2',
                              color: Color.fromARGB(190, 224, 49, 122),
                              angle: 0.12,
                              size: 32,
                            ),
                          ),
                          Positioned(
                            right: 52,
                            top: 10,
                            child: _StickerNumber(
                              number: '3',
                              color: Color.fromARGB(192, 33, 149, 243),
                              angle: 0.15,
                              size: 30,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 14,
                            child: _StickerNumber(
                              number: '4',
                              color: Color.fromARGB(201, 67, 160, 72),
                              angle: -0.10,
                              size: 34,
                            ),
                          ),
                          Positioned(
                            left: 38,
                            top: 6,
                            child: _FloatingEmoji(emoji: '✨', size: 16),
                          ),
                          Positioned(
                            right: 38,
                            bottom: 8,
                            child: _FloatingEmoji(emoji: '💫', size: 14),
                          ),
                          _AvatarWithBubble(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 5, 111, 209)
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
                          child: FutureBuilder<List<NumberSign>>(
                            future: _numberFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                );
                              }
                              if (snapshot.hasError) {
                                return _ErrorState(
                                  message:
                                      'Cannot load numbers. Make sure the backend is running.',
                                  onRetry: _reload,
                                );
                              }
                              final signs = _filter(snapshot.data ?? const []);
                              if (signs.isEmpty) {
                                return _ErrorState(
                                  message: 'No number signs found.',
                                  onRetry: _reload,
                                );
                              }
                              return RefreshIndicator(
                                onRefresh: () async => _reload(),
                                child: GridView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(10),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 0.78,
                                  ),
                                  itemCount: signs.length,
                                  itemBuilder: (context, i) => _NumberCard(
                                    sign: signs[i],
                                    onView: () =>
                                        _showNumberDetails(context, signs[i]),
                                  ),
                                ),
                              );
                            },
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

  void _showNumberDetails(BuildContext context, NumberSign sign) {
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
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: Text(
                        sign.title,
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
                      child: _NumberImage(sign: sign, fit: BoxFit.contain),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      color: const Color(0xFF11B7CB),
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
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
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

// ── Floating emoji ────────────────────────────────────────────────────────────
class _FloatingEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  const _FloatingEmoji({required this.emoji, required this.size});
  @override
  Widget build(BuildContext context) =>
      Text(emoji, style: TextStyle(fontSize: size));
}

// ── Avatar with animated speech bubble ───────────────────────────────────────
class _AvatarWithBubble extends StatefulWidget {
  const _AvatarWithBubble();

  @override
  State<_AvatarWithBubble> createState() => _AvatarWithBubbleState();
}

class _AvatarWithBubbleState extends State<_AvatarWithBubble>
    with SingleTickerProviderStateMixin {
  static const _messages = [
    "Let's count! 🔢",
    "1, 2, 3... Go! 🚀",
    "Sign along! 🤟",
    "You're doing great! ⭐",
    "Numbers are fun! 🎉",
    "Keep practicing! 💪",
  ];

  int _msgIndex = 0;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _scheduleCycle();
  }

  void _scheduleCycle() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      // fade out
      _ctrl.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _msgIndex = (_msgIndex + 1) % _messages.length;
        });
        _ctrl.forward();
        _scheduleCycle();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 170,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // speech bubble
            Positioned(
              top: 0,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
                child: CustomPaint(
                  painter: _BubblePainter(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      _messages[_msgIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3A6B),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // avatar
            const Positioned(
              bottom: 0,
              child: SizedBox(
                height: 150,
                width: 240,
                child: TransparentSignVideoOverlay(
                  videoAsset: 'assets/Num.mp4',
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
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFBFD7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      const Radius.circular(14),
    );

    // tail pointing down
    final tail = Path()
      ..moveTo(size.width / 2 - 8, size.height - 10)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + 8, size.height - 10)
      ..close();

    canvas.drawRRect(rr, paint);
    canvas.drawPath(tail, paint);
    canvas.drawRRect(rr, borderPaint);
    canvas.drawPath(tail, borderPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Sticker number ────────────────────────────────────────────────────────────
class _StickerNumber extends StatelessWidget {
  final String number;
  final Color color;
  final double angle;
  final double size;
  const _StickerNumber({
    required this.number,
    required this.color,
    required this.angle,
    required this.size,
  });
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Text(
        number,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: [
            const Shadow(
                color: Colors.white, offset: Offset(2, 2), blurRadius: 4),
            Shadow(
                color: color.withValues(alpha: 0.4),
                offset: const Offset(3, 3),
                blurRadius: 6),
          ],
        ),
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
      color: const Color.fromARGB(255, 7, 47, 179),
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
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});
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
              controller: controller,
              keyboardType: TextInputType.number,
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
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ── Number card ───────────────────────────────────────────────────────────────
class _NumberCard extends StatelessWidget {
  final NumberSign sign;
  final VoidCallback onView;
  const _NumberCard({required this.sign, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.19),
            blurRadius: 6,
            offset: const Offset(4, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── image area with light grey border — tappable ──
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF9F9),
                  border: Border.all(
                    color: const Color(0xFFD6D6D6),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: _NumberImage(sign: sign, fit: BoxFit.contain),
              ),
            ),
          ),
          // ── footer ──
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 0, 60, 191),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sign.title,
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

// ── Number image ──────────────────────────────────────────────────────────────
class _NumberImage extends StatelessWidget {
  final NumberSign sign;
  final BoxFit fit;
  const _NumberImage({required this.sign, required this.fit});
  @override
  Widget build(BuildContext context) {
    if (sign.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getOptimizedUrl(sign.imageUrl, width: 400),
        fit: fit,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _ImageFallback(label: sign.title),
      );
    }
    return Image.asset(
      sign.imageAsset,
      fit: fit,
      errorBuilder: (_, __, ___) => _ImageFallback(label: sign.title),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final String label;
  const _ImageFallback({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.black, fontSize: 34, fontWeight: FontWeight.w900),
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
                  fontWeight: FontWeight.w700),
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
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
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
