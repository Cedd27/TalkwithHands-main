import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import 'admin_analytics_screen.dart';
import '../ui/app_shell.dart';
import 'landing_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _textOffset;
  late final Animation<double> _textOpacity;
  Future<void>? _routeFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _textOffset = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1, curve: Curves.easeOut),
    );

    _routeFuture = _goToFirstScreen();
  }

  Future<void> _goToFirstScreen() async {
    final hasSessionFuture = AuthService.hasStoredSession();
    final cachedProfileFuture = AuthService.cachedProfile();
    final meFuture = AuthService().me();
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    final hasSession = await hasSessionFuture;
    final cachedProfile = await cachedProfileFuture;
    final me = await meFuture.timeout(
      const Duration(seconds: 8),
      onTimeout: () => cachedProfile,
    );
    if (!mounted) return;

    final profile = me ?? cachedProfile;
    final isAdmin =
        profile?.email?.trim().toLowerCase() == 'talkwithhands06@gmail.com';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => !hasSession && profile == null
            ? const LandingScreen()
            : isAdmin
                ? AdminAnalyticsScreen(userName: profile?.username ?? 'Admin')
                : WelcomeScreen(userName: profile?.username ?? 'Student'),
      ),
    );
  }

  @override
  void dispose() {
    _routeFuture?.ignore();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        showToggle: false,
        child: ColoredBox(
          color: Colors.black,
          child: _buildSplashContent(),
        ),
      ),
    );
  }

  Widget _buildSplashContent() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 500;
          final logoSize = constraints.maxWidth < 360 ? 92.0 : 110.0;
          final textSize = constraints.maxWidth < 360 ? 22.0 : 29.0;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final logo = Transform.scale(
                scale: _logoScale.value,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x88FFFFFF),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: AppLogo(size: logoSize),
                ),
              );
              final title = FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textOffset,
                  child: Text(
                    'Talk with Hands',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: textSize,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Georgia',
                      shadows: const [
                        Shadow(
                          color: Color(0x66FFFFFF),
                          offset: Offset(0, 1),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (stacked) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    logo,
                    const SizedBox(height: 16),
                    title,
                  ],
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  logo,
                  const SizedBox(width: 18),
                  title,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
