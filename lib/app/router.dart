import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/items/presentation/items_screen.dart';
import '../features/pos/presentation/pos_screen.dart';
import '../features/printing/presentation/latest_bill_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final location = state.uri.toString();
      final isLogin = location == '/login';

      if (auth.isRestoring) {
        return null;
      }
      if (!auth.isAuthenticated) {
        return isLogin ? null : '/login';
      }
      if (isLogin) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MobileShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/items',
            builder: (context, state) => const ItemsScreen(),
          ),
          GoRoute(
            path: '/items/add-stock',
            builder: (context, state) => const AddStockScreen(),
          ),
          GoRoute(
            path: '/bills',
            builder: (context, state) => const LatestBillScreen(),
          ),
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class MobileShell extends StatelessWidget {
  const MobileShell({required this.child, super.key});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/items')) return 1;
    if (location.startsWith('/pos') || location.startsWith('/bills')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (next) {
          switch (next) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/items');
              break;
            case 2:
              context.go('/pos');
              break;
            case 3:
              context.go('/reports');
              break;
            case 4:
              context.go('/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cookie_outlined),
            selectedIcon: Icon(Icons.cookie),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.flatware_outlined),
            selectedIcon: Icon(Icons.flatware),
            label: 'Items',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle),
            selectedIcon: Icon(Icons.add_circle),
            label: 'POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
