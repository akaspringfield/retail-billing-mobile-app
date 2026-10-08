import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const requiredFiles = [
  ".env",
  "pubspec.yaml",
  "lib/main.dart",
  "lib/api_client.dart",
  "lib/auth_service.dart",
  "lib/screens/login_screen.dart",
  "lib/screens/signup_screen.dart",
  "lib/screens/forgot_password_screen.dart",
  "android/settings.gradle.kts",
  "android/app/build.gradle.kts",
  "android/app/src/main/AndroidManifest.xml",
  "android/app/src/main/java/com/retailbilling/mobile/MainActivity.java",
];

const missing = requiredFiles.filter((file) => !fs.existsSync(path.join(root, file)));
const env = fs.existsSync(path.join(root, ".env"))
  ? fs.readFileSync(path.join(root, ".env"), "utf8")
  : "";
const main = fs.existsSync(path.join(root, "lib/main.dart"))
  ? fs.readFileSync(path.join(root, "lib/main.dart"), "utf8")
  : "";
const api = fs.existsSync(path.join(root, "lib/auth_service.dart"))
  ? fs.readFileSync(path.join(root, "lib/auth_service.dart"), "utf8")
  : "";

const missingRoutes = ["/login", "/signup", "/forgot-password"].filter(
  (route) => !main.includes(`'${route}'`),
);
const missingEndpoints = ["/auth/login/", "/auth/register/", "/auth/forgot-password/"].filter(
  (endpoint) => !api.includes(endpoint),
);

if (missing.length || !/^API_BASE_URL=.+/m.test(env) || missingRoutes.length || missingEndpoints.length) {
  console.error("Phase 1 auth verification failed.");
  for (const file of missing) console.error(`Missing file: ${file}`);
  if (!/^API_BASE_URL=.+/m.test(env)) console.error(".env must contain API_BASE_URL");
  for (const route of missingRoutes) console.error(`Missing route: ${route}`);
  for (const endpoint of missingEndpoints) console.error(`Missing endpoint: ${endpoint}`);
  process.exit(1);
}

console.log("Phase 1 auth verification passed.");
console.log(`Checked ${requiredFiles.length} files, 3 routes, and 3 backend endpoints.`);
