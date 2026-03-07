import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const requiredFiles = [
  'lib/api_client.dart',
  'lib/auth_service.dart',
  'lib/dashboard_service.dart',
  'lib/billing_service.dart',
  'lib/people_service.dart',
  'lib/widgets/app_shell.dart',
  'lib/screens/dashboard_screen.dart',
  'lib/screens/pos_screen.dart',
  'lib/screens/account_screen.dart',
  'lib/screens/people_screen.dart',
  'lib/main.dart',
];

const requiredRoutes = [
  "'/dashboard'",
  "'/pos'",
  "'/account'",
  "'/customers'",
  "'/suppliers'",
  "'/users'",
];

const requiredEndpoints = [
  '/reports/dashboard/',
  '/billing/products/lookup/',
  '/billing/checkout/',
  '/auth/me/',
  '/auth/profile/',
  '/customer/customers/',
  '/v1/supplier/',
  '/users/',
];

const missing = requiredFiles.filter((file) => !existsSync(join(root, file)));
if (missing.length) {
  console.error(`Missing files:\n${missing.join('\n')}`);
  process.exit(1);
}

const allSource = requiredFiles.map((file) => readFileSync(join(root, file), 'utf8')).join('\n');
const missingRoutes = requiredRoutes.filter((route) => !allSource.includes(route));
const missingEndpoints = requiredEndpoints.filter((endpoint) => !allSource.includes(endpoint));

if (missingRoutes.length || missingEndpoints.length) {
  if (missingRoutes.length) console.error(`Missing routes:\n${missingRoutes.join('\n')}`);
  if (missingEndpoints.length) console.error(`Missing endpoints:\n${missingEndpoints.join('\n')}`);
  process.exit(1);
}

console.log('Phase 2 screen verification passed.');
console.log(`Checked ${requiredFiles.length} files, ${requiredRoutes.length} routes, and ${requiredEndpoints.length} backend endpoints.`);
