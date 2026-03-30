import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const files = [
  'lib/main.dart',
  'lib/widgets/app_shell.dart',
  'lib/sales_service.dart',
  'lib/people_service.dart',
  'lib/catalog_service.dart',
  'lib/screens/sales_screen.dart',
  'lib/screens/products_screen.dart',
  'lib/screens/people_screen.dart',
  'lib/screens/stores_screen.dart',
];

const missingFiles = files.filter((file) => !existsSync(join(root, file)));
if (missingFiles.length) {
  console.error(`Missing commerce files:\n${missingFiles.join('\n')}`);
  process.exit(1);
}

const source = files.map((file) => readFileSync(join(root, file), 'utf8')).join('\n');
const routes = ["'/sales'", "'/products'", "'/customers'", "'/suppliers'", "'/stores'"];
const endpoints = [
  "'/sales/'",
  "'/v1/products/'",
  "'/customer/customers/'",
  "'/v1/supplier/'",
  "'/stores/'",
  "'/v1/masters/",
  "/cancel/",
];
const productFields = [
  "'sku'", "'barcode'", "'barcode_type'", "'category'", "'brand'", "'unit'", "'tax'",
  "'minimum_stock'", "'maximum_stock'", "'purchase_price'", "'selling_price'", "'mrp'",
  "'wholesale_price'", "'track_stock'", "'allow_negative_stock'",
];
const partyFields = [
  "'customer_type'", "'contact_person'", "'alternate_phone'", "'gst_number'", "'pan_number'",
  "'country'", "'state'", "'city'", "'credit_limit'", "'opening_balance'", "'payment_terms'",
];
const storeFields = [
  "'display_name'", "'store_type'", "'manager'", "'opening_date'", "'opening_time'",
  "'closing_time'", "'timezone'", "'currency'", "'receipt_header'", "'receipt_footer'",
  "'is_head_office'", "'is_default'",
];

const checks = [...routes, ...endpoints, ...productFields, ...partyFields, ...storeFields];
const missing = checks.filter((value) => !source.includes(value));
if (missing.length) {
  console.error(`Missing commerce contracts:\n${missing.join('\n')}`);
  process.exit(1);
}

console.log('Sales, product, customer, supplier, and store verification passed.');
console.log(`Checked ${files.length} files and ${checks.length} route, endpoint, and payload contracts.`);
