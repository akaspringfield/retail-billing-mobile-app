import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../widgets/auth_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final controllers = <String, TextEditingController>{
    'organization_name': TextEditingController(),
    'organization_email': TextEditingController(),
    'organization_phone': TextEditingController(),
    'address': TextEditingController(),
    'city': TextEditingController(),
    'state': TextEditingController(),
    'country': TextEditingController(text: 'India'),
    'postal_code': TextEditingController(),
    'tax_registration_number': TextEditingController(),
    'store_name': TextEditingController(text: 'Head Office'),
    'first_name': TextEditingController(),
    'last_name': TextEditingController(),
    'email': TextEditingController(),
    'password': TextEditingController(),
    'confirm_password': TextEditingController(),
  };
  bool showPassword = false;
  bool loading = false;
  String error = '';

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String value(String key) => controllers[key]!.text.trim();

  Future<void> submit() async {
    final required = [
      'organization_name',
      'organization_email',
      'address',
      'state',
      'country',
      'first_name',
      'email',
      'password',
    ];

    if (required.any((key) => value(key).isEmpty)) {
      setState(() => error = 'Complete all required fields.');
      return;
    }
    if (controllers['password']!.text != controllers['confirm_password']!.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      await widget.auth.register({
        for (final entry in controllers.entries) entry.key: entry.value.text.trim(),
        'store_name': value('store_name').isEmpty ? 'Head Office' : value('store_name'),
      });
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
      title: 'Start billing smarter.',
      subtitle: 'Create your business, first store, and admin login.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sign Up', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: loading ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Text('Login'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FormMessage.error(error),
          _Section(
            title: 'Business',
            children: [
              _field('Business Name', 'organization_name'),
              _field('Business Email', 'organization_email', keyboard: TextInputType.emailAddress),
              _field('Phone', 'organization_phone', keyboard: TextInputType.phone),
              _field('Address', 'address'),
              _field('City', 'city'),
              _field('State', 'state'),
              _field('Country', 'country'),
              _field('Postal Code', 'postal_code'),
              _field('Tax Registration', 'tax_registration_number'),
            ],
          ),
          _Section(title: 'Store', children: [_field('Store Name', 'store_name')]),
          _Section(
            title: 'Admin User',
            children: [
              _field('First Name', 'first_name'),
              _field('Last Name', 'last_name'),
              _field('Login Email', 'email', keyboard: TextInputType.emailAddress),
              _field('Password', 'password', secret: true),
              _field('Confirm Password', 'confirm_password', secret: true),
            ],
          ),
          FilledButton(
            onPressed: loading ? null : submit,
            child: Text(loading ? 'Creating account...' : 'Create Account'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    String key, {
    bool secret = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return FieldLabel(
      label: label,
      child: TextField(
        controller: controllers[key],
        enabled: !loading,
        keyboardType: keyboard,
        obscureText: secret && !showPassword,
        decoration: InputDecoration(
          suffixIcon: secret
              ? IconButton(
                  onPressed: loading ? null : () => setState(() => showPassword = !showPassword),
                  icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                )
              : null,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
