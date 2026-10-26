import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/alphabets_screen.dart';
import '../screens/about_us_screen.dart';
import '../screens/admin_analytics_screen.dart';
import '../screens/admin_content_screen.dart';
import '../screens/basic_words_screen.dart';
import '../screens/game_hub_screen.dart';
import '../screens/numbers_screen.dart';
import '../screens/panorama_screen.dart'; // add at top
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sign_detector_screen.dart';
import '../screens/landing_screen.dart';
import '../services/activity_time_service.dart';
import '../services/auth_service.dart';

const Color kAccent = Color(0xFF39D8E8);
const Color kVividBlue = Color(0xFF002693);
const Color kDeepBlue = Color(0xFF0D567E);
const Color kBackgroundBlue = Color(0xFF1387C9);
const String kLogoAsset = 'assets/images/app_logo.png';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool dimmed;
  final String? imageAsset;

  const AppBackground({
    super.key,
    required this.child,
    this.dimmed = false,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA9DFFF), Color(0xFFEAF9FF), Color(0xFF57B9FF)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAsset == null)
            const _SkyBackdrop()
          else
            Image.asset(
              imageAsset!,
              fit: BoxFit.cover,
            ),
          if (dimmed)
            Container(
              color: Colors.black.withValues(alpha: 0.32),
            ),
          child,
        ],
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 104,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        kLogoAsset,
        fit: BoxFit.cover,
      ),
    );
  }
}

class OvalActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;

  const OvalActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 190,
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height),
      ),
      child: Material(
        color: kAccent,
        borderRadius: BorderRadius.circular(height),
        child: InkWell(
          borderRadius: BorderRadius.circular(height),
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.black,
                  shadows: [
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
      ),
    );
  }
}

class AppTopBar extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final bool showLogo;

  const AppTopBar({
    super.key,
    this.title,
    this.onBack,
    this.onMenu,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize =
        MediaQuery.sizeOf(context).shortestSide < 360 ? 62.0 : 47.0;
    final sideSlot = logoSize + 16;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 360 ? 12 : 18,
          vertical: 10,
        ),
        child: Row(
          children: [
            if (onBack != null) ...[
              AppBackIconButton(
                onTap: onBack!,
                size: logoSize,
              ),
              if (onMenu != null) ...[
                const SizedBox(width: 8),
                AppMenuIconButton(
                  onTap: onMenu!,
                  size: logoSize,
                ),
              ],
            ] else if (showLogo)
              AppLogo(size: logoSize)
            else
              SizedBox(width: sideSlot),
            if (title != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 360 ? 22 : 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            if (onMenu != null && onBack == null)
              AppMenuIconButton(
                onTap: onMenu!,
                size: logoSize,
              )
            else if (onMenu == null)
              SizedBox(width: sideSlot),
          ],
        ),
      ),
    );
  }
}

class AppMenuDrawer extends StatefulWidget {
  final String userName;
  final VoidCallback onClose;
  final String activeScreen;

  const AppMenuDrawer({
    super.key,
    required this.userName,
    required this.onClose,
    this.activeScreen = 'Home',
  });

  @override
  State<AppMenuDrawer> createState() => _AppMenuDrawerState();
}

class _AppMenuDrawerState extends State<AppMenuDrawer> {
  static const _adminEmail = 'talkwithhands06@gmail.com';
  bool _isAdmin = false;
  bool _adminStatusLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final cached = await AuthService.cachedProfile();
    if (mounted && _isAdminProfile(cached)) {
      setState(() {
        _isAdmin = true;
        _adminStatusLoaded = true;
      });
    }

    final profile = await AuthService().me();
    if (!mounted) return;
    setState(() {
      _isAdmin = _isAdminProfile(profile) || _isAdmin;
      _adminStatusLoaded = true;
    });
  }

  bool _isAdminProfile(dynamic profile) {
    return profile?.email?.trim().toLowerCase() == _adminEmail;
  }

  Future<void> _logout() async {
    await ActivityTimeService.instance.prepareForAccountChange();
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(MediaQuery.of(context).size.width * 0.86, 390),
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A6FD4),
                Color(0xFF1387C9),
                Color(0xFF0D567E),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(48),
              bottomLeft: Radius.circular(48),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, compact ? 12 : 18, 12, compact ? 12 : 18),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Header with close button
                  Row(
                    children: [
                      // Hand icon — signs directly to the app's purpose
                      // (sign language) instead of a generic heart, so the
                      // menu identity is instantly recognizable.
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF39D8E8), Color(0xFF1387C9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.front_hand_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'MENU',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Color(0x8839D8E8),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'LEARN • PRACTICE • CONNECT',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 254, 254, 254)
                                    .withValues(alpha: 0.95),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button — white circle
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  // User greeting pill
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.09),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: kAccent.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF39D8E8), Color(0xFF1A6FD4)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.userName.isNotEmpty
                                ? widget.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.waving_hand_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Hi, ${widget.userName}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          kAccent.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  _SectionLabel(
                    label: !_adminStatusLoaded
                        ? 'MENU'
                        : _isAdmin
                            ? 'ADMIN'
                            : 'MAIN',
                  ),
                  if (!_adminStatusLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (_isAdmin) ...[
                    _MenuTile(
                      icon: Icons.analytics_rounded,
                      title: 'Analytics',
                      active: widget.activeScreen == 'Analytics',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminAnalyticsScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.sort_by_alpha_rounded,
                      title: 'Alphabets',
                      active: widget.activeScreen == 'ALPHABETS',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminContentScreen(
                              userName: widget.userName,
                              initialTab: AdminContentTab.alphabets,
                            ),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.pin_rounded,
                      title: 'Numbers',
                      active: widget.activeScreen == 'NUMBERS',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminContentScreen(
                              userName: widget.userName,
                              initialTab: AdminContentTab.numbers,
                            ),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.book_rounded,
                      title: 'Basic Words',
                      active: widget.activeScreen == 'BASIC WORDS',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminContentScreen(
                              userName: widget.userName,
                              initialTab: AdminContentTab.basicWords,
                            ),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      onTap: _logout,
                    ),
                  ] else ...[
                    _MenuTile(
                      icon: Icons.bar_chart_rounded,
                      title: 'Progress',
                      active: widget.activeScreen == 'Progress',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProgressScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    const _SectionLabel(label: 'LEARN & PRACTICE'),
                    _MenuTile(
                      icon: Icons.sort_by_alpha_rounded,
                      title: 'Alphabets',
                      active: widget.activeScreen == 'Alphabets',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AlphabetsScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.pin_rounded,
                      title: 'Numbers',
                      active: widget.activeScreen == 'Numbers',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                NumbersScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.book_rounded,
                      title: 'Basic Words',
                      active: widget.activeScreen == 'Basic Words',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BasicWordsScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.pan_tool_alt_rounded,
                      title: 'Sign to Text',
                      active: widget.activeScreen == 'Sign to Text',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignDetectorScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.threesixty_rounded,
                      title: '180° Pictures',
                      active: widget.activeScreen == '180 Pictures',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.activeScreen == '180 Pictures') return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                PanoramaScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.sports_esports_rounded,
                      title: 'Game',
                      active: widget.activeScreen == 'Game',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GameHubScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: compact ? 6 : 12),
                    const _SectionLabel(label: 'PROFILE'),
                    _MenuTile(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      active: widget.activeScreen == 'Settings',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.info_rounded,
                      title: 'About us',
                      active: widget.activeScreen == 'About us',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AboutUsScreen(userName: widget.userName),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyBackdrop extends StatelessWidget {
  const _SkyBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StripedPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _StripedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.48);
    final heartPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFF6BB7).withValues(alpha: 0.62);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.62);
    final bubblePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x66FFFFFF), Color(0x4439D8E8)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.16, size.height * 0.18),
        radius: 24,
      ));

    canvas.drawCircle(
        Offset(size.width * 0.16, size.height * 0.18), 24, bubblePaint);
    canvas.drawCircle(
        Offset(size.width * 0.81, size.height * 0.28), 15, bubblePaint);
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.45), 18, bubblePaint);

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.28, size.height * 0.13)
        ..cubicTo(size.width * 0.40, size.height * 0.03, size.width * 0.50,
            size.height * 0.18, size.width * 0.50, size.height * 0.18)
        ..cubicTo(size.width * 0.50, size.height * 0.18, size.width * 0.62,
            size.height * 0.03, size.width * 0.75, size.height * 0.13),
      ringPaint,
    );

    void cloud(double x, double y, double scale) {
      canvas.drawCircle(Offset(x, y), 18 * scale, cloudPaint);
      canvas.drawCircle(
          Offset(x + 18 * scale, y - 8 * scale), 24 * scale, cloudPaint);
      canvas.drawCircle(Offset(x + 42 * scale, y), 18 * scale, cloudPaint);
      canvas.drawRect(
          Rect.fromLTWH(x - 18 * scale, y, 78 * scale, 18 * scale), cloudPaint);
    }

    cloud(size.width * 0.01, size.height * 0.72, 0.8);
    cloud(size.width * 0.72, size.height * 0.80, 0.7);

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.86, size.height * 0.20)
        ..cubicTo(size.width * 0.83, size.height * 0.17, size.width * 0.78,
            size.height * 0.21, size.width * 0.86, size.height * 0.26)
        ..cubicTo(size.width * 0.94, size.height * 0.21, size.width * 0.89,
            size.height * 0.17, size.width * 0.86, size.height * 0.20),
      heartPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppBackIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const AppBackIconButton({
    super.key,
    required this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF0697B4),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 2.2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: size * 0.56,
            ),
          ),
        ),
      ),
    );
  }
}

class AppMenuIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const AppMenuIconButton({
    super.key,
    required this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    // Same styling as AppBackIconButton so both top-bar buttons match.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF0697B4),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 2.2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.menu_rounded,
              color: Colors.white,
              size: size * 0.72,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: kAccent,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF0697B4),
                        Color(0xFF0697B4),
                      ],
                    )
                  : null,
              color: active ? null : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.22),
                width: active ? 2.2 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Solid accent bar — an unmissable "you are here" cue that
                // doesn't rely on subtle color/opacity shifts alone.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 4 : 0,
                  height: compact ? 22 : 26,
                  margin: EdgeInsets.only(right: active ? 8 : 0),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: kAccent.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: active
                          ? const [Color(0xFF5CEBFA), Color(0xFF1387C9)]
                          : const [Color(0xFF39D8E8), Color(0xFF0D567E)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? Colors.white.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.55),
                      width: active ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (active ? kAccent : const Color(0xFF39D8E8))
                            .withValues(alpha: active ? 0.75 : 0.45),
                        blurRadius: active ? 14 : 8,
                        spreadRadius: active ? 0.5 : 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: compact ? 18 : 20,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 3),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 9 : 11),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 14 : 16,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: active ? 0.5 : 0.2,
                      shadows: active
                          ? const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: active
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.4),
                  size: compact ? 18 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const GlassButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kAccent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
