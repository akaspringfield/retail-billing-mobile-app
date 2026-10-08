import 'package:flutter/material.dart';

import '../session_store.dart';
import '../theme.dart';
import 'backend_status_dot.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.route,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String route;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BackendStatusDot(),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        actions: actions,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Retail Billing',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        SessionStore.current?.organizationName ?? 'Mobile workspace',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _NavTile(route: route, target: '/dashboard', icon: Icons.dashboard_outlined, label: 'Dashboard'),
              _NavTile(route: route, target: '/pos', icon: Icons.point_of_sale_outlined, label: 'POS'),
              _NavTile(route: route, target: '/account', icon: Icons.person_outline, label: 'My Account'),
              _NavTile(route: route, target: '/customers', icon: Icons.groups_outlined, label: 'Customers'),
              _NavTile(route: route, target: '/suppliers', icon: Icons.local_shipping_outlined, label: 'Suppliers'),
              _NavTile(route: route, target: '/users', icon: Icons.manage_accounts_outlined, label: 'Users'),
              const Divider(height: 1),
              _NavTile(route: route, target: '/products', icon: Icons.inventory_2_outlined, label: 'Products'),
              _NavTile(route: route, target: '/stock-balances', icon: Icons.warehouse_outlined, label: 'Stock Balances'),
              _NavTile(route: route, target: '/inventory-ledger', icon: Icons.receipt_long_outlined, label: 'Inventory Ledger'),
              const Divider(height: 1),
              _NavTile(route: route, target: '/settings', icon: Icons.settings_outlined, label: 'Settings'),
              _NavTile(route: route, target: '/roles', icon: Icons.badge_outlined, label: 'Roles'),
              _NavTile(route: route, target: '/permissions', icon: Icons.verified_user_outlined, label: 'Permissions'),
              _NavTile(route: route, target: '/role-permissions', icon: Icons.rule_folder_outlined, label: 'Role Permissions'),
              _NavTile(route: route, target: '/user-roles', icon: Icons.assignment_ind_outlined, label: 'User Roles'),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  SessionStore.clear();
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          notificationPredicate: (_) => false,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.route,
    required this.target,
    required this.icon,
    required this.label,
  });

  final String route;
  final String target;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = route == target;
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.page,
      leading: Icon(icon, color: selected ? AppColors.primary : null),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
      onTap: () {
        Navigator.of(context).pop();
        if (!selected) Navigator.of(context).pushReplacementNamed(target);
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }
}
