# 🟢 Grow Expense App

[![Web App Live](https://img.shields.io/badge/Live-Vercel--deployed-00d09c?style=for-the-badge&logo=vercel)](https://growexpense.vercel.app)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-05f2a8?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local--First-00d09c?style=for-the-badge)](https://growexpense.vercel.app)

Grow Expense is an ultra-premium, local-first personal finance tracker and accounting app. Designed with a sleek, glassmorphic, fintech-inspired dark mode UI, it keeps your financial data secure, private, and under your absolute control.

---

## 🌟 Core Philosophy: Privacy-First & Local-First

Unlike traditional accounting software that stores your sensitive financial logs on centralized servers, Grow Expense operates as a **secure offline enclave**. 
* **Zero Accounts Needed:** Open the app and start managing your budgets instantly. No logins, phone numbers, or emails required.
* **Local Sandbox Database:** All accounts, ledgers, and statement entries are saved inside your device's encrypted SQLite sandbox database.
* **Dual Cloud Integration:** If you wish to back up your ledger across multiple devices, you can choose to sync your data to the cloud using either a direct Supabase setup or a dedicated Node.js server.

---

## ✨ Features

### 📊 1. Batch Statement Imports (PDF & Excel)
* Import large bank statements directly from PhonePe, Google Pay, or netbanking (including password-protected PDFs).
* Automatically categorizes and parses merchants, dates, and amounts locally in seconds using a secure client-side parser.

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

The workspace is organized into three main parts:

```
├── frontend/             # Flutter mobile application codebase (Dart)
│   ├── lib/
│   │   ├── screens/      # Login, Navigation, Budgets, Invoices, & Dashboard views
│   │   ├── services/     # SQLite Database helper, Biometrics, Sync, & User Providers
│   │   ├── widgets/      # Shared custom components (custom toasts, etc.)
│   └── pubspec.yaml      # Flutter package configuration
│
├── backend/              # Optional Node.js Express server backend (PostgreSQL helper)
│   ├── routes/           # Auth, analytics, statement parsing, and invoice generation routes
│   ├── db.js             # PostgreSQL connection pool and migration scripts
│   └── server.js         # Server entry point with keep-alive cron scheduling
│
├── index.html            # Premium marketing landing page
├── index.css             # Glassmorphic dark styling & responsive query rules
├── index.js              # GPU-accelerated interactive spotlight & canvas animations
└── logo.png              # App branding asset
```

---

## 🖥️ Backend & Database Hosting Options

This project is built to support **two flexible backend architectures** depending on your deployment preferences:

```mermaid
graph TD
    A[Flutter Client App] -->|Option A: Direct Sync| B[Supabase Cloud]
    A -->|Option B: Express API| C[Render Node.js Server]
    C -->|Store Ledger| D[PostgreSQL Instance / Neon DB]
    
    subgraph Option A Details
        B --> B1[Supabase Auth - Email OTP & Google]
        B --> B2[Supabase Database - Tables]
        B --> B3[Supabase Storage - Invoices Bucket]
        B --> B4[Edge Functions - AI OCR & PDF]
    end
    
    subgraph Option B Details
        C --> C1[Custom JWT Auth]
        C --> C2[Self-ping Cron Job]
    end
```

---

### 🟢 Option A: Direct Client-to-Supabase Sync (Recommended & Current Active Production Flow)

In this mode, the Flutter app connects directly to **Supabase** via the native client library, eliminating the need for any intermediate custom server. 

#### 1. Authentication Flow
Supabase handles authentication securely using **Supabase GoTrue**:
* **Email Registration & Login:** The client registers with their email, prompting Supabase to send a secure, 6-digit One-Time Password (OTP) to verify the user. The session is managed securely on the device.
* **Google Sign-In:** Authenticates instantly using Google ID Tokens. The client obtains the token from Google Sign-In and passes it to Supabase's `signInWithIdToken` to establish a secure cloud session.
* **Session Security:** Auth tokens are saved locally in the app's encrypted preferences, and token refreshes are handled silently in the background.

#### 2. Cloud Components
* **Database Tables:** Saves your active data to Supabase tables (`expenses`, `budgets`, `payment_details`, `invoice_history`).
* **Storage Buckets:**
  * `invoices`: Stores generated monthly PDF statements inside folders partitioned by User ID (`/invoices/<user_id>/filename.pdf`).
  * `receipts`: Holds temporary images captured during smart OCR scanning.
* **Edge Functions:** 
  * `generate-invoice`: Uses `pdf-lib` inside a Deno environment to dynamically build print-ready expense PDF statements.
  * `scan-receipt`: Integrates with Gemini AI to scan receipt images and parse transaction details.

#### 3. Supabase Setup
Create a Supabase project and set up the variables in the client configuration inside `frontend/lib/services/supabase_service.dart`:
```dart
static const String supabaseUrl = 'https://your-project-ref.supabase.co';
static const String supabaseAnonKey = 'your-anon-key-here';
```

> [!IMPORTANT]
> Ensure Row Level Security (RLS) is enabled on all tables (`expenses`, `budgets`, `invoice_history`, `payment_details`). Set policies so that users can only read, write, or delete rows where `user_id = auth.uid()`.

---

### 🔵 Option B: Dedicated Express Server (Legacy/Optional - Hosted on Render)

If you prefer to route requests through a custom Node.js backend rather than integrating directly with a third-party cloud SDK, you can run the codebase inside the `backend/` directory.

#### 1. Authentication Flow
The custom server manages authentication using **JSON Web Tokens (JWT)**:
* **Custom Sign-Up / Log-In:** The endpoints in `backend/routes/authRoutes.js` accept user registration, hash passwords securely using `bcrypt`, and store credentials in a custom PostgreSQL table.
* **Token Issuance:** Upon successful authentication, the server generates a cryptographically signed JWT containing the user's ID.
* **Client Handshake:** The mobile client stores this token and attaches it to the `Authorization: Bearer <token>` header for all future network requests.

#### 2. Database Integration
The server uses `pg-pool` inside `backend/db.js` to run raw SQL queries on any PostgreSQL instance (such as a **Neon PostgreSQL** server or your own dedicated server).

#### 3. Render Hosting & Environment Variables
When deploying the `backend/` directory to **Render**, configure the environment inside a `.env` file (which is excluded from Git tracking via `.gitignore`):
```env
PORT=5000
DATABASE_URL=postgresql://neondb_owner:password@ep-host-pooler.aws.neon.tech/neondb?sslmode=require
JWT_SECRET=your_custom_jwt_secret_signing_key
SELF_URL=https://your-backend-app.onrender.com/
```

> [!TIP]
> The server includes an internal `node-cron` scheduler inside `backend/server.js` that automatically sends a HTTP ping to `SELF_URL` every 14 minutes. This prevents the server from entering sleep mode on Render's free tier, maintaining fast API response times.

---

## 🚀 Setup & Installation

### 1. Marketing Landing Page
The landing page runs on vanilla HTML5, CSS3, and modern Javascript. It is lightweight, responsive, and optimized for auto-deployments.
* **To run locally:** Simply open `index.html` in any browser, or serve it using a local HTTP server.
* **Deployment:** Push the root files to static hosting systems (Vercel, Netlify, or GitHub Pages).

### 2. Flutter Mobile Application (`frontend/`)
Ensure you have the Flutter SDK installed (`>= 3.0.0`) on your machine.

```bash
# Navigate to the mobile source folder
cd frontend

# Retrieve project dependencies
flutter pub get

# Run the app in development mode on a connected Android/iOS device
flutter run

# Compile split optimized Release APKs for Android distribution (Recommended, reduces size to ~24MB)
flutter build apk --release --split-per-abi

# Or compile the full "fat" Release APK (Contains all target architectures in one large 70MB file)
flutter build apk --release
```

The compiled release packages will be located at:
* **ARM 64-bit (Recommended for modern devices):** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~24.5 MB)
* **ARM 32-bit (For older devices):** `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (~23.0 MB)
* **Full FAT APK (All architectures):** `build/app/outputs/flutter-apk/app-release.apk` (~69.5 MB)

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
