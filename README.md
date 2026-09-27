# Ownership & License

This is a proprietary project owned by **Nasim Uddin Shawrab**. All rights reserved (2026).

This software and its associated source code, design assets, database schemas, and documentation are **not open-source**. The code is shared for academic and research evaluation purposes only (Software Development course, BAUST) unless otherwise explicitly licensed in writing.

For full terms, see the [LICENSE](blood_pulse/LICENSE) file.

---

# 🩸 BloodPulse — Emergency Blood Donation & Medical Matching Platform

> **Bangladesh's Premier Emergency Blood Matching & Donor Coordination Network**  
> Built with Clean Architecture, Flutter frontend, Django REST backend, and AI document verification.

---

## 🌟 Key Features

- **🚨 Emergency Request Broadcast**: Real-time geolocation-based urgent donor callouts.
- **🩸 120-Day Eligibility Engine**: Automatic cooldown counter adhering to WHO biological replenishment guidelines.
- **🔒 Admin & Trust Verification**: AI-powered prescription & medical document verification with PII redaction.
- **👥 Multi-Segment Communities**: Deep integration with national and campus volunteer organizations (*Badhan*, *Sandhani*, *Red Crescent*).
- **🏥 Health Hub Suite**: 7 dedicated modules including AI Report Analysis, Health Calculators (BMI/Blood Volume), Blood Compatibility Matrix, and Recovery Trackers.
- **💬 Real-Time Emergency Chat**: Direct requester-to-donor communication channel.

---

## 🏗️ Architecture & Tech Stack

```
Blood donation/
├── blood_pulse/           # Flutter Mobile / Web Client (Clean Architecture, Riverpod, GoRouter)
├── blood_pulse_backend/   # Python Django REST Framework API & Authentication Engine
├── stitch_bloodpulse_ui/  # Design System & UI Specifications
└── .agents/               # Architectural Rules & AI Pair-Programming Configurations
```

- **Frontend**: Flutter (Dart), Flutter Riverpod, GoRouter, OpenStreetMap.
- **Backend**: Python, Django REST Framework, SQLite / PostgreSQL.
- **Design System**: Georgia (Headings) & Inter (Body), Pill / Stadium capsules (`BorderRadius.circular(50)`), Custom Medical Design Tokens.

---

## 🚀 Getting Started

### 1. Flutter Frontend
```bash
cd blood_pulse
flutter pub get
flutter run
```

To run the full unit and widget test suite:
```bash
flutter test
```

### 2. Django Backend
```bash
cd blood_pulse_backend
python -m venv venv
# Activate virtual environment:
# Windows: venv\Scripts\activate
# Linux/macOS: source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

---

## 🛡️ License & Contributing
Licensed under the [MIT License](LICENSE).
Pull requests, bug reports, and feature proposals are welcome!

## Acknowledgements
- School data compiled from Bangladesh Open Data via KonSchool (github.com/maacpiash/KonSchool)
