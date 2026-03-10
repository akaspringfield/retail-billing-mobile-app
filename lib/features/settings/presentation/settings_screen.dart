import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../auth/presentation/auth_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: ref.read(settingsControllerProvider).apiBaseUrl,
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveApiSettings(AppSettings settings) async {
    await ref.read(settingsControllerProvider.notifier).update(
          settings.copyWith(apiBaseUrl: _apiUrlController.text.trim()),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Menu'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xffc7a866),
                      child: Text('B', style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(
                      user?.organizationName ?? "BAPU'S OVEN",
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(user?.email ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xfffff7ed),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.schedule, color: Color(0xff92400e)),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'TRIAL ENDS IN 6 DAYS\nExpires on September 15, 2026',
                            style: TextStyle(
                              color: Color(0xff92400e),
                              fontWeight: FontWeight.w900,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _MenuGroup(
              children: [
                _MenuTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Regular Customers',
                  onTap: () => _showComingSoon(context),
                ),
                _MenuTile(
                  icon: Icons.chat_outlined,
                  title: 'Manage WhatsApp',
                  onTap: () => _showComingSoon(context),
                ),
                _MenuTile(
                  icon: Icons.rocket_launch_outlined,
                  title: 'WhatsApp Marketing',
                  onTap: () => _showComingSoon(context),
                ),
                _MenuTile(
                  icon: Icons.g_mobiledata,
                  title: 'Google Profile Manager',
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MenuGroup(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync_outlined),
                  title: const Text(
                    'Sync / Use on other devices',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: true,
                  onChanged: (_) {},
                ),
                _MenuTile(
                  icon: Icons.groups_outlined,
                  title: 'Manage Staff',
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 18),
              collapsedBackgroundColor: Colors.white,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppTheme.border),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppTheme.border),
              ),
              leading: const Icon(Icons.settings_outlined),
              title: const Text(
                'POS Settings',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (value) {
                    ref.read(settingsControllerProvider.notifier).update(
                          settings.copyWith(themeMode: value.first),
                        );
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: settings.defaultPrintAction,
                  decoration:
                      const InputDecoration(labelText: 'Default print action'),
                  items: const [
                    DropdownMenuItem(
                        value: 'preview', child: Text('PDF Preview')),
                    DropdownMenuItem(
                        value: 'system', child: Text('System Print')),
                    DropdownMenuItem(value: 'share', child: Text('Share PDF')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(settingsControllerProvider.notifier).update(
                          settings.copyWith(defaultPrintAction: value),
                        );
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: settings.receiptWidth,
                  decoration: const InputDecoration(labelText: 'Receipt width'),
                  items: const [
                    DropdownMenuItem(value: '58mm', child: Text('58mm')),
                    DropdownMenuItem(value: '80mm', child: Text('80mm')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(settingsControllerProvider.notifier).update(
                          settings.copyWith(receiptWidth: value),
                        );
                  },
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _apiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _saveApiSettings(settings),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save API Settings'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff1f1f29),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xffc7a866),
                  child: Icon(Icons.workspace_premium, color: Colors.white),
                ),
                title: const Text(
                  'Buy Premium Plan',
                  style: TextStyle(
                    color: Color(0xffffe8ad),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Color(0xffffe8ad)),
                onTap: () => _showComingSoon(context),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature coming soon.')),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: Icon(icon, color: const Color(0xff59719a)),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xff59719a)),
      onTap: onTap,
    );
  }
}
