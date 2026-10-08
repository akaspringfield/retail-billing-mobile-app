import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Roles', Icons.badge_outlined, '/roles'),
      ('Permissions', Icons.verified_user_outlined, '/permissions'),
      ('Role Permissions', Icons.rule_folder_outlined, '/role-permissions'),
      ('User Roles', Icons.assignment_ind_outlined, '/user-roles'),
    ];

    return AppShell(
      title: 'Settings',
      route: '/settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InfoCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.$2),
                  title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushReplacementNamed(item.$3),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
