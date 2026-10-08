import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../widgets/auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  final otp = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool otpSent = false;
  bool loading = false;
  String error = '';
  String message = '';

  @override
  void dispose() {
    email.dispose();
    otp.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> requestOtp() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Enter your email.');
      return;
    }
    setState(() {
      loading = true;
      error = '';
      message = '';
    });
    try {
      final result = await widget.auth.forgotPassword(email.text.trim());
      setState(() {
        message = result;
        otpSent = true;
      });
    } catch (err) {
      setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reset() async {
    if ([email, otp, password, confirmPassword].any((c) => c.text.trim().isEmpty)) {
      setState(() => error = 'Email, OTP, and new password are required.');
      return;
    }
    setState(() {
      loading = true;
      error = '';
      message = '';
    });
    try {
      final result = await widget.auth.resetPassword(
        email: email.text.trim(),
        otp: otp.text.trim(),
        password: password.text,
        confirmPassword: confirmPassword.text,
      );
      setState(() {
        message = result;
        password.clear();
        confirmPassword.clear();
      });
    } catch (err) {
      setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'A fresh start.',
      subtitle: 'Reset your account password using an OTP.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Forgot Password', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: loading ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Text('Login'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FormMessage.error(error),
          FormMessage.success(message),
          FieldLabel(
            label: 'Email',
            child: TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              enabled: !loading && !otpSent,
              decoration: const InputDecoration(hintText: 'user@example.com'),
            ),
          ),
          if (otpSent) ...[
            FieldLabel(
              label: 'OTP',
              child: TextField(
                controller: otp,
                enabled: !loading,
                decoration: const InputDecoration(hintText: 'Enter OTP'),
              ),
            ),
            FieldLabel(
              label: 'New Password',
              child: TextField(
                controller: password,
                obscureText: true,
                enabled: !loading,
                decoration: const InputDecoration(hintText: 'Enter new password'),
              ),
            ),
            FieldLabel(
              label: 'Confirm Password',
              child: TextField(
                controller: confirmPassword,
                obscureText: true,
                enabled: !loading,
                decoration: const InputDecoration(hintText: 'Confirm new password'),
              ),
            ),
          ],
          FilledButton(
            onPressed: loading ? null : (otpSent ? reset : requestOtp),
            child: Text(loading ? 'Please wait...' : otpSent ? 'Reset Password' : 'Send OTP'),
          ),
        ],
      ),
    );
  }
}
