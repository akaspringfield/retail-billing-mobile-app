import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../session_store.dart';
import '../widgets/auth_shell.dart';
import '../widgets/backend_status_dot.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: SessionStore.rememberedEmail);
  final password = TextEditingController();
  bool rememberEmail = SessionStore.rememberedEmail.isNotEmpty;
  bool showPassword = false;
  bool loading = false;
  String error = '';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      await widget.auth.login(
        email: email.text.trim(),
        password: password.text,
        rememberMe: rememberEmail,
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (err) {
      setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back.',
      subtitle: 'Enter your credentials to access your retail terminal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BackendStatusDot(showLabel: true),
                  const SizedBox(width: 10),
                  Text('Sign in', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              TextButton(
                onPressed: loading ? null : () => Navigator.of(context).pushReplacementNamed('/signup'),
                child: const Text('Sign Up'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Good to see you. Let us get back to business.'),
          const SizedBox(height: 22),
          FormMessage.error(error),
          FieldLabel(
            label: 'Email',
            child: TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !loading,
              decoration: const InputDecoration(hintText: 'admin@example.com'),
            ),
          ),
          FieldLabel(
            label: 'Password',
            child: TextField(
              controller: password,
              obscureText: !showPassword,
              textInputAction: TextInputAction.done,
              enabled: !loading,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                hintText: 'Enter password',
                suffixIcon: IconButton(
                  onPressed: loading ? null : () => setState(() => showPassword = !showPassword),
                  icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: rememberEmail,
                onChanged: loading ? null : (value) => setState(() => rememberEmail = value ?? false),
              ),
              const Expanded(child: Text('Remember email')),
              TextButton(
                onPressed: loading ? null : () => Navigator.of(context).pushReplacementNamed('/forgot-password'),
                child: const Text('Forgot?'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: loading ? null : submit,
            child: Text(loading ? 'Signing in...' : 'Sign In'),
          ),
        ],
      ),
    );
  }
}
