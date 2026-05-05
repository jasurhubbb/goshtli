# Shipping the mobile app

The Flutter codebase is ready for both iOS and Android. The launcher icon will appear in the user's language (Meat Marketplace / Go'sht Bozori / Мясной рынок) automatically.

What's still needed to actually ship: the platform toolchains + (for iOS) a paid developer account.

---

## Path A — Android (recommended first)

### 1. Install Android Studio
Download from <https://developer.android.com/studio>. ~5 GB.

After installing:
```bash
flutter doctor          # walks you through any remaining setup
flutter doctor --android-licenses     # accept SDK licenses (once)
```

### 2. Create a release signing key (one time)
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Save the password somewhere safe — losing it means losing the ability to update the app on Play Store.

### 3. Wire the keystore into Gradle
Create `mobile/android/key.properties` (already in `.gitignore`):
```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/Users/you/upload-keystore.jks
```

Then update `mobile/android/app/build.gradle.kts` — replace the `signingConfig = signingConfigs.getByName("debug")` line in the `release` block with:
```kotlin
signingConfigs {
    create("release") {
        val keyProps = java.util.Properties()
        val keyFile = rootProject.file("key.properties")
        if (keyFile.exists()) keyProps.load(java.io.FileInputStream(keyFile))
        keyAlias = keyProps["keyAlias"] as String?
        keyPassword = keyProps["keyPassword"] as String?
        storeFile = keyProps["storeFile"]?.let { file(it as String) }
        storePassword = keyProps["storePassword"] as String?
    }
}
buildTypes {
    release { signingConfig = signingConfigs.getByName("release") }
}
```

### 4. Build
```bash
cd mobile

# APK — sideload to your own phone for testing (drag onto device, enable "Install unknown apps")
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
# Output: build/app/outputs/flutter-apk/app-release.apk (~25 MB)

# AAB — what Google Play actually wants
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
# Output: build/app/outputs/bundle/release/app-release.aab (~30 MB)
```

### 5. Distribute
| Channel | Cost | Steps |
|---|---|---|
| **Sideload** | Free | Email APK to yourself, open on phone, install |
| **Internal testing** (Play Console) | Free (with $25 dev account) | Upload AAB → Internal testing track → invite up to 100 testers via email |
| **Open testing** | Same | Same flow, but anyone with the link can install |
| **Production** (full Play Store) | Same | Submit for review (1–7 days) |

Pay $25 once at <https://play.google.com/console>. After that, all releases are free.

---

## Path B — iOS

### 1. Install Xcode
From the Mac App Store. ~15 GB. Will take a while.

After installing:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods                # plugin manager iOS uses
flutter doctor                             # should now show ✓ for Xcode
```

### 2. Apple Developer Program ($99/year)
Sign up at <https://developer.apple.com/programs/>. Approval takes 24–48 hours and may need a phone call.

### 3. First build to test
```bash
cd mobile/ios
pod install                                # one-time
cd ..
open ios/Runner.xcworkspace               # opens Xcode
```
In Xcode:
- Click the Runner project → Signing & Capabilities → pick your team (the one tied to your dev account)
- Connect your iPhone via USB → trust this computer → select it as the run target → ▶
- App installs and runs on your phone

### 4. TestFlight (beta)
- In Xcode: Product → Archive
- Window → Organizer → select archive → Distribute App → App Store Connect → Upload
- Go to <https://appstoreconnect.apple.com> → My Apps → TestFlight
- Add internal testers (your team, up to 100) — instant
- Add external testers (up to 10,000) — needs a 24h beta-review

### 5. App Store
Same flow as TestFlight, but submit for full App Store review (1–3 days).

---

## What both paths share

These already work for both platforms:

- ✅ App displays in 3 languages (en/uz/ru)
- ✅ Launcher icon name follows device locale
- ✅ Bundle identifier `com.meatmarketplace.meat_marketplace` set
- ✅ Version `0.1.0+1` — bump in `mobile/pubspec.yaml` for each release
- ✅ INTERNET permission declared in Android manifest
- ✅ HTTPS only — production API uses TLS, no insecure-cleartext exemptions needed

---

## What you still need to provide

Whichever platform you ship first, these are app-store requirements you'll have to produce yourself (no code we can write helps):

| Asset | Specs | Where |
|---|---|---|
| **App icon** | 1024×1024 PNG (no transparency, no rounded corners) | `mobile/android/app/src/main/res/mipmap-*` and `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/` — currently using Flutter's default icon |
| **Screenshots** | iOS: 6.7" / 6.5" / 5.5". Android: at least one phone screenshot. | App Store Connect / Play Console — can be taken from your dev device |
| **App description** | Short (80 chars) + long (4000 chars) | Same |
| **Privacy policy URL** | Hosted page, simple boilerplate is fine | Need to be reachable at a public URL |
| **Demo account** (Apple only) | Email + password reviewers can sign in with | We have `olim@buy.test` / `StrongPass123!` already — give them this |

Use `flutter_launcher_icons` package later to mass-generate icon assets from one 1024×1024 source.

---

## Cheapest realistic timeline

| Day | What |
|---|---|
| 1 | Install Android Studio + accept SDK licenses |
| 1 | Generate signing key, build APK, sideload to your own phone — test the flow |
| 2 | Pay $25 for Play Console, upload to Internal testing, invite 5 friends |
| 3+ | Iterate based on feedback |
| Later | When ready, Apple Developer + Xcode for iOS |

Total cost to validate with real users: **$25** (Android only, internal testers).
