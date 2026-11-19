# APK / App Bundle Build Guide

## Prerequisites

| Tool | Version |
|---|---|
| Flutter | 3.50.0 stable (`flutter --version`) |
| JDK | 17 or 21 |
| Android SDK | Platform 37, Build-Tools 36+, NDK (installed automatically by Gradle) |
| Network | Google Maven, Maven Central, Gradle Plugin Portal, **jitpack.io** |

Check the setup:

```bash
flutter doctor -v
```

## 1. Configure

1. `android/gradle.properties` → set `nexus.webHost=your-real-domain.com`.
2. Optional: `android/app/google-services.json` (Firebase, see README §5).
3. Optional: `android/key.properties` (release signing, see `SIGNING.md`).
   Without it the release build is signed with the debug key (fine for testing,
   **not** accepted by Google Play).

Create `config/prod.json` (not committed) with your values:

```json
{
  "BASE_URL": "https://your-real-domain.com",
  "ONESIGNAL_APP_ID": "",
  "SSL_PINS": ""
}
```

## 2. Install dependencies

```bash
flutter clean
```

```bash
flutter pub get
```

## 3. Debug build (for testing on a device)

```bash
flutter run --dart-define-from-file=config/prod.json
```

## 4. Release APK

Universal APK (all CPU architectures):

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```

Smaller per-architecture APKs (recommended for direct distribution):

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```

Output: `build/app/outputs/flutter-apk/` (`app-release.apk` or
`app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`).

## 5. Release App Bundle (Google Play)

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

Keep `build/symbols/` for every release – it is needed to de-obfuscate Dart crash
stack traces:

```bash
flutter symbolize -i stacktrace.txt -d build/symbols/app.android-arm64.symbols
```

## 6. Install on a device

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 7. Verify before shipping

```bash
flutter analyze
```

```bash
flutter test
```

Manual checklist:

- [ ] Splash → permissions onboarding (first launch) → Home loads the website
- [ ] All four tabs and every drawer entry open the right pages
- [ ] Pull to refresh, back navigation, double-back-to-exit
- [ ] Airplane mode → offline screen → reconnects automatically
- [ ] Download a PDF (view + download), an image and a ZIP; notification shows progress
- [ ] File upload with camera and gallery
- [ ] `tel:`, `mailto:`, WhatsApp, Maps, Facebook, YouTube links open their apps
- [ ] Push notification in foreground, background and killed state; tap opens the URL
- [ ] Biometric lock on, app locks after 60 s in background
- [ ] Screenshot attempt is blocked
- [ ] Dark mode (System / Light / Dark)
- [ ] `myapp://wallet` and `https://<domain>/team` open the app on the right tab:

```bash
adb shell am start -a android.intent.action.VIEW -d "myapp://wallet"
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `Could not resolve com.github.Yalantis:ucrop` | The build machine cannot reach jitpack.io |
| `requires ... compileSdk of at least 37` | Install Android SDK Platform 37 (`sdkmanager "platforms;android-37.0"`) |
| HTTP 429 from Maven Central | Re-run the build; Gradle retries downloads |
| Push not received | Check `google-services.json`, notification permission, battery optimisation |
| App Links open the browser | Publish `assetlinks.json` with the Play signing SHA-256, then `adb shell pm verify-app-links --re-verify com.nexus.consumers` |
