import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import 'auth_screen.dart';
import 'alphabets_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/NEW BACKGROUND/new sign in log in.png',
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420 ||
                    constraints.maxHeight <
                        650; // Adjust compact threshold as needed
                final logoSize =
                    compact ? 80.0 : 95.0; // Adjust logo size for compact mode
                final titleWidth = constraints.maxWidth
                    .clamp(240.0, 320.0); // Adjust title width for compact mode

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact
                        ? 25
                        : 34, // Adjust horizontal padding for compact mode
                    vertical: compact ? 125 : 35,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          (compact ? 39 : 41), // Adjust for vertical padding
                    ),
                    child: Column(
                      // Main column for logo, title, and button
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Transform.rotate(
                              angle: 0.0,
                              child: Container(
                                width: titleWidth,
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 20 : 28,
                                  (compact ? 10 : 46) + logoSize / 2,
                                  compact ? 20 : 28,
                                  compact ? 30 : 46,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                      color: const Color.fromARGB(255, 0, 0, 0),
                                      width: 2.2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromARGB(136, 216, 209, 209),
                                      offset: Offset(10, 10),
                                      blurRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Color(0x8839D8E8),
                                      spreadRadius: 2,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Transform.rotate(
                                  angle: 0.0,
                                  child: Text(
                                    'Talk with\nHands',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: compact ? 32 : 40,
                                      height: 1.02,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w900,
                                      color: const Color.fromARGB(255, 0, 0, 0),
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x55000000),
                                          offset: Offset(0, 6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -(logoSize / 2),
                              child: AppLogo(size: logoSize),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 80 : 40),
                        // Transform.translate moves ONLY the buttons down
                        // (title box and logo stay in place). Change 40 to adjust.
                        Transform.translate(
                          offset: Offset(0, compact ? 30 : 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LandingPillButton(
                                label: 'Login',
                                background: Colors.white,
                                borderColor:
                                    const Color.fromARGB(255, 171, 184, 226),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AuthScreen(
                                          initialTab: AuthTab.login),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 30),
                              _LandingPillButton(
                                label: 'Sign in',
                                background:
                                    const Color.fromARGB(255, 255, 139, 186),
                                borderColor:
                                    const Color.fromARGB(111, 99, 88, 101),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AuthScreen(
                                          initialTab: AuthTab.register),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 42),
                          _LandingPillButton(
                            label: 'Preview Alphabets (Guest)',
                            background: const Color(0xFF39D8E8),
                            borderColor: const Color(0xFF1387C9),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AlphabetsScreen(userName: 'Guest'),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: compact ? 68 : 120),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingPillButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color? borderColor;
  final VoidCallback onTap;

  const _LandingPillButton({
    required this.label,
    required this.background,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (borderColor != null)
                BoxShadow(
                  color: borderColor!,
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              const BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
