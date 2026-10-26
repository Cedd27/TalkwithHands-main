import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sign_language_app/games/calculator_game.dart' as calculator;
import 'package:sign_language_app/games/guess_asl_game.dart' as guess_asl;
import 'package:sign_language_app/games/guess_me_game.dart' as guess_me;
import '../services/progress_service.dart';
import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';

class GameHubScreen extends StatefulWidget {
  final String userName;

  const GameHubScreen({
    super.key,
    required this.userName,
  });

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _recordGamePlayed(String gameKey) async {
    try {
      await ProgressService().recordActivity(
        category: 'game',
        itemKey: gameKey,
        gameCompleted: true,
      );
    } catch (_) {
      // Progress sync should never interrupt gameplay.
    }
  }

  void _openGuessAsl() {
    _recordGamePlayed('guess_asl');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => guess_asl.GameScreen(
          onExit: () => Navigator.of(context).maybePop(),
          onGameFinished: ({
            required won,
            required score,
            required completed,
            required total,
          }) {},
        ),
      ),
    );
  }

  void _openGuessMe() {
    _recordGamePlayed('guess_me');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => guess_me.GuessMeScreen(
          onGameFinished: () {},
        ),
      ),
    );
  }

  void _openCalculator() {
    _recordGamePlayed('calculator');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const calculator.CalculatorGamePage(),
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
        activeScreen: 'Game',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.gameHub,
        child: _GameStageBackground(
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
                    const SizedBox(height: 14),
                    const Text(
                      'GAME',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns =
                                  constraints.maxWidth > 520 ? 3 : 2;
                              final spacing = columns == 2 ? 18.0 : 22.0;
                              final itemWidth = (constraints.maxWidth -
                                      spacing * (columns - 1)) /
                                  columns;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: 22,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    child: _GameTile(
                                      label: 'Calculator',
                                      subtitle: 'Camera or keypad',
                                      onTap: _openCalculator,
                                      child: const _CalculatorIcon(),
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _GameTile(
                                      label: 'Guess ASL',
                                      subtitle: 'Letters & numbers',
                                      onTap: _openGuessAsl,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(22),
                                        child: Image.asset(
                                          'assets/images/guess_asl_icon.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const _GuessAslIcon(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _GameTile(
                                      label: 'Guess Me',
                                      subtitle: 'Video phrase quiz',
                                      onTap: _openGuessMe,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(22),
                                        child: Image.asset(
                                          'assets/images/guess_me_icon.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const _GuessMeIcon(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
}

class _GameStageBackground extends StatelessWidget {
  final Widget child;

  const _GameStageBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 61, 67, 196),
            Color.fromARGB(255, 34, 20, 139),
            Color.fromARGB(159, 203, 125, 208),
            Color.fromARGB(255, 20, 3, 175),
          ],
          stops: [0, 0.38, 0.72, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/NEW BACKGROUND/new games.png',
            fit: BoxFit.cover,
          ),
          CustomPaint(
            painter: _GameStagePainter(),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GameStagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft, blurred glow orbs give the stage depth instead of flat color.
    _drawGlowOrb(canvas, Offset(size.width * 0.14, size.height * 0.16),
        size.width * 0.55, const Color.fromARGB(255, 112, 92, 17));
    _drawGlowOrb(canvas, Offset(size.width * 0.9, size.height * 0.1),
        size.width * 0.5, const Color(0xFF4DE8FF));
    _drawGlowOrb(canvas, Offset(size.width * 0.82, size.height * 0.68),
        size.width * 0.6, const Color(0xFFFF5DA2));
    _drawGlowOrb(canvas, Offset(size.width * 0.08, size.height * 0.78),
        size.width * 0.45, const Color(0xFF7C4DFF));

    // Faint dotted grid reads as a fun "game board" texture without the
    // busyness of hard stripes.
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const dotSpacing = 34.0;
    for (double y = dotSpacing * 0.5; y < size.height; y += dotSpacing) {
      final rowOffset =
          ((y / dotSpacing).floor().isEven) ? 0.0 : dotSpacing / 2;
      for (double x = rowOffset; x < size.width; x += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 1.6, dotPaint);
      }
    }

    // Sparkle accents scattered around, like little stage twinkles.
    final sparkles = [
      (Offset(size.width * 0.22, size.height * 0.10), 10.0),
      (Offset(size.width * 0.68, size.height * 0.06), 7.0),
      (Offset(size.width * 0.95, size.height * 0.42), 8.0),
      (Offset(size.width * 0.06, size.height * 0.52), 6.0),
      (Offset(size.width * 0.40, size.height * 0.08), 5.0),
    ];
    for (final s in sparkles) {
      _drawSparkle(canvas, s.$1, s.$2, Colors.white.withValues(alpha: 0.85));
    }

    // Confetti: a mix of rounded squares and dots for a party-ish feel.
    final confettiPaint = Paint()..style = PaintingStyle.fill;
    final confetti = [
      (
        Offset(size.width * 0.12, size.height * 0.17),
        const Color(0xFFFFD43B),
        true
      ),
      (
        Offset(size.width * 0.78, size.height * 0.31),
        const Color(0xFFFF5DA2),
        false
      ),
      (
        Offset(size.width * 0.24, size.height * 0.63),
        const Color(0xFF69F0AE),
        true
      ),
      (
        Offset(size.width * 0.90, size.height * 0.62),
        const Color(0xFFFFF176),
        false
      ),
      (
        Offset(size.width * 0.52, size.height * 0.15),
        const Color(0xFFE040FB),
        true
      ),
      (
        Offset(size.width * 0.34, size.height * 0.42),
        const Color(0xFF4DE8FF),
        false
      ),
      (
        Offset(size.width * 0.62, size.height * 0.55),
        const Color(0xFFFFA94D),
        true
      ),
    ];

    for (final item in confetti) {
      confettiPaint.color = item.$2.withValues(alpha: 0.75);
      final center = item.$1;
      final side = size.width * 0.03;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(center.dx / size.width * 2);
      if (item.$3) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: side, height: side),
            const Radius.circular(3),
          ),
          confettiPaint,
        );
      } else {
        canvas.drawCircle(Offset.zero, side * 0.42, confettiPaint);
      }
      canvas.restore();
    }

    // Gentle curved stage floor to ground the content area.
    final floorPath = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.78,
        size.width,
        size.height * 0.88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final floorPaint = Paint()..color = const Color(0x28180030);
    canvas.drawPath(floorPath, floorPaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.30);
    _drawGamepad(canvas, Offset(size.width * 0.80, size.height * 0.80),
        size.width * 0.16, outlinePaint);

    // Subtle top-and-bottom vignette so the tile grid in the middle pops.
    final vignettePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x33130826),
          Color(0x00000000),
          Color(0x00000000),
          Color(0x55130826),
        ],
        stops: [0, 0.22, 0.7, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  void _drawGlowOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius, paint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawGamepad(Canvas canvas, Offset center, double width, Paint paint) {
    final height = width * 0.52;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(height * 0.38)),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - width * 0.30, center.dy),
      Offset(center.dx - width * 0.16, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - width * 0.23, center.dy - height * 0.16),
      Offset(center.dx - width * 0.23, center.dy + height * 0.16),
      paint,
    );
    canvas.drawCircle(
        Offset(center.dx + width * 0.20, center.dy - height * 0.08),
        width * 0.025,
        paint);
    canvas.drawCircle(
        Offset(center.dx + width * 0.31, center.dy + height * 0.08),
        width * 0.025,
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GameTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget child;
  final VoidCallback onTap;

  const _GameTile({
    required this.label,
    required this.subtitle,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x332693FF), width: 1.4),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFEAF8FF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF002693).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 21,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF185FA5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuessMeIcon extends StatelessWidget {
  const _GuessMeIcon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF27AAEB), Color(0xFF0D6FAB)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GuessMeIconPainter()),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 46),
                  SizedBox(height: 8),
                  Text(
                    'GUESS\nME?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 0.9,
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

class _GuessAslIcon extends StatelessWidget {
  const _GuessAslIcon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD43B), Color(0xFFFF6B6B)],
          ),
        ),
        child: const Center(
          child: Text(
            'ASL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuessMeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = size.width * 0.12;
    for (double x = -size.height; x < size.width + size.height; x += 36) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CalculatorIcon extends StatelessWidget {
  const _CalculatorIcon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          _CalcCell(label: '+', color: Color(0xFFFF9700)),
          _CalcCell(label: '-', color: Color(0xFFFF9700)),
          _CalcCell(label: 'x', color: Color(0xFFFF9700)),
          _CalcCell(label: '=', color: Color(0xFFD8D8D8), dark: true),
        ],
      ),
    );
  }
}

class _CalcCell extends StatelessWidget {
  final String label;
  final Color color;
  final bool dark;

  const _CalcCell({
    required this.label,
    required this.color,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.black54 : Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ── Decorative floating bubbles for the background ──────────────────────────
// Purely visual, non-interactive layer — sits behind all existing screen
// content and does not change any other part of the design.
const List<Color> _bubbleColors = [
  Color(0xFFFFD43B),
  Color.fromARGB(255, 196, 93, 255),
  Color(0xFF69F0AE),
  Color(0xFFFFF176),
  Color.fromARGB(255, 32, 8, 156),
  Colors.white,
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
          ..color = b.color.withValues(alpha: opacity * 1.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
        canvas.drawCircle(Offset(x, y), radius, ring);
      } else {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = b.color.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
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
