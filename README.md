# Retail Billing Mobile

Flutter Android app for the existing Retail Billing backend.

Phase 1 implements:

- Login
- Signup
- Forgot Password / Reset Password

Update `.env` before building for a real phone:

```text
API_BASE_URL=http://YOUR_PC_IP:8001/api
```

Use your computer LAN IP or a tunnel URL. `localhost` points to the phone itself.

Useful commands:

```powershell
cd D:\Project-Sandbox\retail-billing\mobile-app-flutter
flutter pub get
dart analyze .
flutter build apk --debug
```
