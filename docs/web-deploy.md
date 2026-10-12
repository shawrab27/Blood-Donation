# BloodPulse Web & PWA Deployment Guide

## 1. Overview & Build Artifacts
BloodPulse is configured for Flutter Web release builds targeting standard web browsers and Progressive Web App (PWA) installation.

### Release Build Command
```bash
cd blood_pulse
flutter build web --release
```
The output directory is `blood_pulse/build/web/`.

### App Shell & Service Worker Architecture
- **Web App Manifest (`web/manifest.json`)**: Configured with BloodPulse branding, `#C30121` theme color, `#FDF3F3` background color, standalone display, and 192px/512px standard + maskable icons.
- **Service Worker (`web/bloodpulse_sw.js`)**: Caches only static app shell assets (HTML, scripts, icons, canvas).
- **API Guard**: The service worker explicitly **never** caches `/api/` endpoints or `cloudinary.com` assets. In-app data caching is strictly handled by application-level state (Riverpod providers + SharedPreferences).
- **Offline Fallback**: Offline fallback screen displays when network is unreachable.

---

## 2. Free Hosting Provider Plans & Setup

### Option A: Cloudflare Pages (Recommended for Global CDN & Zero-Cost Egress)
- **Tier**: Free plan (unlimited bandwidth, 500 builds/month, free custom domains & SSL).
- **Setup**:
  1. Link the repository to Cloudflare Pages.
  2. Build command: `flutter build web --release` (or upload pre-built `build/web` via GitHub Action).
  3. Output directory: `build/web`.
  4. Single Page Application (SPA) redirect configuration: Create `web/_routes.json` or rely on Cloudflare Pages default SPA routing rule.
  5. Allowed origin format: `https://<project-name>.pages.dev`.

### Option B: Netlify
- **Tier**: Free Starter plan (100 GB bandwidth/month, 300 build minutes/month).
- **Setup**:
  1. Add `web/_redirects` file with:
     ```
     /*    /index.html   200
     ```
  2. Deploy via CLI:
     ```bash
     netlify deploy --prod --dir=build/web
     ```
  3. Allowed origin format: `https://<site-name>.netlify.app`.

### Option C: Firebase Hosting
- **Tier**: Spark (Free, 10 GB storage, 360 MB/day transfer, custom domains with SSL).
- **Setup**:
  1. Add `firebase.json` in repository root or web directory:
     ```json
     {
       "hosting": {
         "public": "build/web",
         "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
         "rewrites": [
           { "source": "**", "destination": "/index.html" }
         ]
       }
     }
     ```
  2. Deploy:
     ```bash
     firebase deploy --only hosting
     ```
  3. Allowed origin format: `https://<project-id>.web.app`.

---

## 3. Backend CORS & Web Origin Security

The Django backend enforces strict CORS validation in `blood_pulse_backend/blood_pulse_backend/settings.py`.

### Environment Configuration
- **Variable**: `CORS_ALLOWED_ORIGINS` (comma-separated list of fully qualified origins).
- **Production Rules**:
  - `CORS_ALLOW_ALL_ORIGINS = False` (never wildcards in production).
  - Pre-registered regex patterns match `*.pages.dev`, `*.netlify.app`, `*.web.app`, `*.vercel.app`.
  - For custom production domains (e.g. `https://bloodpulse.app`), specify in Neon/Render/Fly environment:
    ```env
    CORS_ALLOWED_ORIGINS=https://bloodpulse.app,https://www.bloodpulse.app
    ```
- **JWT Authorization**: Transmitted via standard `Authorization: Bearer <token>` header, fully compliant with browser fetch policies.

---

## 4. Platform Feature Compatibility Matrix

| Feature | Mobile (Android / iOS) | Web (PWA) | Implementation Detail |
| :--- | :--- | :--- | :--- |
| **Photo Upload** | Native Camera & Gallery | Browser File Input (`<input type="file">`) | Handled via `image_picker_for_web` |
| **Location / GPS** | Native GPS Provider | Browser Geolocation API | Requires HTTPS origin; user permission prompt |
| **Emergency Posters** | Save directly to Gallery | Browser file download | `PosterRepository` refactored to `Uint8List` |
| **AI Blood Report OCR** | On-device Google ML Kit | Graceful fallback | Abstracted behind `OcrService`; web displays message |
| **Navigation** | Persistent Bottom Bar (5 tabs) | Responsive NavigationRail (>=840px) | `MainShellScreen` responsive breakpoints |
| **Data Persistence** | SharedPreferences / SQLite | IndexedDB / LocalStorage | `shared_preferences_web` abstraction |

---

## 5. NOT VERIFIED (Items Requiring Production Deployment & Owner Action)

The following items cannot be fully verified in local testing and require a live HTTPS deployment or owner credentials:
1. **PWA "Add to Home Screen" prompt in mobile Chrome/Safari**: Browsers enforce that PWA manifests and service workers be served over public HTTPS domains before triggering native install prompts.
2. **Cloudinary direct browser upload CORS**: Cloudinary upload preset must explicitly allow the deployed web origin in Cloudinary Management Console -> Settings -> Security -> Allowed origins.
3. **Google Sign-In Web OAuth Client ID**: `web/index.html` contains the client ID `404989190662-hojuqm8fie4lbrfuh62dspj8m9e1acgg.apps.googleusercontent.com`. The Google Cloud Console Authorized JavaScript Origins must have the exact deployed domain whitelisted.
4. **Geolocation API on HTTP**: Modern browsers block `navigator.geolocation` on insecure HTTP contexts (except `localhost`). Live location on web can only be tested on HTTPS.
