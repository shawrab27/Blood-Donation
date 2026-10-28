---
name: bloodpulse-seo
description: Project-specific technical SEO, GEO, and search engine optimization rules for BloodPulse (Bangladesh nationwide blood donation platform).
version: 1.0.0
tags: [seo, technical-seo, geo, structured-data, flutter-web, bangladesh, ymyl]
---

# BloodPulse Project SEO & Search Optimization Guide

This skill governs all technical search engine optimization (SEO), Generative Engine Optimization (GEO / AI citation readiness), metadata, and structured data for the **BloodPulse** platform.

---

## 1. Product Context & Architecture

* **Product**: Nationwide voluntary blood donation and donor networking platform for Bangladesh, serving all 64 districts.
* **Languages**: Bangla (primary audience) and English (secondary).
* **Architecture**:
  * **Frontend**: Flutter Web (PWA / Web App) hosted on **Firebase Hosting** (`bloodpulse-283dc.web.app`), alongside native Android APK.
  * **Backend**: Django REST Framework hosted on **Render**.
  * **Brand**: `BloodPulse`
  * **AI Assistant**: `Pulse AI`
  * **Approved Official Slogan**: *"You give today, they live today"*. **Never** invent or use any alternate slogan.

---

## 2. Content Standards & YMYL (Your Money Your Life) Guardrails

Blood donation is strictly classified under Google's **YMYL (Your Money or Your Life)** quality guidelines. Strict accuracy and safety standards apply:

1. **No Medical Claims Without Sources**: Never state medical claims without citing recognized medical authorities (e.g., Directorate General of Health Services Bangladesh / DGHS, WHO, or Red Crescent).
2. **No Diagnosis or Triage**: Pulse AI and BloodPulse web content must never provide medical diagnosis, prescription advice, or clinical triage.
3. **No Blood Availability Guarantees**: Never promise or guarantee that blood units will be available or fulfilled within a specific timeframe; BloodPulse connects voluntary donors and facilitates emergency requests.
4. **Zero Tolerance for Commercialization**: Strict Bangladesh law and platform policy forbid buying or selling blood. Never use language implying payment, compensation, or financial transactions for blood donation.
5. **Mandatory Health Disclaimer**: Every public health guide, FAQ, or eligibility article must carry the plain disclaimer:
   > *"Disclaimer: BloodPulse is a voluntary donor connection platform and does not provide medical advice. For clinical emergencies or medical eligibility questions, consult a licensed healthcare professional."*

---

## 3. Language & Internationalization (`hreflang`)

* **Primary Audience**: Bangladesh (Bengali / `bn`).
* **Hreflang Rule**: Use `hreflang="bn"` and `hreflang="en"` **only** if separate, discrete URLs exist for both language variants. Do not declare alternating hreflang tags if both languages are rendered on a single dynamic SPA route without dedicated path/query separation.

---

## 4. Crawling & Indexation Policy

### Indexable Public Surfaces (Allowed)
Only public, static, and informational content may be indexed:
* Landing page (`/`)
* About (`/about`)
* How It Works (`/how-it-works`)
* Public FAQs (`/faq`)
* Privacy Policy (`/privacy`)
* Terms of Service (`/terms`)
* Contact (`/contact`)
* Public blood donation guides / donor education articles (if published)

### Non-Indexable Protected Surfaces (`noindex`, `robots.txt` Disallowed)
To protect user privacy and avoid duplicate SPA crawls, the following must **never** be indexed:
* `/login`, `/register`, `/auth/**`
* `/profile`, `/profile/**`
* `/requests`, `/request/**`, `/emergency/**`
* `/chat`, `/messages/**`
* `/tracking`, `/live/**`
* `/admin`, `/dashboard/**`
* All `/api/**` endpoints
* **Any view displaying real donor identities, phone numbers, location coordinates, or medical request records.**

---

## 5. Structured Data (Schema.org / JSON-LD)

### Allowed Schema Types:
1. **`Organization` / NGO style**: Platform identity, official logo, verified domain, social links, contact point.
2. **`WebSite`**: Platform name, URL, and internal search potential.
3. **`FAQPage`**: Common donor eligibility questions (e.g., 90-day interval, age/weight requirements) without personalized data.
4. **`BreadcrumbList`**: Clean navigation hierarchy for public pages.

### Forbidden in Schema:
* **Never** put real donor names, recipient names, live emergency requests, hospital slips, or donor phone numbers in JSON-LD.
* Do not fabricate schema ratings, review counts, or physical addresses unless verified and provided directly by the owner.

---

## 6. Target Keywords (Bangla + English)

Maintain organic, high-intent relevance across Bangladesh. **Do not keyword-stuff**:
* **English**: `blood donation Bangladesh`, `blood donor near me`, `emergency blood Dhaka`, `blood group donor by district`, `voluntary blood donors Bangladesh`.
* **Bangla**: `রক্তদাতা খুঁজুন`, `জরুরি রক্ত`, `বাংলাদেশে রক্তদান`, `স্বেচ্ছায় রক্তদাতা`, `রক্তের গ্রুপ ও দাতা`.

---

## 7. Flutter Web & Core Web Vitals (CWV)

Flutter Web compiles via CanvasKit / Skwasm or HTML renderer, which presents unique SEO challenges:
1. **Initial HTML Shell**: Web crawlers (Googlebot, Bingbot) initially fetch the raw `index.html` file before executing heavy WebAssembly or CanvasKit scripts. The `index.html` file must contain semantic meta tags, complete Open Graph tags, canonical URLs, and a structured `<noscript>` fallback.
2. **Initial Load Size**: CanvasKit `.wasm` and Flutter JavaScript bundles can take several seconds on mobile 3G/4G networks in Bangladesh. Keep the splash screen lightweight and ensure critical metadata is parsed without waiting for `.wasm` initialization.
3. **Glass/White Theme Consistency**: In `index.html`, keep `theme-color` aligned with the platform's surface/glass token (`#FFF8F7` / `#FDF3F3` or `#FFFFFF`), never bright red, preventing intrusive mobile browser header flashes.

---

## 8. Generative Engine Optimization (GEO & AI Citation Readiness)

To ensure AI search engines (Perplexity, Google Gemini, SearchGPT) accurately cite BloodPulse:
1. **Fact-First Consistency**: Ensure platform facts (64 districts, 90-day cooldown interval, free voluntary donations, emergency verification) are identical across `index.html`, FAQs, schema, and `llms.txt`.
2. **`llms.txt` Standard**: Maintain a clean, Markdown-formatted `/llms.txt` file summarizing BloodPulse's mission, factual parameters, approved slogan, and public endpoints.
3. **No Phantom Metrics**: Do not publish unverified counts of active donors or saved lives unless backed by database facts.

---

## 9. Pre-Change SEO Checklist

Before applying any SEO or metadata changes, the engineer must verify:
- [ ] No Flutter UI widgets, screens, colors, or buttons are modified.
- [ ] The app slogan is strictly *"You give today, they live today"* (no variations).
- [ ] No donor, requester, or user personal data (PII) is exposed in headers, schemas, sitemaps, or meta tags.
- [ ] All private routes (`/profile`, `/requests`, `/chat`, `/api/`) have `noindex` and `robots.txt` disallow rules.
- [ ] All JSON-LD structures are valid Schema.org syntax and contain only verified organization data.
- [ ] `firebase.json` remains valid JSON with headers that do not disrupt SPA client routing.
