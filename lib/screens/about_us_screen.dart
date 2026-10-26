import 'package:flutter/material.dart';

import '../ui/app_shell.dart';

// ── Palette ──────────────────────────────────────────────────────────────
const _kTitleBlue = Color(0xFF0B2E6B);
const _kDeepBlue = Color(0xFF071A3F);
const _kAccent = Color(0xFF11B7CB);
const _kCoral = Color(0xFFFF6B8A);
const _kGold = Color(0xFFF5A623);
const _kGreen = Color(0xFF2ECC71);
const _kPurple = Color(0xFF8B5CF6);

class AboutUsScreen extends StatelessWidget {
  final String userName;

  const AboutUsScreen({
    super.key,
    required this.userName,
  });

  static const _developers = [
    _Developer(
      name: 'Bungualan, Renz F.',
      role: 'System Analyst',
      imageAsset: 'assets/images/renzz.jpg',
    ),
    _Developer(
      name: 'Cuentas, Jade Allen',
      role: 'System Tester',
      imageAsset: 'assets/images/jade.jpg',
    ),
    _Developer(
      name: 'De Rama, John Cedrick B.',
      role: 'System Designer',
      imageAsset: 'assets/images/jjderama.jpg',
    ),
    _Developer(
      name: 'Ecal, Jomaica H.',
      role: 'Project Manager',
      imageAsset: 'assets/images/ecal.png',
    ),
    _Developer(
      name: 'Gucela, Diana T.',
      role: 'Technical Writer',
      imageAsset: 'assets/images/diana.jpg',
    ),
    _Developer(
      name: 'Manalo, Mary Jasmine B.',
      role: 'Programmer',
      imageAsset: 'assets/images/mary.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'About us',
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    children: [
                      const _HeroHeader(),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AppTopBar(
                            onBack: () => Navigator.of(context).pop(),
                            onMenu: () =>
                                scaffoldKey.currentState?.openEndDrawer(),
                            showLogo: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: const _StatsRow(),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 18, 20),
                    child: Column(
                      children: [
                        _MissionCard(),
                        SizedBox(height: 22),
                        _SectionHeading(
                          icon: Icons.groups_2_rounded,
                          accent: _kPurple,
                          title: 'Meet the Team',
                        ),
                        SizedBox(height: 12),
                        _TeamCarousel(developers: _developers),
                        SizedBox(height: 26),
                      ],
                    ),
                  ),
                  const _ReachUsFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero header with curved bottom edge ────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderCurveClipper(),
      child: Container(
        height: 260,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.fromARGB(83, 46, 92, 171), _kAccent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55), width: 1.6),
                ),
                child: const Icon(Icons.front_hand_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 10),
              const Text(
                'ABOUT US',
                style: TextStyle(
                  color: Color.fromARGB(255, 227, 227, 233),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                        color: Color.fromARGB(211, 24, 11, 166),
                        offset: Offset(2, 3),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The people behind Talk with Hands',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12.5,
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

class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 34);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 34,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ── Floating stat chips ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: Icons.groups_2_rounded,
              value: '6',
              label: 'Developers',
              color: _kPurple,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.school_rounded,
              value: 'DLSP',
              label: 'Institution',
              color: _kAccent,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.sign_language_rounded,
              value: 'ASL/FSL',
              label: 'Focus',
              color: _kCoral,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _kDeepBlue,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8792A6),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mission card ─────────────────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  const _MissionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _kGold, size: 20),
              SizedBox(width: 8),
              Text(
                'Team Synergy',
                style: TextStyle(
                  color: _kTitleBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'We are a dedicated group of Information Technology students committed to creating an accessible learning app for Sign Language. Talk with Hands helps users learn alphabets, numbers, and basic words, and practice through interactive games, all in one friendly platform.',
            textAlign: TextAlign.justify,
            style: TextStyle(
              color: Color(0xFF4A5972),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section heading ──────────────────────────────────────────────────────
class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;

  const _SectionHeading({
    required this.icon,
    required this.accent,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _kDeepBlue,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Team carousel ─────────────────────────────────────────────────────────
class _TeamCarousel extends StatefulWidget {
  final List<_Developer> developers;

  const _TeamCarousel({required this.developers});

  @override
  State<_TeamCarousel> createState() => _TeamCarouselState();
}

class _TeamCarouselState extends State<_TeamCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: 0.44);
  final ValueNotifier<int> _page = ValueNotifier(0);

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: widget.developers.length,
            onPageChanged: (i) => _page.value = i,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _DeveloperCard(developer: widget.developers[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: _page,
          builder: (context, page, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.developers.length, (i) {
                final active = i == page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 10 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? _roleColor(widget.developers[i].role)
                        : const Color(0xFFD7DEE9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'System Analyst':
      return _kPurple;
    case 'System Tester':
      return _kCoral;
    case 'System Designer':
      return _kAccent;
    case 'Project Manager':
      return _kGold;
    case 'Technical Writer':
      return _kTitleBlue;
    case 'Programmer':
      return _kGreen;
    default:
      return _kAccent;
  }
}

class _DeveloperCard extends StatelessWidget {
  final _Developer developer;

  const _DeveloperCard({required this.developer});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(developer.role);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roleColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 148,
              width: double.infinity,
              color: roleColor.withValues(alpha: 0.12),
              child: Image.asset(
                developer.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: roleColor.withValues(alpha: 0.85),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 56),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    developer.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kDeepBlue,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      developer.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reach Us footer ──────────────────────────────────────────────────────
class _ReachUsFooter extends StatelessWidget {
  const _ReachUsFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(83, 46, 92, 171), _kAccent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dalubhasaan ng Lunsod ng San Pablo (DLSP)\nSan Pablo City, Laguna',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 18),
          const Text(
            'REACH US',
            style: TextStyle(
              color: Color.fromARGB(181, 255, 255, 255),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          const _FooterContactRow(
            icon: Icons.email_rounded,
            value: 'talkwithhands06@gmail.com',
          ),
          const SizedBox(height: 10),
          const _FooterContactRow(
            icon: Icons.phone_rounded,
            value: '0956 029 3552',
          ),
        ],
      ),
    );
  }
}

class _FooterContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _FooterContactRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Developer {
  final String name;
  final String role;
  final String imageAsset;

  const _Developer({
    required this.name,
    required this.role,
    required this.imageAsset,
  });
}