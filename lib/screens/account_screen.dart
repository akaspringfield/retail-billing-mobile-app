import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../data_utils.dart';
import '../widgets/app_shell.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final first = TextEditingController();
  final last = TextEditingController();
  final display = TextEditingController();
  final mobile = TextEditingController();
  String email = '';
  String message = '';
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final user = await widget.auth.currentUser();
      first.text = textValue(user, ['first_name'], fallback: '');
      last.text = textValue(user, ['last_name'], fallback: '');
      display.text = textValue(user, ['display_name'], fallback: '');
      mobile.text = textValue(user, ['mobile_number'], fallback: '');
      email = textValue(user, ['email'], fallback: '');
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      message = '';
    });
    try {
      await widget.auth.updateProfile({
        'first_name': first.text.trim(),
        'last_name': last.text.trim(),
        'display_name': display.text.trim(),
        'mobile_number': mobile.text.trim(),
      });
      message = 'Profile updated.';
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'My Account',
      route: '/account',
      child: loading
          ? const LoadingBlock()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(email, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      TextField(controller: first, decoration: const InputDecoration(labelText: 'First Name')),
                      const SizedBox(height: 10),
                      TextField(controller: last, decoration: const InputDecoration(labelText: 'Last Name')),
                      const SizedBox(height: 10),
                      TextField(controller: display, decoration: const InputDecoration(labelText: 'Display Name')),
                      const SizedBox(height: 10),
                      TextField(controller: mobile, decoration: const InputDecoration(labelText: 'Mobile Number'), keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save Profile')),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(message),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
