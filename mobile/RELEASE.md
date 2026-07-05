# Wayfarer Sync — Release & Build Guide

This document covers everything needed to build, sign, and ship the Wayfarer Sync mobile app for both **Android** and **iOS**.

For general project setup and local development, see [README.md](README.md).

---

## 🌐 Environment Variables

Base URLs are injected at **compile time** via `--dart-define` (defined in [`lib/core/network/apiUrl.dart`](lib/core/network/apiUrl.dart)):

| Variable | Default (production) |
| :--- | :--- |
| `BASE_URL` | `https://wayfarer-sync-production.up.railway.app/api` |
| `WS_BASE_URL` | `wss://wayfarer-sync-production.up.railway.app` |

> **Production builds require no extra flags.** Omitting `--dart-define` bakes the Railway URLs into the binary automatically.

To override for a **local server**, pass both flags to any `flutter run` or `flutter build` command:

```bash
# Android Emulator
flutter run \
  --dart-define=BASE_URL=http://10.0.2.2:3000/api \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:3000

# iOS Simulator
flutter run \
  --dart-define=BASE_URL=http://localhost:3000/api \
  --dart-define=WS_BASE_URL=ws://localhost:3000

# Physical Device (replace with your machine's LAN IP)
flutter run \
  --dart-define=BASE_URL=http://192.168.1.50:3000/api \
  --dart-define=WS_BASE_URL=ws://192.168.1.50:3000
```

---

## 🤖 Android

### Prerequisites

- Android Studio with SDK tools installed
- Java 17+ on `$PATH` (bundled with Android Studio)
- A release keystore (see [Android Signing](#android-signing) below)

---

### APK — Direct install / sideloading

```bash
# Debug APK
flutter build apk --debug

# Release APK (single universal binary)
flutter build apk --release

# Release APK split by ABI — smaller per-device download (recommended)
flutter build apk --release --split-per-abi
```

**Output:** `build/app/outputs/flutter-apk/`

---

### AAB — Google Play Store submission

```bash
# Debug AAB
flutter build appbundle --debug

# Release AAB ← use this for Play Store uploads
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

> The Play Store **requires** an AAB. APKs are for sideloading only.

---

### Android Signing

Release APK/AAB builds must be signed with a keystore. Do this **once** per project.

#### Step 1 — Generate a keystore

```bash
keytool -genkey -v \
  -keystore android/app/wayfarer-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias wayfarer
```

#### Step 2 — Create `android/key.properties`

> ⚠️ This file is in `.gitignore`. **Never commit it.**

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=wayfarer
storeFile=wayfarer-release.jks
```

#### Step 3 — Reference the keystore in `android/app/build.gradle.kts`

Add a `signingConfigs` block and wire it to the `release` build type:

```kotlin
// android/app/build.gradle.kts

import java.util.Properties
import java.io.FileInputStream

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    load(FileInputStream(keyPropertiesFile))
}

android {
    // ...existing config...

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

#### Step 4 — Build the signed release

```bash
# Signed release APK
flutter build apk --release

# Signed release AAB (Play Store)
flutter build appbundle --release
```

📖 Full reference: [Flutter Android deployment guide](https://docs.flutter.dev/deployment/android)

---

## 🍎 iOS

### Prerequisites

- macOS with **Xcode** installed (latest stable recommended)
- An active **Apple Developer account**
- A valid **provisioning profile** and **distribution certificate**

---

### IPA — Device install / App Store submission

```bash
# Debug build (runs on a provisioned physical device)
flutter build ios --debug

# Release build — no codesign (for CI pipelines / manual Xcode archive)
flutter build ios --release --no-codesign

# Release build with automatic signing — generates a ready-to-upload .ipa
flutter build ipa --release
```

**Output:** `build/ios/ipa/*.ipa` or `build/ios/archive/*.xcarchive`

---

### iOS Signing Setup

1. Open `ios/Runner.xcworkspace` in **Xcode** (not `.xcodeproj`).
2. Select the **Runner** target → **Signing & Capabilities** tab.
3. Set your **Team** and a unique **Bundle Identifier** (e.g. `com.yourcompany.wayfarerSync`).
4. Enable **Automatically manage signing** — Xcode handles profiles automatically.

> For manual signing or enterprise distribution, create an explicit App ID and provisioning profile in the [Apple Developer portal](https://developer.apple.com/account).

---

### Uploading to App Store Connect

After `flutter build ipa --release`:

- **Xcode Organizer:** `Window → Organizer → Distribute App`
- **Transporter app:** [Download from Mac App Store](https://apps.apple.com/app/transporter/id1450874784)
- **CLI:** `xcrun altool --upload-app -f build/ios/ipa/*.ipa -u <apple-id> -p <app-specific-password>`

📖 Full reference: [Flutter iOS deployment guide](https://docs.flutter.dev/deployment/ios)

---

## 🔧 Useful Commands

```bash
# List connected devices & emulators
flutter devices

# Lint and static analysis
flutter analyze

# Run tests
flutter test

# Clean build cache (use after switching branches or updating deps)
flutter clean && flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Print full Flutter environment info
flutter doctor -v
```
