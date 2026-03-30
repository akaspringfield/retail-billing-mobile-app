import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const requiredFiles = [
  'lib/catalog_service.dart',
  'lib/rbac_service.dart',
  'lib/screens/catalog_screens.dart',
  'lib/screens/settings_screen.dart',
  'lib/screens/rbac_screens.dart',
  'lib/widgets/app_shell.dart',
  'lib/main.dart',
];

const requiredRoutes = [
  "'/products'",
  "'/stock-balances'",
  "'/inventory-ledger'",
  "'/settings'",
  "'/roles'",
  "'/permissions'",
  "'/role-permissions'",
  "'/user-roles'",
];

const requiredEndpoints = [
  '/v1/products/',
  '/v1/stocks/',
  '/inventory/transactions/',
  '/inventory/adjustment-requests/',
  '/approve/',
  '/reject/',
  '/rbac/roles/',
  '/rbac/permission-groups/',
  '/rbac/permissions/',
  '/rbac/user-roles/',
];

const missing = requiredFiles.filter((file) => !existsSync(join(root, file)));
if (missing.length) {
  console.error(`Missing files:\n${missing.join('\n')}`);
  process.exit(1);
}

const source = requiredFiles.map((file) => readFileSync(join(root, file), 'utf8')).join('\n');
const missingRoutes = requiredRoutes.filter((route) => !source.includes(route));
const missingEndpoints = requiredEndpoints.filter((endpoint) => !source.includes(endpoint));

const stockFields = [
  "'organization'",
  "'store'",
  "'product'",
  "'direction'",
  "'quantity'",
  "'unit_cost'",
  "'reason'",
  "'reference_number'",
  "'remarks'",
];
const missingStockFields = stockFields.filter((field) => !source.includes(field));

if (missingRoutes.length || missingEndpoints.length || missingStockFields.length) {
  if (missingRoutes.length) console.error(`Missing routes:\n${missingRoutes.join('\n')}`);
  if (missingEndpoints.length) console.error(`Missing endpoints:\n${missingEndpoints.join('\n')}`);
  if (missingStockFields.length) console.error(`Missing stock fields:\n${missingStockFields.join('\n')}`);
  process.exit(1);
}

console.log('Phase 3 catalog, stock, and settings verification passed.');
console.log(`Checked ${requiredFiles.length} files, ${requiredRoutes.length} routes, ${requiredEndpoints.length} backend endpoints, and ${stockFields.length} stock fields.`);
