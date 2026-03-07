import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const service = readFileSync(join(root, 'lib/billing_service.dart'), 'utf8');
const screen = readFileSync(join(root, 'lib/screens/pos_screen.dart'), 'utf8');
const people = readFileSync(join(root, 'lib/screens/people_screen.dart'), 'utf8');

const requiredServiceCalls = [
  "'/stores/'",
  "'/customer/customers/'",
  "'/v1/products/'",
  "'/billing/products/lookup/'",
  "'/v1/masters/payment-methods/'",
  "'/billing/checkout/'",
  "'/billing/invoices/",
];

const requiredFeatures = [
  'Quick Bill',
  'Held Bills',
  'Cart Discount %',
  'Round Off',
  'Split Payment',
  'Complete Sale',
  'Receipt Preview',
  'WhatsApp',
  'Receipt / Print',
];

const missingCalls = requiredServiceCalls.filter((value) => !service.includes(value));
const missingFeatures = requiredFeatures.filter((value) => !screen.includes(value));

if (!screen.includes('Icons.print_outlined') ||
    !screen.includes("label: const Text('Print')")) {
  console.error('Checkout success dialog is missing the direct Print action.');
  process.exit(1);
}

if (screen.includes("labelText: 'Store ID'") || screen.includes("labelText: 'Customer ID")) {
  console.error('Manual Store ID or Customer ID fields are still present.');
  process.exit(1);
}

if (!people.includes("String customerType = 'INDIVIDUAL'") ||
    !people.includes("'customer_type': customerType")) {
  console.error('Customer creation does not use a valid backend customer type.');
  process.exit(1);
}

if (missingCalls.length || missingFeatures.length) {
  if (missingCalls.length) console.error(`Missing POS API calls:\n${missingCalls.join('\n')}`);
  if (missingFeatures.length) console.error(`Missing POS features:\n${missingFeatures.join('\n')}`);
  process.exit(1);
}

console.log('Mobile POS verification passed.');
console.log(`Checked ${requiredServiceCalls.length} API integrations and ${requiredFeatures.length} POS features.`);
