# BloodPulse Real-Device & Phone Testing Runbook

Updated: 2026-10-12 (Task 10A)

## 1. Network & Host Configuration for Physical Android/iOS Phones
- **NEVER use `10.0.2.2`** when running or testing on physical Android devices. `10.0.2.2` is strictly an internal alias for the Android Virtual Device (AVD) emulator loopback.
- **Backend Host Binding**: Always bind the Django dev server to `0.0.0.0:8000`:
  ```bash
  python manage.py runserver 0.0.0.0:8000
  ```
- **Wi-Fi Subnet Matching**: Both the test phone and the host machine running Django must be connected to the exact same Wi-Fi router.
- **Host LAN IP**: Check host machine IP via `ipconfig` (Windows) or `ifconfig` (macOS/Linux), e.g., `192.168.0.105`.
- **Windows Firewall**: Allow incoming TCP traffic on port 8000 through Windows Defender Firewall.

## 2. Flutter Dart-Define Build Flags
Use the central `ApiConfig` flavor or custom base URL:

### Local Area Network Development (Phone on same Wi-Fi):
```bash
flutter run --dart-define=API_FLAVOR=lan-dev --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8000
```

### Staging / Rehearsal (Render backend):
```bash
flutter run --dart-define=API_FLAVOR=rehearsal
```

### Production:
```bash
flutter run --dart-define=API_FLAVOR=prod
```

## 3. Cleartext Traffic Policy
- Cleartext HTTP (`http://...`) is permitted **only in debug builds** via `android/app/src/debug/AndroidManifest.xml` (`android:usesCleartextTraffic="true"`).
- Production release builds enforce strict HTTPS.

## 4. Owner Verification Steps for Google Sign-In
To enable Google Sign-In on test devices:
1. Generate Android debug keystore SHA-1 & SHA-256:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
2. Register the SHA-1 and SHA-256 fingerprints in the Firebase Console under **Project Settings > Android App**.
3. Register the Web Client ID in Google Cloud Console OAuth 2.0 Credentials.
4. Download the refreshed `google-services.json` and replace `blood_pulse/android/app/google-services.json`.
