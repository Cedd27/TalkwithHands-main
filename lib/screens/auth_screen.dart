import 'package:flutter/material.dart';

import '../ui/app_shell.dart';
import '../services/activity_time_service.dart';
import '../services/auth_service.dart';
import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import 'admin_analytics_screen.dart';
import 'reset_password_screen.dart';
import 'welcome_screen.dart';

enum AuthTab { login, register }

class AuthScreen extends StatefulWidget {
  final AuthTab initialTab;

  const AuthScreen({
    super.key,
    required this.initialTab,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _adminEmail = 'talkwithhands06@gmail.com';
  late AuthTab _tab;
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPassword = TextEditingController();
  final _registerConfirm = TextEditingController();
  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  bool _showRegisterConfirm = false;
  bool _loading = false;

  Widget _destinationForProfile(dynamic profile) {
    final email = profile?.email?.toString().trim().toLowerCase();
    if (email == _adminEmail) {
      return AdminAnalyticsScreen(userName: profile?.username ?? 'Admin');
    }
    return WelcomeScreen(userName: profile?.username ?? 'Student');
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _registerPassword.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPassword.dispose();
    _registerConfirm.dispose();
    super.dispose();
  }

  int _passwordScore(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    return score; // 0..4
  }

  bool _isStrongPassword(String password) => _passwordScore(password) == 4;

  Future<void> _submit() async {
    if (_loading) return;

    if (_tab == AuthTab.register &&
        _registerPassword.text != _registerConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (_tab == AuthTab.register &&
        !_isStrongPassword(_registerPassword.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Use atleast 8 characters with uppercase, lowercase, and a number.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = AuthService();
      final isLogin = _tab == AuthTab.login;

      final profile = isLogin
          ? await auth.login(
              email: _loginEmail.text.trim(),
              password: _loginPassword.text,
            )
          : await auth.signup(
              username: _registerName.text.trim().isEmpty
                  ? 'Student'
                  : _registerName.text.trim(),
              email: _registerEmail.text.trim(),
              password: _registerPassword.text,
            );
      await ActivityTimeService.instance.reloadForCurrentAccount();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _destinationForProfile(profile),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final profile = await AuthService().loginWithGoogle();
      await ActivityTimeService.instance.reloadForCurrentAccount();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _destinationForProfile(profile),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginFacebook() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final profile = await AuthService().loginWithFacebook();
      await ActivityTimeService.instance.reloadForCurrentAccount();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _destinationForProfile(profile),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _loginEmail.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot password'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'email@example.com'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await AuthService().requestPasswordReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('If the email exists, a reset link was sent.')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(initialEmail: email)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _tab == AuthTab.login;
    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/NEW BACKGROUND/new sign in log in.png',
          child: Column(
            children: [
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 670),
                      padding: const EdgeInsets.fromLTRB(18, 28, 20, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isLogin ? 'Login' : 'Create an Account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF0072A9),
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              shadows: [
                                Shadow(
                                  color: Color(0x44000000),
                                  offset: Offset(0, 6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sign Language Learning',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1E2430),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Learn, practice, and master sign language.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6D7583),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _SegmentTabs(
                            current: _tab,
                            onChanged: (tab) => setState(() => _tab = tab),
                          ),
                          const SizedBox(height: 18),
                          if (!isLogin) ...[
                            const _FieldLabel('User Name'),
                            _AppTextField(
                              controller: _registerName,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const _FieldLabel('Email'),
                          _AppTextField(
                            controller: isLogin ? _loginEmail : _registerEmail,
                          ),
                          const SizedBox(height: 16),
                          const _FieldLabel('Password'),
                          _AppTextField(
                            controller:
                                isLogin ? _loginPassword : _registerPassword,
                            obscureText: isLogin
                                ? !_showLoginPassword
                                : !_showRegisterPassword,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() {
                                  if (isLogin) {
                                    _showLoginPassword = !_showLoginPassword;
                                  } else {
                                    _showRegisterPassword =
                                        !_showRegisterPassword;
                                  }
                                });
                              },
                              icon: Icon(
                                (isLogin
                                        ? _showLoginPassword
                                        : _showRegisterPassword)
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF969EAE),
                              ),
                            ),
                          ),
                          if (!isLogin) ...[
                            const SizedBox(height: 10),
                            _PasswordRequirements(
                              password: _registerPassword.text,
                            ),
                          ],
                          if (!isLogin) ...[
                            const SizedBox(height: 16),
                            const _FieldLabel('Confirm Password'),
                            _AppTextField(
                              controller: _registerConfirm,
                              obscureText: !_showRegisterConfirm,
                              suffix: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showRegisterConfirm =
                                        !_showRegisterConfirm;
                                  });
                                },
                                icon: Icon(
                                  _showRegisterConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF969EAE),
                                ),
                              ),
                            ),
                          ],
                          if (isLogin) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: _loading ? null : _forgotPassword,
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: Color(0xFF32B7FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 58,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF31A8E8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: Text(
                                _loading
                                    ? 'Please wait...'
                                    : (isLogin ? 'Login' : 'Create Account'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (isLogin) ...[
                            const SizedBox(height: 20),
                            const _DividerOr(),
                            const SizedBox(height: 16),
                            _SocialButton(
                              icon: Icons.public,
                              label: 'Login with Google',
                              onTap: _loading ? null : _loginGoogle,
                            ),
                            const SizedBox(height: 12),
                            _SocialButton(
                              icon: Icons.facebook,
                              label: 'Login with Facebook',
                              onTap: _loading ? null : _loginFacebook,
                            ),
                          ],
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                color: Color(0xFF555E6E),
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                    text:
                                        'By continuing, you agree to Talk with Hands '),
                                TextSpan(
                                  text: '\n Terms of Service',
                                  style: TextStyle(
                                    color: Color(0xFF32B7FF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy \n',
                                  style: TextStyle(
                                    color: Color(0xFF32B7FF),
                                    fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  final AuthTab current;
  final ValueChanged<AuthTab> onChanged;

  const _SegmentTabs({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Login',
              selected: current == AuthTab.login,
              onTap: () => onChanged(AuthTab.login),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Register',
              selected: current == AuthTab.register,
              onTap: () => onChanged(AuthTab.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF2A303B),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8DDE8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  enabled ? const Color(0xFF2C3342) : const Color(0xFF9AA2B3),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? const Color(0xFF2C3342)
                      : const Color(0xFF9AA2B3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerOr extends StatelessWidget {
  const _DividerOr();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFD9DEE7))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFD9DEE7))),
      ],
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  final String password;

  const _PasswordRequirements({required this.password});

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your password must contain:',
            style: TextStyle(
              color: Color(0xFF2D3340),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _RequirementRow(label: 'At least 8 characters', met: hasLength),
          _RequirementRow(label: 'Upper case letters (A-Z)', met: hasUpper),
          _RequirementRow(label: 'Lower case letters (a-z)', met: hasLower),
          _RequirementRow(label: 'Numbers (0-9)', met: hasNumber),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final color = met ? const Color(0xFF2ECC71) : const Color(0xFF9AA2B3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: met ? const Color(0xFF2D3340) : const Color(0xFF9AA2B3),
              fontSize: 13,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2D3340),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;

  const _AppTextField({
    required this.controller,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE2EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF31A8E8), width: 1.5),
        ),
      ),
    );
  }
}
