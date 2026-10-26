import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';

void main() {
  runApp(const GuessASLApp());
}

class GuessASLApp extends StatelessWidget {
  const GuessASLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GUESS ASLLLLL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A3FFF)),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

const kElectricBlue = Color(0xFF1A6BFF);
const kDeepNavy = Color(0xFF2C1810);
const kAccentCyan = Color(0xFF00E5FF);
const kAccentGold = Color(0xFFFFD93D);
const kRed = Color(0xFFFF4E4E);
const kGreen = Color(0xFF22C55E);
const kGlassBorder = Color(0x66FFFFFF);
const kWarmBrown = Color(0xFF8B4513);
const kParchment = Color(0xFFF5E6C8);
const kBannerRed = Color(0xFFB22222);
const kWoodDark = Color(0xFF5C3317);

// Game logo used in the header and the start modal badge.
const List<String> kGameIconCandidates = [
  'assets/images/guess_asl_icon.png',
];

const List<Map<String, String>> kCombinedPool = [
  {'label': 'A', 'type': 'ALPHABET'},
  {'label': 'B', 'type': 'ALPHABET'},
  {'label': 'C', 'type': 'ALPHABET'},
  {'label': 'D', 'type': 'ALPHABET'},
  {'label': 'E', 'type': 'ALPHABET'},
  {'label': 'F', 'type': 'ALPHABET'},
  {'label': 'G', 'type': 'ALPHABET'},
  {'label': 'H', 'type': 'ALPHABET'},
  {'label': 'I', 'type': 'ALPHABET'},
  {'label': 'J', 'type': 'ALPHABET'},
  {'label': 'K', 'type': 'ALPHABET'},
  {'label': 'L', 'type': 'ALPHABET'},
  {'label': 'M', 'type': 'ALPHABET'},
  {'label': 'N', 'type': 'ALPHABET'},
  {'label': 'O', 'type': 'ALPHABET'},
  {'label': 'P', 'type': 'ALPHABET'},
  {'label': 'Q', 'type': 'ALPHABET'},
  {'label': 'R', 'type': 'ALPHABET'},
  {'label': 'S', 'type': 'ALPHABET'},
  {'label': 'T', 'type': 'ALPHABET'},
  {'label': 'U', 'type': 'ALPHABET'},
  {'label': 'V', 'type': 'ALPHABET'},
  {'label': 'W', 'type': 'ALPHABET'},
  {'label': 'X', 'type': 'ALPHABET'},
  {'label': 'Y', 'type': 'ALPHABET'},
  {'label': 'Z', 'type': 'ALPHABET'},
  {'label': '0', 'type': 'NUMBER'},
  {'label': '1', 'type': 'NUMBER'},
  {'label': '2', 'type': 'NUMBER'},
  {'label': '3', 'type': 'NUMBER'},
  {'label': '4', 'type': 'NUMBER'},
  {'label': '5', 'type': 'NUMBER'},
  {'label': '6', 'type': 'NUMBER'},
  {'label': '7', 'type': 'NUMBER'},
  {'label': '8', 'type': 'NUMBER'},
  {'label': '9', 'type': 'NUMBER'},
  {'label': '10', 'type': 'NUMBER'},
  {'label': '11', 'type': 'NUMBER'},
  {'label': '12', 'type': 'NUMBER'},
  {'label': '13', 'type': 'NUMBER'},
  {'label': '14', 'type': 'NUMBER'},
  {'label': '15', 'type': 'NUMBER'},
  {'label': '16', 'type': 'NUMBER'},
  {'label': '17', 'type': 'NUMBER'},
  {'label': '18', 'type': 'NUMBER'},
  {'label': '19', 'type': 'NUMBER'},
  {'label': '20', 'type': 'NUMBER'},
];

class ScoreBoard {
  static int todayBest = 0;
  static int weekBest = 0;
  static int allTimeBest = 0;

  static void submit(int score) {
    if (score > todayBest) todayBest = score;
    if (score > weekBest) weekBest = score;
    if (score > allTimeBest) allTimeBest = score;
  }
}

// Tries each candidate asset path in turn and falls back to [fallback] if
// none of them exist. This means we don't need to guess your exact filename —
// as long as one of these common names matches what's in your assets folder
// it will render. (You still need the folder declared under `flutter: assets:`
// in pubspec.yaml, and a full restart — not hot reload — after adding assets.)
class _AssetFallbackImage extends StatelessWidget {
  final List<String> candidates;
  final BoxFit fit;
  final Widget Function() fallback;
  // Where to anchor the crop when the source image doesn't match the target
  // box's aspect ratio. Defaults to center (Flutter's default), but for
  // sprite frames that contain more than one character side-by-side, pick
  // an alignment that keeps the *same* character in frame on every call —
  // otherwise BoxFit.cover center-crops each frame slightly differently
  // (frames can have tiny size differences) and it reads as the avatar
  // "sliding" to reveal whoever is standing next to it.
  const _AssetFallbackImage({
    required this.candidates,
    required this.fit,
    required this.fallback,
  });

  Widget _tryFrom(int index) {
    if (index >= candidates.length) return fallback();
    return Image.asset(
      candidates[index],
      fit: fit,
      alignment: Alignment.center,
      // Keep showing the last good frame while a new one decodes instead of
      // flashing empty for a tick — that gap is what made the swap between
      // frames look like a jump/slide rather than a clean loop.
      gaplessPlayback: true,
      errorBuilder: (ctx, err, st) => _tryFrom(index + 1),
    );
  }

  @override
  Widget build(BuildContext context) => _tryFrom(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// SPRITE MASCOT — plays real PNG frame sequences (idle/blink/talk/wave/think/
// encourage/celebrate/victory), matching the "Kalinaw" sprite sheet naming:
//   idle_01.png..idle_04.png     (loop, resting state)
//   blink_01.png..blink_03.png   (plays once at random intervals, over idle)
//   talk_01.png..talk_04.png     (loop while the speech bubble is typing)
//   wave_01.png..wave_04.png     (plays once — hello / round start)
//   think_01.png..think_03.png   (plays once — hint used)
//   encourage_01.png..encourage_03.png (plays once — wrong answer)
//   celebrate_01.png..celebrate_04.png (loop — win screen)
//   victory_01.png..victory_03.png     (plays once — correct answer)
//
// Drop your exported frames into one of the folders in
// `_mascotFrameCandidates` below (declared under `flutter: assets:` in
// pubspec.yaml, full restart after adding). Until real art is in place, each
// frame silently falls back to the hand-drawn `_FacePainter` face so the
// mascot still blinks/talks correctly with placeholder art.
// ─────────────────────────────────────────────────────────────────────────────
enum MascotState { idle, blink, talk, wave, think, encourage, celebrate, victory }

class _MascotFrameSpec {
  final int frameCount;
  final Duration frameDuration;
  const _MascotFrameSpec({required this.frameCount, required this.frameDuration});
}

const Map<MascotState, _MascotFrameSpec> _kMascotSpecs = {
  MascotState.idle: _MascotFrameSpec(frameCount: 4, frameDuration: Duration(milliseconds: 420)),
  MascotState.blink: _MascotFrameSpec(frameCount: 3, frameDuration: Duration(milliseconds: 70)),
  MascotState.talk: _MascotFrameSpec(frameCount: 4, frameDuration: Duration(milliseconds: 140)),
  MascotState.wave: _MascotFrameSpec(frameCount: 4, frameDuration: Duration(milliseconds: 150)),
  MascotState.think: _MascotFrameSpec(frameCount: 3, frameDuration: Duration(milliseconds: 380)),
  MascotState.encourage: _MascotFrameSpec(frameCount: 3, frameDuration: Duration(milliseconds: 220)),
  MascotState.celebrate: _MascotFrameSpec(frameCount: 4, frameDuration: Duration(milliseconds: 180)),
  MascotState.victory: _MascotFrameSpec(frameCount: 3, frameDuration: Duration(milliseconds: 220)),
};

// Candidate asset folders — first match wins per frame, same fallback trick
// as the background/mascot images above, so the exact folder name doesn't
// need to be guessed correctly.
List<String> _mascotFrameCandidates(MascotState state, int frameNumber1Based) {
  final file = '${state.name}_${frameNumber1Based.toString().padLeft(2, '0')}.png';
  return [
    'assets/kalinaw/$file',
    'assets/guess_asl/kalinaw/$file',
    'assets/guess_asl/mascot/$file',
    'assets/mascot/$file',
  ];
}

// Small controller the game screen uses to tell the mascot what to do —
// e.g. `mascotCtrl.setTalking(true)` while the bubble types, or
// `mascotCtrl.playOnce(MascotState.victory)` on a correct answer.
class MascotController extends ChangeNotifier {
  bool isTalking = false;
  bool isCelebrating = false;
  MascotState? _pendingOneOff;

  void setTalking(bool value) {
    if (isTalking == value) return;
    isTalking = value;
    notifyListeners();
  }

  void setCelebrating(bool value) {
    if (isCelebrating == value) return;
    isCelebrating = value;
    notifyListeners();
  }

  void playOnce(MascotState state) {
    _pendingOneOff = state;
    notifyListeners();
  }

  MascotState? _consumeOneOff() {
    final s = _pendingOneOff;
    _pendingOneOff = null;
    return s;
  }
}

class _SpriteMascot extends StatefulWidget {
  final MascotController controller;
  const _SpriteMascot({required this.controller});

  @override
  State<_SpriteMascot> createState() => _SpriteMascotState();
}

class _SpriteMascotState extends State<_SpriteMascot> {
  Timer? _frameTimer;
  Timer? _blinkTimer;
  MascotState _current = MascotState.idle;
  int _frame = 0;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _playLoop(MascotState.idle);
    _scheduleNextBlink();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _frameTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _onControllerChange() {
    final oneOff = widget.controller._consumeOneOff();
    if (oneOff != null) {
      _playOnce(oneOff);
      return;
    }
    // Only react to talking/celebrating flag flips while sitting in a loop —
    // don't interrupt a blink or a one-off animation mid-way.
    if (_current == MascotState.idle ||
        _current == MascotState.talk ||
        _current == MascotState.celebrate) {
      _resumeBaseLoop();
    }
  }

  void _resumeBaseLoop() {
    if (widget.controller.isCelebrating) {
      _playLoop(MascotState.celebrate);
    } else if (widget.controller.isTalking) {
      _playLoop(MascotState.talk);
    } else {
      _playLoop(MascotState.idle);
    }
  }

  void _setFrame(MascotState state, int frame) {
    if (!mounted) return;
    setState(() {
      _current = state;
      _frame = frame;
    });
  }

  void _playLoop(MascotState state) {
    _frameTimer?.cancel();
    final spec = _kMascotSpecs[state]!;
    int i = 0;
    _setFrame(state, i);
    _frameTimer = Timer.periodic(spec.frameDuration, (_) {
      i = (i + 1) % spec.frameCount;
      _setFrame(state, i);
    });
  }

  void _playOnce(MascotState state) {
    _frameTimer?.cancel();
    final spec = _kMascotSpecs[state]!;
    int i = 0;
    _setFrame(state, i);
    _frameTimer = Timer.periodic(spec.frameDuration, (t) {
      i++;
      if (i >= spec.frameCount) {
        t.cancel();
        _resumeBaseLoop();
        return;
      }
      _setFrame(state, i);
    });
  }

  // Blinks at a random interval (roughly every 2.4–5s), but only while idle —
  // never interrupts talking, waving, or any other one-off animation.
  void _scheduleNextBlink() {
    final delay = Duration(milliseconds: 2400 + _rng.nextInt(2600));
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      if (_current == MascotState.idle) {
        _playBlinkThenResume();
      } else {
        _scheduleNextBlink();
      }
    });
  }

  void _playBlinkThenResume() {
    _frameTimer?.cancel();
    final spec = _kMascotSpecs[MascotState.blink]!;
    int i = 0;
    _setFrame(MascotState.blink, i);
    _frameTimer = Timer.periodic(spec.frameDuration, (t) {
      i++;
      if (i >= spec.frameCount) {
        t.cancel();
        _resumeBaseLoop();
        _scheduleNextBlink();
        return;
      }
      _setFrame(MascotState.blink, i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _mascotFrameCandidates(_current, _frame + 1);
    // AspectRatio(1) forces every frame to be laid out against the exact
    // same square box before BoxFit.cover ever runs. Without a hard-locked
    // box, differences in each exported frame's own pixel dimensions
    // (idle_01.png vs idle_02.png vs idle_03.png...) each get their own
    // "cover" calculation, and the resulting crop can land a little
    // differently side to side per frame — which is what reads as the
    // mascot "sliding right" to reveal whoever/whatever is next to it in
    // the source art.
    return AspectRatio(
      aspectRatio: 1,
      child: FittedBox(
        // contain: always shows the FULL image, no cropping on any side.
        // cover was cutting into the character because it crops toward the
        // center by default — with contain there is nothing to guess about
        // where the character sits in the canvas, since nothing gets cut.
        // With your real 1700x1990 canvas (nearly square), the only
        // trade-off is a few px of empty gap on the sides — not a crop.
        fit: BoxFit.contain,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          // Exact resolution of your real exported frames.
          width: 1700,
          height: 1990,
          child: _AssetFallbackImage(
            candidates: candidates,
            // fill stretches each frame to that exact fixed canvas — a ~3%
            // squeeze/stretch at most, invisible, but it means every frame
            // is treated as identically sized before the FittedBox above
            // ever scales it, so no per-frame zoom variance survives.
            fit: BoxFit.fill,
            fallback: () => CustomPaint(
              painter: _FacePainter(
                blink: _current == MascotState.blink ? 1.0 : 0.0,
                talk: _current == MascotState.talk
                    ? (0.4 + 0.6 * (_frame / 3))
                    : (_current == MascotState.victory ||
                            _current == MascotState.celebrate
                        ? 0.7
                        : 0.0),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final double blink; // 0 = eyes fully open, 1 = eyes fully closed
  final double talk; // 0 = mouth closed/smiling, 1 = mouth wide open

  const _FacePainter({required this.blink, required this.talk});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Skin base fill
    final skinPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD9B3), Color(0xFFFFC08A)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skinPaint);

    // Simple rounded hair cap across the top
    final hairPaint = Paint()..color = const Color(0xFF3B2416);
    final hairPath = Path()
      ..moveTo(0, h * 0.42)
      ..quadraticBezierTo(cx, -h * 0.08, w, h * 0.42)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // Blush cheeks
    final blushPaint = Paint()..color = const Color(0x33FF6B81);
    canvas.drawCircle(
        Offset(cx - w * 0.28, cy + h * 0.10), w * 0.09, blushPaint);
    canvas.drawCircle(
        Offset(cx + w * 0.28, cy + h * 0.10), w * 0.09, blushPaint);

    // Eyes — height animates down to a sliver on blink
    final eyeOpenH = h * 0.13;
    final eyeH = (eyeOpenH * (1 - blink)).clamp(1.4, eyeOpenH);
    final eyeW = w * 0.11;
    final eyeY = cy - h * 0.04;
    final eyeDX = w * 0.17;

    final eyeWhitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF2C1810);
    final lidPaint = Paint()
      ..color = const Color(0xFF7A4B2B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final dx in [-eyeDX, eyeDX]) {
      final center = Offset(cx + dx, eyeY);
      final rect = Rect.fromCenter(center: center, width: eyeW, height: eyeH);
      canvas.drawOval(rect, eyeWhitePaint);
      if (blink < 0.6) {
        final pupilH = (eyeH * 0.55).clamp(1.0, eyeH);
        canvas.drawOval(
          Rect.fromCenter(center: center, width: eyeW * 0.45, height: pupilH),
          pupilPaint,
        );
      }
      canvas.drawLine(
        Offset(center.dx - eyeW / 2, center.dy),
        Offset(center.dx + eyeW / 2, center.dy),
        lidPaint,
      );
    }

    // Eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF3B2416)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final dx in [-eyeDX, eyeDX]) {
      final by = eyeY - eyeOpenH * 0.9;
      canvas.drawLine(
        Offset(cx + dx - eyeW * 0.55, by + 2),
        Offset(cx + dx + eyeW * 0.55, by - 2),
        browPaint,
      );
    }

    // Mouth — a gentle smile at rest, opens into a rounded talking shape
    final mouthY = cy + h * 0.24;
    final mouthW = w * 0.30;
    if (talk < 0.08) {
      final smilePaint = Paint()
        ..color = const Color(0xFF7A3B2E)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(cx - mouthW / 2, mouthY)
        ..quadraticBezierTo(cx, mouthY + h * 0.09, cx + mouthW / 2, mouthY);
      canvas.drawPath(path, smilePaint);
    } else {
      final mouthH = h * 0.05 + h * 0.14 * talk;
      final mouthPaint = Paint()..color = const Color(0xFF7A2E22);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, mouthY), width: mouthW, height: mouthH),
        Radius.circular(mouthH / 2),
      );
      canvas.drawRRect(rrect, mouthPaint);
      if (talk > 0.55) {
        final tonguePaint = Paint()..color = const Color(0xFFD9707A);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, mouthY + mouthH * 0.18),
            width: mouthW * 0.5,
            height: mouthH * 0.5,
          ),
          tonguePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.blink != blink || oldDelegate.talk != talk;
}

// Background asset path — points at the prototype's nipa-hut classroom art.
// NOTE: confirm the exact filename in C:\Projects\TalkwithHands\assets\guess_asl
// and add/reorder candidates below if it differs from these common guesses.
const List<String> kBackgroundCandidates = [
  'assets/guess_asl/guess_asl-bg.png',
  'assets/guess_asl/background.png',
  'assets/guess_asl/background.jpg',
  'assets/guess_asl/bg.png',
  'assets/guess_asl/bg.jpg',
  'assets/guess_asl/classroom_bg.png',
  'assets/guess_asl/classroom.png',
];

const List<String> kMascotCandidates = [
  'assets/guess_asl/mascot.png',
  'assets/guess_asl/avatar.png',
  'assets/guess_asl/character.png',
  'assets/guess_asl/girl.png',
];

class ArcadeBackground extends StatelessWidget {
  final Widget child;
  const ArcadeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Prototype background image (nipa hut / ASL classroom art)
        _AssetFallbackImage(
          candidates: kBackgroundCandidates,
          fit: BoxFit.cover,
          fallback: () => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B1330),
                  Color(0xFF11224A),
                  Color(0xFF1A1030),
                ],
              ),
            ),
          ),
        ),
        // Soft ambient glow blobs for a modern arcade backdrop
        const Positioned(
          top: -80,
          left: -60,
          child: _GlowBlob(color: kElectricBlue, size: 260),
        ),
        const Positioned(
          bottom: -100,
          right: -70,
          child: _GlowBlob(color: Color(0xFF7C3AED), size: 280),
        ),
        child,
      ],
    );
  }
}

// Soft blurred glow circle used to add ambient color depth to the modern
// dark background, similar to the glow accents popular in current mobile
// game UIs (Duolingo, Kahoot, Clash Royale menus, etc).
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                spreadRadius: 1,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TITLE BANNER — modern glass header
// ─────────────────────────────────────────────────────────────────────────────
// Modern glass header bar — replaces the old parchment scroll + red
// ribbon with a sleek frosted pill, gradient logo text, and a small
// glowing badge icon, in line with current mobile-game header design.
class _TitleBanner extends StatelessWidget {
  final VoidCallback? onBack;
  const _TitleBanner({this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 64,
                margin: EdgeInsets.only(left: onBack != null ? 56 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: kAccentCyan.withValues(alpha: 0.3), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withValues(alpha: 0.15),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Small gradient badge icon
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [kElectricBlue, kAccentCyan],
                        ),
                      ),
                      child: ClipOval(
                        child: _AssetFallbackImage(
                          candidates: kGameIconCandidates,
                          fit: BoxFit.cover,
                          fallback: () => const Center(
                            child: Icon(
                              Icons.sports_esports_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Solid white (no fading gradient) so every letter
                            // stays fully readable; cyan glow keeps the neon look.
                            Text(
                              'GUESS ASL',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                height: 1.15,
                                shadows: [
                                  Shadow(
                                    color: kAccentCyan.withValues(alpha: 0.7),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'CHALLENGE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: kAccentGold,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Back button overlapping the header's left edge
          if (onBack != null)
            Positioned(
              left: 0,
              child: AppBackIconButton(onTap: onBack!, size: 44),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final void Function({
    required bool won,
    required int score,
    required int completed,
    required int total,
  })? onGameFinished;

  const GameScreen({super.key, this.onExit, this.onGameFinished});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int kMaxLives = 3;
  static const int kStartTime = 25;
  static const int kNumChoices = 5;
  static const int kMaxHints = 3;

  int _lives = kMaxLives;
  int _score = 0;
  int _timeLeft = kStartTime;
  bool _gameOver = false;
  bool _gameWon = false;
  int _hintsLeft = kMaxHints;
  bool _showStartPrompt = true;

  // Combined pool queue
  late List<Map<String, String>> _remainingItems;
  int _completedCount = 0;

  late String _roundLetter;
  late String _roundType; // 'ALPHABET' or 'NUMBER'
  late List<String> _choices;
  String? _selectedChoice;
  final Set<String> _eliminated = {};

  Timer? _timer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _popCtrl;
  late Animation<double> _popScale;
  late AnimationController _winPopCtrl;
  late Animation<double> _winPopScale;
  late AnimationController _imageRevealCtrl;
  late AnimationController _hintPulseCtrl;
  late AnimationController _startPromptCtrl;
  late Animation<double> _startPromptScale;

  // Typing animation state
  String _displayedBubbleText = '';
  String _fullBubbleText = '';
  Timer? _typingTimer;
  int _typingIndex = 0;

  // Talking (mouth bounce) animation
  late AnimationController _talkCtrl;
  late Animation<double> _talkAnim;

  // Drives the sprite mascot's idle/blink/talk/wave/think/encourage/
  // celebrate/victory states.
  final MascotController _mascotCtrl = MascotController();

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);

    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _popScale = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);

    _winPopCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _winPopScale =
        CurvedAnimation(parent: _winPopCtrl, curve: Curves.elasticOut);

    _imageRevealCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _hintPulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        lowerBound: 0.92,
        upperBound: 1.0)
      ..repeat(reverse: true);

    _startPromptCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _startPromptScale = CurvedAnimation(
      parent: _startPromptCtrl,
      curve: Curves.easeOutBack,
    );

    _talkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _talkAnim = CurvedAnimation(parent: _talkCtrl, curve: Curves.easeInOut);

    _initQueue();
    _setupRound();
    _startPromptCtrl.forward();
    _mascotCtrl.playOnce(MascotState.wave);
    // Kick off typing after first frame so `mounted` is true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startTyping();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typingTimer?.cancel();
    _shakeCtrl.dispose();
    _popCtrl.dispose();
    _winPopCtrl.dispose();
    _imageRevealCtrl.dispose();
    _hintPulseCtrl.dispose();
    _startPromptCtrl.dispose();
    _talkCtrl.dispose();
    _mascotCtrl.dispose();
    super.dispose();
  }

  // ── QUEUE ────────────────────────────────────────────────────────────────────
  void _initQueue() {
    _remainingItems = List<Map<String, String>>.from(kCombinedPool)
      ..shuffle(Random());
    _completedCount = 0;
  }

  // ── ROUND SETUP ─────────────────────────────────────────────────────────────
  void _setupRound() {
    final current = _remainingItems.first;
    _roundLetter = current['label']!;
    _roundType = current['type']!;
    _choices = _generateChoices(_roundLetter);
    _selectedChoice = null;
    _eliminated.clear();
    _imageRevealCtrl.forward(from: 0);
    // Only call _startTyping if widget is already mounted (not during initState)
    if (mounted) _startTyping();
  }

  void _startTyping([String? overrideText]) {
    _typingTimer?.cancel();
    if (overrideText != null) {
      _fullBubbleText = overrideText;
    } else {
      final typeWord = _roundType == 'ALPHABET' ? 'Alphabet' : 'Number';
      _fullBubbleText = 'Which $typeWord\nsign is this?';
    }
    _typingIndex = 0;
    setState(() => _displayedBubbleText = '');

    // Start talking animation loop
    _talkCtrl.repeat(reverse: true);
    _mascotCtrl.setTalking(true);

    _typingTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_typingIndex < _fullBubbleText.length) {
        setState(() {
          _displayedBubbleText = _fullBubbleText.substring(0, _typingIndex + 1);
          _typingIndex++;
        });
      } else {
        t.cancel();
        // Stop talking once typing is done
        _talkCtrl.animateTo(0).then((_) => _talkCtrl.stop());
        _mascotCtrl.setTalking(false);
      }
    });
  }

  List<String> _generateChoices(String correct) {
    final rng = Random();
    final correctType = kCombinedPool
        .firstWhere((e) => e['label'] == correct)['type'];
    final pool = kCombinedPool
        .where((e) => e['type'] == correctType && e['label'] != correct)
        .map((e) => e['label']!)
        .toList()
      ..shuffle(rng);
    final distractors = pool.take(kNumChoices - 1).toList();
    return ([correct, ...distractors]..shuffle(rng));
  }

  // ── HINT ─────────────────────────────────────────────────────────────────────
  void _useHint() {
    if (_hintsLeft <= 0 || _selectedChoice != null || _gameOver || _gameWon) {
      return;
    }

    final wrong = _choices
        .where((c) => c != _roundLetter && !_eliminated.contains(c))
        .toList();

    if (wrong.isEmpty) return;

    wrong.shuffle(Random());
    final toRemove = wrong.take(2).toList();

    setState(() {
      _eliminated.addAll(toRemove);
      _hintsLeft--;
    });
    _mascotCtrl.playOnce(MascotState.think);
  }

  // ── TIMER ────────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_gameOver || _gameWon) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _triggerGameOver();
        }
      });
    });
  }

  // ── ANSWER ───────────────────────────────────────────────────────────────────
  void _onChoiceTap(String choice) {
    if (_selectedChoice != null || _gameOver || _gameWon) return;
    if (_eliminated.contains(choice)) return;

    final correct = choice == _roundLetter;

    setState(() {
      _selectedChoice = choice;
      if (correct) {
        _score += 10 + _timeLeft;
        _mascotCtrl.playOnce(MascotState.victory);
        _startTyping('You did\namazing!');
      } else {
        _lives--;
        _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reset());
        _mascotCtrl.playOnce(MascotState.encourage);
        _startTyping('Great try!\nLet\'s do another one!');
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      if (!correct && _lives <= 0) {
        _triggerGameOver();
        return;
      }

      if (correct) {
        // Advance the queue
        _remainingItems.removeAt(0);
        _completedCount++;

        if (_remainingItems.isEmpty) {
          // Player answered every sign — they win!
          _triggerWin();
          return;
        }
      }

      // Wrong answer but still has lives → retry same letter (don't advance queue)
      // Correct answer with letters remaining → move to next letter
      setState(() {
        _timeLeft = kStartTime;
        _setupRound();
      });
    });
  }

  void _triggerGameOver() {
    if (_gameOver || _gameWon) return;
    _timer?.cancel();
    ScoreBoard.submit(_score);
    widget.onGameFinished?.call(
      won: false,
      score: _score,
      completed: _completedCount,
      total: kCombinedPool.length,
    );
    setState(() => _gameOver = true);
    _popCtrl.forward(from: 0);
  }

  void _triggerWin() {
    if (_gameOver || _gameWon) return;
    _timer?.cancel();
    ScoreBoard.submit(_score);
    widget.onGameFinished?.call(
      won: true,
      score: _score,
      completed: _completedCount,
      total: kCombinedPool.length,
    );
    setState(() => _gameWon = true);
    _winPopCtrl.forward(from: 0);
    _mascotCtrl.setCelebrating(true);
  }

  void _restart() {
    final isWin = _gameWon;
    final ctrl = isWin ? _winPopCtrl : _popCtrl;

    ctrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _lives = kMaxLives;
        _score = 0;
        _timeLeft = kStartTime;
        _gameOver = false;
        _gameWon = false;
        _hintsLeft = kMaxHints;
        _showStartPrompt = true;
      });
      _initQueue();
      _setupRound();
      _startPromptCtrl.forward(from: 0);
      _mascotCtrl.setCelebrating(false);
      _mascotCtrl.playOnce(MascotState.wave);
    });
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 650;
    final maxW = isWide ? 480.0 : size.width;

    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.guessAsl,
        child: PopScope(
        canPop: !_showStartPrompt,
        child: ArcadeBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          _TitleBanner(onBack: widget.onExit),
                          const SizedBox(height: 12),
                          _buildStatsCard(),
                          const SizedBox(height: 14),
                          _buildMascotBubble(),
                          const SizedBox(height: 10),
                          Expanded(child: _buildImageAndHintRow()),
                          const SizedBox(height: 12),
                          _buildChoices(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_gameOver) _buildGameOverOverlay(),
                if (_gameWon) _buildWinOverlay(),
                if (_showStartPrompt) _buildStartPromptOverlay(),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  // ── STATS CARD (Score / Lives + Star / Progress) ────────────────────────────
  Widget _buildStatsCard() {
    final total = kCombinedPool.length;
    final completed = _completedCount;
    final progress = total == 0 ? 0.0 : completed / total;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Score badge — gradient pill instead of plain text
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kElectricBlue, kAccentCyan],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '$_score',
                        key: ValueKey(_score),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lives — glowing hearts, centered between score and timer
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(kMaxLives, (i) {
                      final alive = i < _lives;
                      // One persistent icon per heart (no AnimatedSwitcher, no
                      // glow Shadow) so there is never a second layer drawn on
                      // top and the heart stays crisp. Only color + a tiny
                      // scale animate when a life is lost / restored.
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: alive ? 1.0 : 0.0),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          builder: (context, t, _) => Transform.scale(
                            scale: 0.85 + 0.15 * t,
                            child: Icon(
                              alive
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: Color.lerp(
                                  Colors.white.withValues(alpha: 0.25),
                                  kRed,
                                  t),
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Timer — live countdown, shifts color as it runs low
              _buildTimerChip(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (ctx, value, _) {
                          return Stack(
                            children: [
                              Container(
                                height: 22,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              FractionallySizedBox(
                                widthFactor: value.clamp(0.0, 1.0),
                                child: Container(
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [kAccentGold, kElectricBlue],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '$completed / $total',
                        key: ValueKey(completed),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 3,
                                offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TIMER CHIP (live countdown, color shifts as time runs low) ──────────────
  Widget _buildTimerChip() {
    final urgent = _timeLeft <= 5;
    final warning = _timeLeft <= 10 && !urgent;
    final color = urgent ? kRed : (warning ? kAccentGold : kAccentCyan);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            '${_timeLeft}s',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    // Pulse the chip once time is running critically low, using the same
    // pulse controller already driving the hint button (always running).
    return urgent ? ScaleTransition(scale: _hintPulseCtrl, child: chip) : chip;
  }

  // ── MASCOT + SPEECH BUBBLE ───────────────────────────────────────────────────
  Widget _buildMascotBubble() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Talking avatar
          AnimatedBuilder(
            animation: _talkAnim,
            builder: (ctx, _) {
              final talk = _talkAnim.value;
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF11224A),
                  border: Border.all(
                    color: Color.lerp(
                      kAccentCyan,
                      const Color(0xFF7C3AED),
                      talk,
                    )!,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(
                        kAccentCyan.withValues(alpha: 0.35),
                        const Color(0xFF7C3AED).withValues(alpha: 0.6),
                        talk,
                      )!,
                      blurRadius: 10 + talk * 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _SpriteMascot(controller: _mascotCtrl),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          // Speech bubble
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: kAccentCyan.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kAccentCyan.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _displayedBubbleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                          // Blinking cursor while typing
                          if (_displayedBubbleText.length <
                              _fullBubbleText.length)
                            const _BlinkingCursor(),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tail pointing left toward avatar
                Positioned(
                  left: -7,
                  bottom: 16,
                  child: Transform.rotate(
                    angle: pi / 4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16224A).withValues(alpha: 0.85),
                        border: Border(
                          left: BorderSide(
                              color: kAccentCyan.withValues(alpha: 0.35),
                              width: 1.4),
                          bottom: BorderSide(
                              color: kAccentCyan.withValues(alpha: 0.35),
                              width: 1.4),
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
    );
  }

  // ── IMAGE CARD ───────────────────────────────────────────────────────────────
  Widget _buildImageCard() {
    return Center(
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (ctx, child) {
          final offset =
              sin(_shakeAnim.value * pi * 6) * 6 * (1 - _shakeAnim.value);
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: FadeTransition(
          opacity: _imageRevealCtrl,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kElectricBlue, kAccentCyan, Color(0xFF7C3AED)],
              ),
              boxShadow: [
                BoxShadow(
                  color: kAccentCyan.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: -8,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image area
                  AspectRatio(
                    aspectRatio: 1.1,
                    child: Container(
                      color: const Color(0xFFF4F6FB),
                      child: _buildSignImage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _assetPathsFor(String item) {
    return [
      'assets/guess_asl/$item.png',
      'assets/guess_asl/$item.jpg',
      'assets/guess_asl/$item.jpeg',
    ];
  }

  Widget _buildSignImage() {
    return _buildSignImageFromCandidates(_assetPathsFor(_roundLetter));
  }

  Widget _buildSignImageFromCandidates(List<String> candidates, [int index = 0]) {
    if (index >= candidates.length) return _placeholderSign();

    return Image.asset(
      candidates[index],
      fit: BoxFit.contain,
      key: ValueKey(candidates[index]),
      errorBuilder: (ctx, err, st) =>
          _buildSignImageFromCandidates(candidates, index + 1),
    );
  }

  Widget _placeholderSign() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kElectricBlue.withValues(alpha: 0.08),
            kDeepNavy.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: kElectricBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: kElectricBlue.withValues(alpha: 0.25), width: 2),
              ),
              child: Center(
                child: Text(
                  '✋',
                  style: TextStyle(
                    fontSize: 72,
                    shadows: [
                      Shadow(
                          color: kElectricBlue.withValues(alpha: 0.3),
                          blurRadius: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ASL SIGN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF11224A).withValues(alpha: 0.45),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kElectricBlue, Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _roundLetter,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _assetPathsFor(_roundLetter).first,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF11224A).withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── IMAGE + HINT ROW ─────────────────────────────────────────────────────────
  Widget _buildImageAndHintRow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Centered image card
        _buildImageCard(),
        // Hint button floats bottom-right of the card
        Positioned(
          bottom: 0,
          right: 0,
          child: _buildHintButton(),
        ),
      ],
    );
  }

  // ── HINT BUTTON (glowing gradient badge, modern style) ───────────────────────
  Widget _buildHintButton() {
    final canUse = _hintsLeft > 0 &&
        _selectedChoice == null &&
        !_gameOver &&
        !_gameWon &&
        _choices
            .where((c) => c != _roundLetter && !_eliminated.contains(c))
            .isNotEmpty;

    return Opacity(
      opacity: canUse ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: canUse ? _useHint : null,
        child: ScaleTransition(
          scale: canUse ? _hintPulseCtrl : const AlwaysStoppedAnimation(1.0),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canUse
                  ? const LinearGradient(
                      colors: [kAccentGold, Color(0xFFFF8C00)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1.4),
              boxShadow: canUse
                  ? [
                      BoxShadow(
                        color: kAccentGold.withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '💡',
                  style: TextStyle(
                    fontSize: 18,
                    color: canUse ? Colors.white : Colors.white38,
                  ),
                ),
                if (_hintsLeft < kMaxHints)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11224A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '$_hintsLeft',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CHOICES ──────────────────────────────────────────────────────────────────
  Widget _buildChoices() {
    final top = _choices.sublist(0, 3);
    final bottom = _choices.sublist(3);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 tiles + 2 gaps must always fit constraints.maxWidth exactly.
        // IMPORTANT: gaps are inserted as separate SizedBoxes BETWEEN tiles
        // (not as padding on every tile), otherwise the outer edges add
        // extra width that this formula doesn't account for — that mismatch
        // was the earlier "overflowed by N pixels" bug. The -2 is a tiny
        // safety margin against floating-point rounding in the layout engine.
        const spacing = 16.0;
        final rawSize = (constraints.maxWidth - spacing * 2 - 2) / 3;
        final tileSize = rawSize.clamp(56.0, 88.0);
        final tileHeight = tileSize * 0.86;

        Widget tile(String c) {
          final tileState = _eliminated.contains(c)
              ? _TileState.eliminated
              : _selectedChoice == null
                  ? _TileState.idle
                  : c == _roundLetter
                      ? _TileState.correct
                      : c == _selectedChoice
                          ? _TileState.wrong
                          : _TileState.idle;
          return SizedBox(
            width: tileSize,
            height: tileHeight,
            child: _ChoiceTile(
              label: c,
              state: tileState,
              onTap: () => _onChoiceTap(c),
              enabled: _selectedChoice == null &&
                  !_gameOver &&
                  !_gameWon &&
                  !_eliminated.contains(c),
            ),
          );
        }

        List<Widget> withGaps(List<String> letters) {
          final widgets = <Widget>[];
          for (var i = 0; i < letters.length; i++) {
            if (i > 0) widgets.add(const SizedBox(width: spacing));
            widgets.add(tile(letters[i]));
          }
          return widgets;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: withGaps(top),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: withGaps(bottom),
            ),
          ],
        );
      },
    );
  }

  // ── GAME OVER OVERLAY ────────────────────────────────────────────────────────
  Widget _buildGameOverOverlay() {
    return AnimatedBuilder(
      animation: _popCtrl,
      builder: (context, _) {
        final t = _popCtrl.value.clamp(0.0, 1.0);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55 * t),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: _AmbientParticles(
                      shape: _ParticleShape.circle,
                      colors: [
                        kElectricBlue.withValues(alpha: 0.55),
                        const Color(0xFF7C3AED).withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity:
                        CurvedAnimation(parent: _popCtrl, curve: Curves.easeOut),
                    child: ScaleTransition(
                      scale: _popScale,
                      child: _GameOverModal(
                        score: _score,
                        completed: _completedCount,
                        total: kCombinedPool.length,
                        mistakes: kMaxLives - _lives,
                        onRestart: _restart,
                        onExit: _exitGame,
                        revealAnim: _popCtrl,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── WIN OVERLAY ──────────────────────────────────────────────────────────────
  Widget _buildWinOverlay() {
    return AnimatedBuilder(
      animation: _winPopCtrl,
      builder: (context, _) {
        final t = _winPopCtrl.value.clamp(0.0, 1.0);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
          child: Container(
            color: Colors.black.withValues(alpha: 0.5 * t),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _AmbientParticles(
                      shape: _ParticleShape.star,
                      colors: [kAccentGold, Color(0xFF22C55E), kAccentCyan],
                    ),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity:
                        CurvedAnimation(parent: _winPopCtrl, curve: Curves.easeOut),
                    child: ScaleTransition(
                      scale: _winPopScale,
                      child: _WinModal(
                        score: _score,
                        total: kCombinedPool.length,
                        mistakes: kMaxLives - _lives,
                        message:
                            'Amazing! You completed all ${kCombinedPool.length} signs! 🎉',
                        actionLabel: '🔄  Play Again',
                        onRestart: _restart,
                        onExit: _exitGame,
                        revealAnim: _winPopCtrl,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern "famous game" style start modal — dark glass card, neon glow,
  // gradient badge + title, ambient floating particles, and a pulsing
  // gradient CTA. Replaces the old parchment/banner look.
  Widget _buildStartPromptOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // absorb taps so modal cannot be dismissed
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Stack(
              children: [
                // Ambient floating orbs behind the card for a lively,
                // modern-game backdrop.
                Positioned.fill(
                  child: _AmbientParticles(
                    shape: _ParticleShape.circle,
                    count: 20,
                    colors: [
                      kAccentCyan.withValues(alpha: 0.55),
                      kElectricBlue.withValues(alpha: 0.55),
                      kAccentGold.withValues(alpha: 0.45),
                    ],
                  ),
                ),
                Center(
                  child: ScaleTransition(
                    scale: _startPromptScale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: _buildStartCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Exit the game. While the start modal is open, the screen's PopScope blocks
  // popping (canPop: false), so a host onExit that uses maybePop() did nothing.
  // Close the start modal first, wait one frame for PopScope to update, then exit.
  void _exitGame() {
    if (_showStartPrompt) {
      setState(() => _showStartPrompt = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _performExit();
      });
      return;
    }
    _performExit();
  }

  void _performExit() {
    if (widget.onExit != null) {
      widget.onExit!();
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // Start card — same frosted-glass + cyan-glow language as the header banner,
  // stats card and mascot bubble, so it feels like part of the game screen.
  Widget _buildStartCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: kAccentCyan.withValues(alpha: 0.22),
            blurRadius: 44,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x80000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: kAccentCyan.withValues(alpha: 0.3), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Same gradient hand badge as the header
                _PulsingBadge(
                  glowColor: kAccentCyan,
                  size: 84,
                  child: _FloatingBob(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kElectricBlue, kAccentCyan],
                        ),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 2),
                      ),
                      child: ClipOval(
                        child: _AssetFallbackImage(
                          candidates: kGameIconCandidates,
                          fit: BoxFit.cover,
                          fallback: () => const Center(
                            child: Icon(
                              Icons.sports_esports_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, kAccentCyan],
                  ).createShader(bounds),
                  child: const Text(
                    'GUESS ASL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'CHALLENGE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kAccentGold,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Guess the sign — letters & numbers,\nall mixed together!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ruleTile('⏱', '${_GameScreenState.kStartTime}s',
                          'Per round', kAccentCyan),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ruleTile('💡', '${_GameScreenState.kMaxHints}',
                          'Hints', kAccentGold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ruleTile('❤️', '${_GameScreenState.kMaxLives}',
                          'Lives', kRed),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _PulseWrapper(
                  child: SizedBox(
                    width: double.infinity,
                    child: _ModalButton(
                      label: 'START GAME',
                      gradient: const LinearGradient(
                        colors: [kElectricBlue, kAccentCyan],
                      ),
                      glowColor: kAccentCyan,
                      textColor: Colors.white,
                      onTap: () {
                        _startPromptCtrl.reverse().then((_) {
                          if (!mounted) return;
                          setState(() => _showStartPrompt = false);
                          _startTimer();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _GhostButton(
                    label: 'Exit',
                    color: Colors.white,
                    onTap: _exitGame,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Small glass stat tile (emoji + big value + label) — same look as the
  // stat chips on the result modals.
  Widget _ruleTile(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHOICE TILE
// ─────────────────────────────────────────────────────────────────────────────
enum _TileState { idle, correct, wrong, eliminated }

class _ChoiceTile extends StatefulWidget {
  final String label;
  final _TileState state;
  final VoidCallback onTap;
  final bool enabled;

  const _ChoiceTile({
    required this.label,
    required this.state,
    required this.onTap,
    required this.enabled,
  });

  @override
  State<_ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<_ChoiceTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.state) {
      case _TileState.correct:
        return const Color(0xFF22C55E);
      case _TileState.wrong:
        return kRed;
      case _TileState.eliminated:
        return const Color(0xFF14203F);
      case _TileState.idle:
        return _hovering ? const Color(0xFF1D3A78) : const Color(0xFF16224A);
    }
  }

  Color get _borderColor {
    switch (widget.state) {
      case _TileState.eliminated:
        return Colors.white.withValues(alpha: 0.22);
      case _TileState.idle:
        return kAccentCyan.withValues(alpha: 0.35);
      case _TileState.correct:
      case _TileState.wrong:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEliminated = widget.state == _TileState.eliminated;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) _press.forward();
        },
        onTapUp: (_) {
          _press.reverse();
          if (widget.enabled) widget.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.96).animate(
            CurvedAnimation(parent: _press, curve: Curves.easeOut),
          ),
          // ONE layer only: the tile background and its letter live in the
          // same widget, so they always scale / recolor together and nothing
          // is drawn underneath or on top of another choice.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: _borderColor,
                  width: widget.state == _TileState.idle || isEliminated ? 1.5 : 2),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    inherit: false,
                    color: isEliminated
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                    decoration: isEliminated
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: Colors.white.withValues(alpha: 0.5),
                    decorationThickness: 2.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLINKING CURSOR (for typing animation)
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: const Text(
        '|',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT MODAL — shared shell for the Win / Game Over screens.
// Modern "game results card" look: overlapping badge, gradient mesh header,
// animated stat chips (Score / Accuracy / Completed), color-coded
// leaderboard, and a floating idle bob on top of the entrance bounce.
// ─────────────────────────────────────────────────────────────────────────────
class _ResultTheme {
  final Color primary; // borders, chips, badge
  final Color secondary; // badge gradient end
  final Color glow; // card + badge glow
  final Color titleAccent; // end color of the title gradient
  final Color ctaA; // restart button gradient
  final Color ctaB;
  final _ParticleShape particleShape;

  const _ResultTheme({
    required this.primary,
    required this.secondary,
    required this.glow,
    required this.titleAccent,
    required this.ctaA,
    required this.ctaB,
    required this.particleShape,
  });
}

// Dark frosted-glass result card (same language as the header / stats card /
// start modal). Win and defeat share the layout but get their own colors,
// badge, and "hero" widget (stars on win, progress + broken hearts on loss).
class _ResultModal extends StatelessWidget {
  final Animation<double> revealAnim;
  final _ResultTheme theme;
  final String bannerTitle;
  final String badgeEmoji;
  final String? cornerEmoji;
  final String subtitle;
  final String scoreLabel;
  final int score;
  final int completed;
  final int total;
  final int mistakes;
  final Widget extra;
  final bool showStats;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final String restartLabel;

  const _ResultModal({
    required this.revealAnim,
    required this.theme,
    required this.bannerTitle,
    required this.badgeEmoji,
    required this.subtitle,
    required this.scoreLabel,
    required this.score,
    required this.completed,
    required this.total,
    required this.mistakes,
    required this.extra,
    required this.onRestart,
    required this.restartLabel,
    this.cornerEmoji,
    this.showStats = true,
    this.onExit,
  });

  int get _accuracy {
    final attempts = completed + mistakes;
    if (attempts <= 0) return 100;
    return ((completed / attempts) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return _FloatingBob(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // ── Card body ──
            Container(
              margin: const EdgeInsets.only(top: 44),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: theme.glow.withValues(alpha: 0.30),
                    blurRadius: 44,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 30,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 52, 22, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.alphaBlend(
                            theme.primary.withValues(alpha: 0.20),
                            const Color(0xFF161B33),
                          ),
                          const Color(0xFF0F2247),
                          const Color(0xFF0A1930),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.primary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Title ──
                        _FadeSlideIn(
                          animation: revealAnim,
                          start: 0.1,
                          end: 0.5,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [Colors.white, theme.titleAccent],
                            ).createShader(bounds),
                            child: Text(
                              bannerTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _FadeSlideIn(
                          animation: revealAnim,
                          start: 0.2,
                          end: 0.55,
                          child: Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Hero extra (stars on win / progress on loss) ──
                        _FadeSlideIn(
                          animation: revealAnim,
                          start: 0.38,
                          end: 0.72,
                          child: extra,
                        ),
                        const SizedBox(height: 16),

                        if (showStats) ...[
                        // ── Stat chips ──
                        _FadeSlideIn(
                          animation: revealAnim,
                          start: 0.42,
                          end: 0.76,
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatChip(
                                  emoji: '🎯',
                                  value: '$_accuracy%',
                                  label: 'Accuracy',
                                  color: theme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatChip(
                                  emoji: '✅',
                                  value: '$completed/$total',
                                  label: 'Completed',
                                  color: theme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatChip(
                                  emoji: '💔',
                                  value: '$mistakes',
                                  label: 'Mistakes',
                                  color: theme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ],

                        // ── Leaderboard ──
                        _FadeSlideIn(
                          animation: revealAnim,
                          start: 0.5,
                          end: 0.85,
                          child: Column(
                            children: [
                              _leaderRow('🏆', "Today's Best",
                                  ScoreBoard.todayBest, kAccentGold),
                              const SizedBox(height: 8),
                              _leaderRow('🥈', "Week's Best",
                                  ScoreBoard.weekBest, kAccentCyan),
                              const SizedBox(height: 8),
                              _leaderRow('👑', 'All-time Best',
                                  ScoreBoard.allTimeBest, theme.titleAccent),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Buttons ──
                        _FadeSlideIn(
                          animation: revealAnim,
                          start: 0.6,
                          end: 0.95,
                          child: Row(
                            children: [
                              if (onExit != null) ...[
                                Expanded(
                                  child: _GhostButton(
                                    label: 'Exit',
                                    color: Colors.white,
                                    onTap: onExit!,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                flex: onExit != null ? 2 : 1,
                                child: _PulseWrapper(
                                  child: _ModalButton(
                                    label: restartLabel,
                                    onTap: onRestart,
                                    glowColor: theme.ctaA,
                                    gradient: LinearGradient(
                                        colors: [theme.ctaA, theme.ctaB]),
                                    textColor: Colors.white,
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
              ),
            ),

            // ── Overlapping glow badge ──
            _FadeSlideIn(
              animation: revealAnim,
              start: 0.0,
              end: 0.5,
              offsetY: -10,
              child: _PulsingBadge(
                size: 80,
                glowColor: theme.glow,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [theme.primary, theme.secondary],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 2.5),
                      ),
                      child: Center(
                        child: Text(badgeEmoji,
                            style: const TextStyle(fontSize: 38)),
                      ),
                    ),
                    if (cornerEmoji != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Text(cornerEmoji!,
                            style: const TextStyle(fontSize: 20)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaderRow(String emoji, String label, int value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color.withValues(alpha: 0.85),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── WIN: gold + green, trophy badge, 1–3 star rating ──
class _WinModal extends StatelessWidget {
  final int score;
  final int total;
  final int mistakes;
  final String message;
  final String actionLabel;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final Animation<double> revealAnim;

  const _WinModal({
    required this.score,
    required this.total,
    required this.mistakes,
    required this.message,
    required this.actionLabel,
    required this.onRestart,
    required this.revealAnim,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final filled = (3 - mistakes).clamp(1, 3).toInt();
    final stars = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i < filled;
        return Padding(
          padding: EdgeInsets.only(top: i == 1 ? 0 : 10, left: 4, right: 4),
          child: _ScaleIn(
            animation: revealAnim,
            start: 0.45 + i * 0.1,
            end: 0.75 + i * 0.1,
            child: Icon(
              Icons.star_rounded,
              size: i == 1 ? 54 : 42,
              color: on ? kAccentGold : Colors.white.withValues(alpha: 0.16),
              shadows: on
                  ? [
                      Shadow(
                          color: kAccentGold.withValues(alpha: 0.7),
                          blurRadius: 14),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );

    return _ResultModal(
      revealAnim: revealAnim,
      theme: const _ResultTheme(
        primary: kAccentGold,
        secondary: Color(0xFFF59E0B),
        glow: kAccentGold,
        titleAccent: kAccentGold,
        ctaA: kGreen,
        ctaB: Color(0xFF16A34A),
        particleShape: _ParticleShape.star,
      ),
      bannerTitle: 'YOU WIN!',
      badgeEmoji: '🏆',
      cornerEmoji: '✨',
      subtitle: message,
      scoreLabel: 'Final Score',
      score: score,
      completed: total,
      total: total,
      mistakes: mistakes,
      extra: stars,
      onRestart: onRestart,
      onExit: onExit,
      restartLabel: actionLabel,
    );
  }
}

// ── DEFEAT: red + purple, broken hearts, "how far you got" progress bar ──
class _GameOverModal extends StatelessWidget {
  final int score;
  final int completed;
  final int total;
  final int mistakes;
  final VoidCallback onRestart;
  final VoidCallback? onExit;
  final Animation<double> revealAnim;

  const _GameOverModal({
    required this.score,
    required this.completed,
    required this.total,
    required this.mistakes,
    required this.onRestart,
    required this.revealAnim,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final hero = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.heart_broken_rounded,
                size: 26,
                color: kRed.withValues(alpha: 0.85),
                shadows: [
                  Shadow(color: kRed.withValues(alpha: 0.5), blurRadius: 10),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 22, color: Colors.white.withValues(alpha: 0.08)),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 22,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kAccentGold, kElectricBlue],
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '$completed / $total signs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return _ResultModal(
      revealAnim: revealAnim,
      theme: const _ResultTheme(
        primary: kRed,
        secondary: Color(0xFF7C3AED),
        glow: kRed,
        titleAccent: Color(0xFFFF8A8A),
        ctaA: kElectricBlue,
        ctaB: kAccentCyan,
        particleShape: _ParticleShape.circle,
      ),
      bannerTitle: 'GAME OVER',
      badgeEmoji: '💔',
      subtitle: 'So close! Keep practicing, you\'ve got this',
      scoreLabel: 'Score',
      score: score,
      completed: completed,
      total: total,
      mistakes: mistakes,
      extra: hero,
      showStats: false,
      onRestart: onRestart,
      onExit: onExit,
      restartLabel: 'Try Again',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL ANIMATION HELPERS — staggered fade/slide, scale-in, floating idle
// bob, breathing glow, idle button pulse, count-up numbers, and an ambient
// particle field (stars for wins, soft orbs for game over).
// ─────────────────────────────────────────────────────────────────────────────
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final double start;
  final double end;
  final double offsetY;
  final Widget child;

  const _FadeSlideIn({
    required this.animation,
    required this.child,
    this.start = 0.0,
    this.end = 1.0,
    this.offsetY = 14,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final v = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}

class _ScaleIn extends StatelessWidget {
  final Animation<double> animation;
  final double start;
  final double end;
  final Widget child;

  const _ScaleIn({
    required this.animation,
    required this.child,
    this.start = 0.0,
    this.end = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.elasticOut),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final v = curved.value.clamp(0.0, 1.4);
        return Transform.scale(scale: v, child: child);
      },
    );
  }
}

class _FloatingBob extends StatefulWidget {
  final Widget child;
  const _FloatingBob({required this.child});

  @override
  State<_FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<_FloatingBob>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final dy = (t - 0.5) * 10;
        return Transform.translate(offset: Offset(0, dy), child: widget.child);
      },
    );
  }
}

class _PulseWrapper extends StatefulWidget {
  final Widget child;
  const _PulseWrapper({required this.child});

  @override
  State<_PulseWrapper> createState() => _PulseWrapperState();
}

class _PulseWrapperState extends State<_PulseWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = 1.0 + t * 0.035;
        return Transform.scale(scale: scale, child: widget.child);
      },
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double size;

  const _PulsingBadge({
    required this.child,
    required this.glowColor,
    this.size = 96,
  });

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = 1.0 + t * 0.12;
        final glowOpacity = 0.22 + t * 0.35;
        return SizedBox(
          width: widget.size + 28,
          height: widget.size + 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: glowOpacity),
                        blurRadius: 26,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _CountUpNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const _CountUpNumber({
    required this.value,
  }) : style = null;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$v', style: style),
    );
  }
}

enum _ParticleShape { star, circle }

class _Particle {
  final double dx;
  final double speed;
  final double size;
  final double phase;
  final double drift;
  final Color color;
  const _Particle({
    required this.dx,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
    required this.color,
  });
}

// Continuously floating ambient background particles — stars for the win
// screen, soft orbs for the game-over screen. Loops forever, independent of
// the modal's entrance animation, for a lively "modern game" backdrop.
class _AmbientParticles extends StatefulWidget {
  final _ParticleShape shape;
  final List<Color> colors;
  final int count;

  const _AmbientParticles({
    required this.shape,
    required this.colors,
    this.count = 16,
  });

  @override
  State<_AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<_AmbientParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    final rnd = Random(7);
    _particles = List.generate(widget.count, (i) {
      return _Particle(
        dx: rnd.nextDouble(),
        speed: 0.4 + rnd.nextDouble() * 0.8,
        size: 4 + rnd.nextDouble() * 8,
        phase: rnd.nextDouble(),
        drift: (rnd.nextDouble() - 0.5) * 24,
        color: widget.colors[i % widget.colors.length],
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            return Stack(
              children: _particles.map((p) {
                final loopT = (t * p.speed + p.phase) % 1.0;
                // Floats from bottom to top, then wraps around.
                final y = constraints.maxHeight * (1 - loopT);
                final x = p.dx * constraints.maxWidth +
                    sin(loopT * 2 * pi) * p.drift;
                final opacity = sin(loopT * pi).clamp(0.0, 1.0);
                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: opacity * 0.8,
                    child: widget.shape == _ParticleShape.star
                        ? _StarShape(size: p.size, color: p.color)
                        : Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.color,
                            ),
                          ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _StarShape extends StatelessWidget {
  final double size;
  final Color color;
  const _StarShape({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(color: color),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  const _StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    for (int i = 0; i < 4; i++) {
      final angle = (pi / 2) * i;
      final tipX = cx + r * cos(angle);
      final tipY = cy + r * sin(angle);
      final midAngle = angle + pi / 4;
      final midX = cx + (r * 0.35) * cos(midAngle);
      final midY = cy + (r * 0.35) * sin(midAngle);
      if (i == 0) {
        path.moveTo(tipX, tipY);
      } else {
        path.lineTo(tipX, tipY);
      }
      path.lineTo(midX, midY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ModalButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color textColor;
  final Color? glowColor;

  const _ModalButton({
    required this.label,
    required this.onTap,
    required this.gradient,
    required this.textColor,
    this.glowColor,
  });

  @override
  State<_ModalButton> createState() => _ModalButtonState();
}

class _ModalButtonState extends State<_ModalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.94).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        ),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor != null
                    ? widget.glowColor!.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.12),
                blurRadius: widget.glowColor != null ? 16 : 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: widget.textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}