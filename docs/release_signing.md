# Android Release Keystore & Signing Guide

This document outlines the procedure for configuring Android release build signing for the BloodPulse application.

---

## 1. Security Principles
- **NEVER** commit keystore files (`*.jks`, `*.keystore`) to source control.
- **NEVER** commit `key.properties` to source control.
- Both `key.properties` and `*.jks`/`*.keystore` are strictly listed in `.gitignore` at both repository root and `blood_pulse/` project level.
- Always generate release keys offline on a secure machine. Keep backup copies in an encrypted password manager or secure vault.

---

## 2. Generate a Production Keystore

Run the following command using Java `keytool` (included in your JDK distribution or Android Studio JRE):

```bash
keytool -genkey -v -keystore <path-to-keystore>/upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

### Prompt Details:
- **Keystore & Key Password**: Choose strong, unique passwords.
- **Certificate Info**: Enter your organization name and location details when prompted.
- **Target File**: Save the resulting `.jks` file outside git or at `blood_pulse/android/app/upload-keystore.jks` (which is covered by `.gitignore`).

---

## 3. Configure `android/key.properties`

Create a file at `blood_pulse/android/key.properties` (or `android/key.properties` relative to the Flutter Android module):

```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

> **Note**: `storeFile` is resolved relative to `android/app/` by Gradle (`file(it)`). If the keystore is saved in `android/app/`, use `../app/upload-keystore.jks` or `upload-keystore.jks` depending on the working directory resolution.

---

## 4. Build Behavior in `build.gradle.kts`

- **Debug Builds**: Debug builds continue using the default debug keystore for development convenience.
- **Release Builds**:
  - If `android/key.properties` exists, Gradle reads the credentials and signs the release APK / App Bundle using `signingConfigs.release`.
  - If `android/key.properties` is **missing**, the release build immediately fails with a clear `GradleException` error informing the engineer to create `key.properties`. It will **never** silently fall back to debug signing.

---

## 5. Firebase SHA-1 / SHA-256 Registration

After generating the release keystore, extract the certificate fingerprint:

```bash
keytool -list -v -keystore <path-to-keystore>/upload-keystore.jks -alias upload
```

Copy the SHA-1 and SHA-256 fingerprints to the **Firebase Console** under **Project Settings > General > Your Apps > BloodPulse Android App > Add Fingerprint**.
This ensures Firebase Authentication (Phone, Google Sign-In) and SafetyNet/App Check continue functioning seamlessly on release builds.
