# Retail Billing Mobile App

Flutter Android mobile app for the existing Retail Billing web/backend project.

This app is built to reuse the same backend APIs used by the React web app in:

```text
D:\Project-Sandbox\retail-billing\frontend
D:\Project-Sandbox\retail-billing\backend
```

## Current Screens

Auth / Public:

- Login
- Signup
- Forgot Password / Reset Password

Main App:

- Dashboard
- POS / Point of Sale
- My Account
- Customers
- Suppliers
- Users

Stock / Catalog:

- Products
- Stock Balances
- Inventory Ledger / Stock Transactions

Settings / RBAC:

- Settings Home
- Roles
- Permissions
- Role Permissions
- User Roles

## File Structure

```text
mobile-app-flutter/
  .env
  pubspec.yaml
  README.md
  android/
    app/
    build.gradle.kts
    settings.gradle.kts
  lib/
    main.dart
    env.dart
    api_client.dart
    session_store.dart
    theme.dart
    data_utils.dart
    auth_service.dart
    dashboard_service.dart
    billing_service.dart
    people_service.dart
    catalog_service.dart
    rbac_service.dart
    screens/
      login_screen.dart
      signup_screen.dart
      forgot_password_screen.dart
      dashboard_screen.dart
      pos_screen.dart
      account_screen.dart
      people_screen.dart
      catalog_screens.dart
      settings_screen.dart
      rbac_screens.dart
    widgets/
      auth_shell.dart
      app_shell.dart
      backend_status_dot.dart
  scripts/
    verify_phase1.mjs
    verify_phase2.mjs
    verify_phase3.mjs
```

## Backend API Configuration

The mobile app reads the backend base URL from:

```text
mobile-app-flutter\.env
```

Example for phone on same Wi-Fi as your PC:

```env
API_BASE_URL=http://192.168.1.25:8001/api
```

Example for ngrok:

```env
API_BASE_URL=https://your-ngrok-domain.ngrok-free.dev/api
```

Do not use `localhost` or `127.0.0.1` for a real phone. On a phone, `localhost` means the phone itself, not your PC.

For ngrok, do not add `/8001` in the path. This is wrong:

```env
API_BASE_URL=https://your-ngrok-domain.ngrok-free.dev/8001/api
```

Use this instead:

```env
API_BASE_URL=https://your-ngrok-domain.ngrok-free.dev/api
```

After changing `.env`, rebuild the APK. Flutter bundles `.env` into the APK at build time.

## Backend Setup

Run the backend so it is reachable from phone/network:

```powershell
cd D:\Project-Sandbox\retail-billing\backend
python manage.py runserver 0.0.0.0:8001
```

If using LAN IP, make sure:

- Phone and PC are on the same Wi-Fi.
- Windows Firewall allows Python/Django on port `8001`.
- `.env` uses your PC IP, not `localhost`.

If using ngrok, tunnel the backend port:

```powershell
ngrok http 8001
```

Then use the generated ngrok HTTPS URL with `/api` at the end.

## Mobile App Workflow

1. App starts at Login.
2. `lib/env.dart` loads `API_BASE_URL` from `.env`.
3. `lib/api_client.dart` sends requests to the backend.
4. Login/Signup saves tokens in `SessionStore`.
5. Protected screens send:

```http
Authorization: Bearer <access_token>
```

6. The green/red backend dot checks whether the configured backend URL is reachable.

Backend dot:

- Green: backend reachable.
- Red: backend not reachable.
- Gray: checking.
- Tap the dot to manually re-check.

## API Mapping

Auth:

- `POST /auth/login/`
- `POST /auth/register/`
- `POST /auth/forgot-password/`
- `POST /auth/reset-password/`
- `GET /auth/me/`
- `PATCH /auth/profile/`

Dashboard:

- `GET /reports/dashboard/`

POS:

- `GET /billing/products/lookup/`
- `GET /v1/masters/payment-methods/`
- `POST /billing/checkout/`

Parties:

- `GET/POST /customer/customers/`
- `GET/POST /v1/supplier/`
- `GET/POST /users/`

Catalog / Stock:

- `GET /v1/products/`
- `GET /v1/stocks/`
- `GET /inventory/transactions/`

Settings / RBAC:

- `GET/POST /rbac/roles/`
- `GET /rbac/permission-groups/`
- `GET /rbac/permissions/`
- `GET/POST/DELETE /rbac/roles/{roleUuid}/permissions/`
- `GET /rbac/user-roles/`
- `POST /rbac/user-roles/assign/`
- `DELETE /rbac/user-roles/{uuid}/`

## Install Dependencies

Use the Flutter SDK installed at:

```text
C:\flutter
```

Run:

```powershell
cd D:\Project-Sandbox\retail-billing\mobile-app-flutter
C:\flutter\bin\flutter.bat pub get
```

## Verify Code

Run the verification scripts:

```powershell
cd D:\Project-Sandbox\retail-billing\mobile-app-flutter
node scripts\verify_phase1.mjs
node scripts\verify_phase2.mjs
node scripts\verify_phase3.mjs
```

Run Dart analysis:

```powershell
C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze .
```

Format code:

```powershell
C:\flutter\bin\cache\dart-sdk\bin\dart.exe format .
```

## Build APK

Debug APK:

```powershell
cd D:\Project-Sandbox\retail-billing\mobile-app-flutter
C:\flutter\bin\flutter.bat clean
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat build apk --debug
```

Output:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

Release APK:

```powershell
cd D:\Project-Sandbox\retail-billing\mobile-app-flutter
C:\flutter\bin\flutter.bat build apk --release
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

For release signing, configure Android signing keys before distributing outside testing.

## Install On Phone

1. Build the APK.
2. Uninstall old app from phone if `.env` changed.
3. Copy/install:

```text
mobile-app-flutter\build\app\outputs\flutter-apk\app-debug.apk
```

Uninstalling the old app avoids confusion with older bundled `.env` values.

## Android SDK Notes

APK build requires Android SDK and platform tools. Check:

```powershell
C:\flutter\bin\flutter.bat doctor
```

If `flutter doctor` reports Android toolchain errors, fix those first. The app can pass Dart checks but still fail APK build if Android SDK is missing.

## Known Limitations

- Product screen is currently read/search focused. Full create/edit product needs master-data selection for organization, store, category, unit, brand, tax, and image upload.
- POS currently asks for Store ID manually. Later this should become a store selector using organization/store APIs.
- Tokens are stored in memory only. For production, use secure local storage.
- Runtime API testing on a physical phone depends on backend URL, network, firewall, and Android SDK/APK setup.

## Troubleshooting

Large Django HTML error on login:

- Usually means `API_BASE_URL` is wrong.
- Check `.env`.
- Rebuild APK after changing `.env`.
- Uninstall old APK from phone before installing the new one.

Backend dot green but login fails:

- Backend host is reachable, but the API path or credentials may be wrong.
- Confirm the app is calling `/api/auth/login/`.
- For ngrok, use `https://your-domain.ngrok-free.dev/api`.

Backend dot red:

- Backend is not reachable from phone.
- Check backend is running.
- Check phone and PC network.
- Check firewall.
- Check ngrok tunnel is active.
