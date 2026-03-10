# Retail Billing Mobile

Flutter mobile POS app for the existing Django Retail Billing backend.

## Implemented Scope

- Login with existing JWT API: `/api/auth/login/`
- Secure token storage and centralized refresh through `/api/auth/refresh/`
- Store, customer, payment method loading from existing APIs
- POS product lookup through `/api/billing/products/lookup/`
- Cart, customer selection, payment, and checkout through `/api/billing/checkout/`
- Latest invoice print/preview/share using backend PDF endpoint
- Settings for theme mode, API base URL, and print defaults

## API Notes

Default development API base URL is:

```text
http://10.0.2.2:8001/api
```

Use this for Android emulator when the backend is running on your PC. For a physical phone, use your PC LAN IP.

## Flutter SDK

Flutter is not installed/on PATH in this environment, so platform wrapper files and validation commands could not be run here.

After installing Flutter, run:

```powershell
cd D:\Project-Sandbox\retail-billing\mobile-app
flutter create . --platforms android,ios
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Run backend for Android emulator testing:

```powershell
cd D:\Project-Sandbox\retail-billing\backend
$env:DEBUG='True'
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8001
```
