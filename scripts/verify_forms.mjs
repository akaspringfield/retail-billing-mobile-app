import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const people = readFileSync(join(root, 'lib/screens/people_screen.dart'), 'utf8');
const rbac = readFileSync(join(root, 'lib/screens/rbac_screens.dart'), 'utf8');
const service = readFileSync(join(root, 'lib/people_service.dart'), 'utf8');
const account = readFileSync(join(root, 'lib/screens/account_screen.dart'), 'utf8');

const requiredPeopleFields = [
  "'organization': organizationId",
  "'store': storeId",
  "'employment_status': employmentStatus",
  "'contact_person': contactPerson.text.trim()",
  "'customer_type': customerType",
  "'credit_limit': creditLimit.text.trim()",
  "'payment_terms': int.tryParse(paymentTerms.text.trim())",
];
const requiredChoices = [
  "'OWNER': 'Owner'",
  "'EMPLOYEE': 'Employee'",
  "'CONTRACT': 'Contract'",
  "'TEMPORARY': 'Temporary'",
];
const requiredRoleContract = [
  "String roleType = 'ORGANIZATION'",
  "'role_type': roleType",
  "'permissions': permissions.toList()",
  "'display_order': int.tryParse(displayOrder.text)",
];

const missing = [
  ...requiredPeopleFields.filter((value) => !people.includes(value)),
  ...requiredChoices.filter((value) => !people.includes(value)),
  ...requiredRoleContract.filter((value) => !rbac.includes(value)),
  ...(["'direct_phone': directPhone.text.trim()", "'language': language.text.trim()", "'timezone': timezone.text.trim()"]
    .filter((value) => !account.includes(value))),
  ...(['/stores/', '/customer/customers/', '/v1/supplier/', '/users/']
    .filter((value) => !service.includes(value))),
];

if (people.includes("'employment_status': 'ACTIVE'") ||
    rbac.includes("'role_type': 'CUSTOM'") || missing.length) {
  if (missing.length) console.error(`Missing form contract values:\n${missing.join('\n')}`);
  console.error('A deprecated invalid choice is still present in a create payload.');
  process.exit(1);
}

console.log('Mobile form contract verification passed.');
console.log('Checked customer, supplier, user, role, and user-role create flows.');
