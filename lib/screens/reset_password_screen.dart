import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../ui/app_shell.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialToken;

  const ResetPasswordScreen({super.key, this.initialEmail, this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _newPassword = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
    _token.text = widget.initialToken ?? '';
    _newPassword.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  int _passwordScore(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    return score;
  }

  (double, String, Color) _passwordStrength(String password) {
    final score = _passwordScore(password);
    final percent = score / 4.0;
    if (score <= 1) return (percent, 'Weak', const Color(0xFFE74C3C));
    if (score == 2) return (percent, 'Fair', const Color(0xFFF39C12));
    if (score == 3) return (percent, 'Good', const Color(0xFFF1C40F));
    return (percent, 'Strong', const Color(0xFF2ECC71));
  }

  Future<void> _submit() async {
    if (_passwordScore(_newPassword.text) < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Use 8+ characters with uppercase, lowercase, and a number.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService().resetPassword(
        email: _email.text.trim(),
        token: _token.text.trim(),
        newPassword: _newPassword.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password reset successful. You can log in now.')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (strengthPct, strengthLabel, strengthColor) =
        _passwordStrength(_newPassword.text);

    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            AppTopBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 670),
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Paste the token from your email link, then set a new password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6D7583),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Email'),
                        _AppTextField(
                            controller: _email, hint: 'email@example.com'),
                        const SizedBox(height: 16),
                        const _FieldLabel('Reset Token'),
                        _AppTextField(controller: _token, hint: 'token'),
                        const SizedBox(height: 16),
                        const _FieldLabel('New Password'),
                        _AppTextField(
                          controller: _newPassword,
                          hint: 'Password',
                          obscureText: !_showPassword,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF969EAE),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: strengthPct,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFE9EEF6),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      strengthColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              strengthLabel,
                              style: TextStyle(
                                color: strengthColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '8+ chars, uppercase, lowercase, number',
                          style:
                              TextStyle(color: Color(0xFF6D7583), fontSize: 12),
                        ),
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
                              _loading ? 'Resetting...' : 'Reset Password',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
            ),
          ],
        ),
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
  final String hint;
  final bool obscureText;
  final Widget? suffix;

  const _AppTextField({
    required this.controller,
    required this.hint,
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
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA2B3)),
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