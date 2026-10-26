import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'progress_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String userName;

  const WelcomeScreen({
    super.key,
    required this.userName,
  });

  String get _firstName {
    final parts = userName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : userName;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background ─────────────────────────────────────────────────
            Image.asset(
              'assets/images/home_bg_clean.png',
              fit: BoxFit.cover,
              width: sw,
              height: sh,
            ),

            // ── Logo button (top-left) ─────────────────────────────────────
            Positioned(
              top: topPad + 15,
              left: 14,
              child: _CircleBtn(
                onTap: () {},
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 68,
                  height: 68,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sign_language_rounded,
                    color: Color.fromARGB(255, 1, 1, 1),
                    size: 26,
                    shadows: [
                      Shadow(
                          color: Color.fromARGB(255, 0, 0, 0),
                          offset: Offset(10, 5),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),

            // ── "Kumusta ka," ───────────────────────────────────────────
            Positioned(
              top: sh * 0.11 + topPad,
              left: 22,
              right: 22,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Kumusta ka, ',
                    style: GoogleFonts.poetsenOne(
                      color: Colors.white,
                      fontSize: sw * 0.068,
                      shadows: const [
                        Shadow(
                            color: Colors.black26,
                            offset: Offset(1, 2),
                            blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── "[Name]!" pink bold italic ─────────────────────────────────
            Positioned(
              top: sh * 0.14 + topPad,
              left: 50,
              right: 22,
              child: Text(
                '$_firstName!',
                style: GoogleFonts.poetsenOne(
                  color: const Color.fromARGB(255, 240, 237, 239),
                  fontSize: sw * 0.110,
                  fontStyle: FontStyle.italic,
                  shadows: const [
                    Shadow(
                        color: Color(0x66000000),
                        offset: Offset(2, 3),
                        blurRadius: 6),
                    Shadow(
                        color: Color.fromARGB(253, 246, 109, 237),
                        offset: Offset(-1, -1),
                        blurRadius: 3),
                  ],
                ),
              ),
            ),

            // ── Speech bubble ──────────────────────────────────────────────
            Positioned(
              top: sh * 0.24 + topPad,
              left: sw * 0.10,
              right: sw * 0.04,
              child: Transform.rotate(
                angle: -5 * 3.14159265 / 180,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: sw * 0.045,
                        vertical: sh * 0.018,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(235, 250, 250, 250),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 15,
                            offset: const Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Handa ka na bang matuto\nng bagong Senyas ngayong\naraw?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1A2A5E),
                          fontSize: sw * 0.030,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                    ),
                    // bubble tail — bottom-left pointing to character
                    Positioned(
                      bottom: -13,
                      left: 26,
                      child: CustomPaint(
                        size: const Size(24, 14),
                        painter: _BubbleTailPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Transparent sign video overlay ─────────────────────────────
            Positioned(
              top: sh * 0.50,
              left: 0,
              right: 0,
              bottom: sh * 0.165,
              child: const TransparentSignVideoOverlay(
                fit: BoxFit.cover,
                edgeCrop: 0.04,
                verticalCrop: 0.18,
              ),
            ),

            // ── Start button ───────────────────────────────────────────────
            Positioned(
              bottom: sh * 0.095,
              left: sw * 0.12,
              right: sw * 0.12,
              child: _StartButton(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProgressScreen(userName: userName),
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

// ── Bubble tail ───────────────────────────────────────────────────────────────
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Circle button ─────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 50, height: 50, child: Center(child: child)),
      ),
    );
  }
}

// ── Start button ──────────────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.white24,
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF90EEFF), Color(0xFF2EC8F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2EC8F2).withValues(alpha: 0.65),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            'Start',
            style: GoogleFonts.nunito(
              color: const Color(0xFF0D2D7A),
              fontSize: sw * 0.072,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(
                  color: Colors.white54,
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
