import 'package:flutter/material.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'billing_service.dart';
import 'catalog_service.dart';
import 'dashboard_service.dart';
import 'env.dart';
import 'people_service.dart';
import 'rbac_service.dart';
import 'screens/account_screen.dart';
import 'screens/catalog_screens.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/people_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/rbac_screens.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  final api = ApiClient();
  runApp(RetailBillingMobile(
    auth: AuthService(api),
    dashboard: DashboardService(api),
    billing: BillingService(api),
    people: PeopleService(api),
    catalog: CatalogService(api),
    rbac: RbacService(api),
  ));
}

class RetailBillingMobile extends StatelessWidget {
  const RetailBillingMobile({
    super.key,
    required this.auth,
    required this.dashboard,
    required this.billing,
    required this.people,
    required this.catalog,
    required this.rbac,
  });

  final AuthService auth;
  final DashboardService dashboard;
  final BillingService billing;
  final PeopleService people;
  final CatalogService catalog;
  final RbacService rbac;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retail Billing',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: '/login',
      routes: {
        '/login': (_) => LoginScreen(auth: auth),
        '/signup': (_) => SignupScreen(auth: auth),
        '/forgot-password': (_) => ForgotPasswordScreen(auth: auth),
        '/dashboard': (_) => DashboardScreen(service: dashboard),
        '/pos': (_) => PosScreen(service: billing),
        '/account': (_) => AccountScreen(auth: auth),
        '/customers': (_) => PeopleScreen(service: people, kind: PeopleKind.customers),
        '/suppliers': (_) => PeopleScreen(service: people, kind: PeopleKind.suppliers),
        '/users': (_) => PeopleScreen(service: people, kind: PeopleKind.users),
        '/products': (_) => CatalogScreen(service: catalog, kind: CatalogKind.products),
        '/stock-balances': (_) => CatalogScreen(service: catalog, kind: CatalogKind.stockBalances),
        '/inventory-ledger': (_) => CatalogScreen(service: catalog, kind: CatalogKind.inventoryLedger),
        '/settings': (_) => const SettingsScreen(),
        '/roles': (_) => RbacScreen(service: rbac, people: people, kind: RbacKind.roles),
        '/permissions': (_) => RbacScreen(service: rbac, people: people, kind: RbacKind.permissions),
        '/role-permissions': (_) => RbacScreen(service: rbac, people: people, kind: RbacKind.rolePermissions),
        '/user-roles': (_) => RbacScreen(service: rbac, people: people, kind: RbacKind.userRoles),
      },
    );
  }
}
