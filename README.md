# Grow Expense App

[![Web App Deployment](https://img.shields.io/badge/Live-Vercel--deployed-00d09c?style=flat-square)](https://growexpenseapp.vercel.app)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue?style=flat-square&color=05f2a8)]()
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local--First-00d09c?style=flat-square)]()

Grow Expense is an ultra-premium, local-first personal finance tracker and accounting app. Designed with a sleek, glassmorphic, fintech-inspired dark mode UI, it keeps your financial data secure, private, and under your absolute control.

---

## 🌟 Core Philosophy: Privacy-First & Local-First

Unlike traditional accounting software that stores your sensitive financial logs on centralized servers, Grow Expense operates as a **secure offline enclave**. 
* **Zero Accounts Needed:** Open the app and start managing your budgets instantly. No logins, phone numbers, or emails required.
* **Local Sandbox Database:** All accounts, ledgers, and statement entries are saved inside your device's encrypted sandbox database.
* **Optional Encrypted Sync:** If you wish to back up your ledger across multiple devices, you can toggle on private cloud sync securely using client-side encrypted authorization tokens.

---

## ✨ Features

### 📊 1. Batch Statement Imports (PDF & Excel)
* Import large bank statements directly from PhonePe, Google Pay, or netbanking (including password-protected PDFs).
* Automatically categorizes and parses merchants, dates, and amounts locally in seconds using a secure client-side parsing parser.

### 📷 2. Smart OCR Receipt Scanner
* Capture photos of receipts and invoices.
* The smart scanner automatically extracts item details, payment channels, and totals.

### 🔄 3. Month Rollover Clean-up
* Prevent database bloat and keep the mobile app running fast.
* At the end of each month, the app compiles the entire monthly expense log into a structured, print-ready PDF invoice directly inside your device's `Downloads` folder.
* Once saved, you can clear the local ledger to start the new month with a clean slate.

### 🔒 4. Enclave Biometric Lock
* Lock the app using Android's native fingerprint/passcode APIs.
* Authentications are verified in the device's secure enclave; biometric credentials never leave the operating system level.

### 📱 5. Tactile Haptic Feedback
* Immersive tactile response optimized for Android haptic engines.
* Micro-impact vibration on tab changes, standard impacts on button saves, and prominent double-vibration warnings on database deletions or authentication failures.

---

## 🛠️ Repository Structure

The workspace is organized into two main parts:

```
├── frontend/             # Flutter mobile application codebase (Dart)
│   ├── lib/
│   │   ├── screens/      # Login, Navigation, Budgets, Invoices, & Dashboard views
│   │   ├── services/     # SQLite Database helper, Biometrics, Sync, & User Providers
│   │   ├── widgets/      # Shared custom components (custom toasts, etc.)
│   └── pubspec.yaml      # Flutter package configuration
│
├── index.html            # Premium marketing landing page
├── index.css             # Glassmorphic dark styling & responsive query rules
├── index.js              # GPU-accelerated interactive spotlight & canvas animations
└── logo.png              # App branding asset
```

---

## 🚀 Setup & Installation

### 1. Marketing Landing Page
The landing page runs on vanilla HTML5, CSS3, and modern Javascript. It is lightweight, responsive, and optimized for auto-deployments.
* To run locally: Simply open `index.html` in any browser, or serve it using a local HTTP server.
* Deployment: Push the root files to static hosting systems (Vercel, Netlify, or GitHub Pages).

### 2. Flutter Mobile Application (`frontend/`)
To run or compile the Flutter application, ensure you have the Flutter SDK installed (`>= 3.0.0`).

```bash
# Navigate to the mobile source folder
cd frontend

# Retrieve project dependencies
flutter pub get

# Run the app in development mode on a connected Android/iOS device
flutter run

# Compile the final optimized Release APK for Android distribution
flutter build apk --release
```

The compiled release package will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🛡️ Security & Privacy Standards
* **Data Transmission:** No financial rows are transmitted to public clouds. All uploads for parsing are executed using secure APIs.
* **Credentials:** Third-party storage tokens are encrypted client-side.
* **Biometrics:** Authentications are handled entirely by Android's `BiometricPrompt` framework.

---

## 📞 Support & Contact
For inquiries, bug reports, or feature requests, contact support at:
* **Email:** [growexpensetrackerapp@gmail.com](mailto:growexpensetrackerapp@gmail.com)
* **Website:** [growexpenseapp.vercel.app](https://growexpenseapp.vercel.app)
