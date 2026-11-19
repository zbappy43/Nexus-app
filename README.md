# Nexus Consumers Limited – Android App

Production Flutter app that wraps the Nexus Consumers website in a secure,
native Android shell (Material 3, MVVM, Provider).

| | |
|---|---|
| Package | `com.nexus.consumers` |
| Version | 1.0.0 (build 1) |
| Min / Target SDK | 24 / 37 (compileSdk 37) |
| Flutter / Dart | 3.50.0 stable / 3.14 |
| Android toolchain | AGP 9.3.1 · Gradle 9.5 · Kotlin 2.4.20 · Java 17 |

Further guides:
[APK build](docs/BUILD_APK.md) ·
[Signing](docs/SIGNING.md) ·
[Play Store release](docs/PLAY_STORE_RELEASE.md)

---

## 1. Quick start

```bash
flutter pub get
```

```bash
flutter run --dart-define=BASE_URL=https://your-real-domain.com
```

Then set the same host in `android/gradle.properties` → `nexus.webHost=your-real-domain.com`
(this drives verified App Links).

## 2. Configuration (no code changes needed)

All runtime configuration lives in `lib/constants/app_config.dart` and can be
overridden with `--dart-define`:

| Define | Default | Purpose |
|---|---|---|
| `BASE_URL` | `https://www.nexusglobalplc.com` | Website root rendered by the app |
| `PATH_HOME`, `PATH_TEAM`, `PATH_WALLET`, `PATH_PROFILE` | `/`, `/team`, `/wallet`, `/profile` | Bottom-navigation tabs |
| `PATH_TRAINING`, `PATH_NOTICE`, `PATH_SUPPORT`, `PATH_CONTACT`, `PATH_ABOUT`, `PATH_PRIVACY` | `/training` … `/privacy-policy` | Drawer entries |
| `PATH_LOGIN`, `PATH_LOGOUT`, `PATH_REGISTER` | `/login`, `/logout`, `/register` | Auto-login detection, logout, referral link |
| `REFERRAL_KEY` | `ref` | Query key for referral links (`/register?ref=CODE`) |
| `VERSION_CHECK_URL` | `$BASE_URL/app/version.json` | Version manifest (see §6) |
| `ONESIGNAL_APP_ID` | *(empty → OneSignal off)* | OneSignal push |
| `SSL_PINS` | *(empty → pinning off)* | Comma-separated certificate pins (see §8) |
| `DEEP_LINK_SCHEME` | `myapp` | Custom scheme; keep in sync with `nexus.deepLinkScheme` |
| `SECURE_SCREEN` | `true` | Set `false` only to take store screenshots |

Tip: keep them in a file and pass `--dart-define-from-file=config/prod.json`.

## 3. Project structure

```
lib/
├── main.dart                      Entry point, global error handling
├── app.dart                       MultiProvider + MaterialApp + security layers
├── constants/                     AppConfig, colours, strings, storage keys
├── themes/                        Material 3 light / dark themes
├── core/
│   ├── bootstrap.dart             Start-up initialisation (runs under splash)
│   ├── di/app_services.dart       Composition root (all services, once)
│   ├── errors/                    Typed exceptions
│   ├── network/secure_http_client HTTPS-only client with certificate pinning
│   └── web/                       JS bridge handlers + injected JS loader
├── models/                        AppNotification, DownloadItem, VersionInfo, AppTab
├── services/                      Platform/plugin wrappers (Service layer)
│   ├── connectivity_service        Online detection + auto re-probe
│   ├── push_notification_service   Firebase Cloud Messaging (fg/bg/taps)
│   ├── onesignal_service           OneSignal
│   ├── local_notification_service  Channels, display, tap routing, badges
│   ├── download_service            flutter_downloader + progress isolate port
│   ├── biometric_service           Fingerprint / face (local_auth)
│   ├── security_service            FLAG_SECURE, screen-recording signal
│   ├── update_service              version.json + Play In-App Update
│   ├── permission_service          Runtime permissions per SDK level
│   ├── media_service               Pick → crop → compress images
│   ├── deep_link_service           App Links + myapp:// from MainActivity
│   ├── launcher_service            WhatsApp, tel:, mailto:, Maps, Facebook…
│   ├── share_service / storage_service / web_session_service / device_info_service
├── repositories/                  Settings, Auth (encrypted credentials), Notification inbox
├── providers/                     ViewModels (ChangeNotifier): Theme, Connectivity,
│                                  Navigation, Auth, Update, Notification, Download, AppStage
├── screens/                       splash, shell, webview popup, auth (lock, force update),
│                                  scanner, pdf, downloads, notifications, media, settings
├── widgets/                       NexusWebView, drawer, status views, logo
└── utils/                         URL routing rules, file helpers, versions, logger, UI helpers
assets/js/                         nexus_bridge.js (window.NexusApp), auto_login.js
android/                           Gradle (KTS), manifest, MainActivity.kt, R8 rules
tools/                             Brand asset generator, SSL pin generator
docs/                              Build / signing / release guides, website files
test/                              Unit tests (routing, files, versions, pinning)
```

**Architecture.** MVVM with a repository pattern: *Screens/Widgets* observe
*Providers* (ViewModels) → which use *Repositories* (persistence) and
*Services* (platform/plugins). `AppServices` is the single composition root.

## 4. Feature map

| Requirement | Where |
|---|---|
| WebView: JS, DOM storage, cookies, session persistence, cache, zoom | `widgets/nexus_web_view.dart` |
| Pull to refresh, progress bar, back navigation | same + `providers/navigation_provider.dart` |
| Multiple windows / pop-ups (OAuth, payments) | `screens/webview/popup_webview_screen.dart` |
| File upload, camera, microphone, geolocation | WebView permission callbacks + `permission_service.dart` |
| Downloads (images, PDF, Excel, ZIP, video, data:/blob:) with notification & progress | `download_service.dart`, `download_provider.dart`, `screens/downloads/` |
| Open after download, in-app PDF viewer (zoom + search) | `screens/pdf/pdf_viewer_screen.dart` |
| External links: WhatsApp, phone, e-mail, SMS, Maps, Facebook, Messenger, YouTube, intent:// | `utils/url_utils.dart`, `launcher_service.dart` |
| Animated splash (2 s) + native splash | `screens/splash/`, `flutter_native_splash` config |
| Native bottom navigation (Home, Team, Wallet, Profile) – one WebView per tab, kept alive | `screens/shell/main_shell.dart` |
| Drawer (Home … Privacy Policy, Logout) + Notifications, QR, Photo tools, Settings | `widgets/app_drawer.dart` |
| App bar: logo, refresh, share (page / referral / app), notification badge | `main_shell.dart` |
| Offline detection, offline screen, auto-reconnect, offline cache | `connectivity_service.dart`, `widgets/status_view.dart` |
| Error page with reload; renderer-crash recovery | `nexus_web_view.dart` |
| FCM foreground/background/click, badge, inbox | `push_notification_service.dart`, `notification_provider.dart` |
| OneSignal | `onesignal_service.dart` |
| Remember login, auto login, secure storage | `auth_provider.dart`, `auth_repository.dart`, `assets/js/` |
| Fingerprint / face unlock (re-lock after 60 s in background) | `biometric_service.dart`, `screens/auth/lock_screen.dart` |
| Screenshot & screen-recording block, secure cookies, HTTPS only, SSL pinning, debugger block, obfuscation | `MainActivity.kt`, `security_service.dart`, `secure_http_client.dart`, network security config |
| QR + barcode scanner (camera or gallery image) | `screens/scanner/qr_scanner_screen.dart` |
| Image picker, crop, compress | `media_service.dart`, `screens/media/image_tools_screen.dart` |
| Fullscreen / landscape video with auto-rotate | `onEnterFullscreen` / `onExitFullscreen` |
| Deep links `https://` (App Links) and `myapp://` | manifest + `MainActivity.kt` + `deep_link_service.dart` |
| Dark mode: System / Light / Dark (+ WebView algorithmic darkening) | `theme_provider.dart`, `settings_screen.dart` |
| Version check, update dialog, force update, Play in-app update (flexible + immediate) | `update_provider.dart`, `force_update_screen.dart` |
| Permissions: camera, mic, storage, notification, location, Bluetooth | `permission_service.dart`, `screens/settings/permissions_screen.dart` |
| Double back to exit | `main_shell.dart` |

## 5. Firebase setup (push notifications)

1. Create a project at <https://console.firebase.google.com> → **Add app → Android**,
   package name `com.nexus.consumers`. Add your SHA-1/SHA-256 (see `docs/SIGNING.md`).
2. Download **`google-services.json`** and place it at `android/app/google-services.json`.
3. Rebuild. The Gradle build applies the Google Services plugin automatically when the
   file exists (without it the app still builds; FCM is simply disabled).

Sending: the app subscribes every device to topic **`all_users`**. Put the target
page in the data payload so taps open it:

```json
{
  "message": {
    "topic": "all_users",
    "notification": { "title": "New notice", "body": "Monthly meeting on Friday" },
    "data": { "url": "/notice/42" },
    "android": { "notification": { "channel_id": "nexus_general" } }
  }
}
```

`url` may be a path, a full website URL or `myapp://…`. Data-only messages are shown
by the app itself (foreground and background). The website can read the device's
FCM installation ID via `NexusApp.pushToken()` to target individual users.

## 6. OneSignal setup

1. Create an app at <https://onesignal.com> → Android (FCM) and upload the Firebase
   service-account JSON as OneSignal instructs.
2. Build with `--dart-define=ONESIGNAL_APP_ID=<your-app-id>`.
3. Call `NexusApp.setUserId('<user id>')` from the website after login so you can
   target users by external ID. Use **Launch URL** or `additionalData.url` to choose
   the page opened on tap.

## 7. Website integration

* **Version manifest**: publish `docs/website/version.json` at
  `https://<domain>/app/version.json`. Raise `min_supported_version` to force users
  onto a newer build (blocking screen → Play Store / immediate in-app update).
* **App Links**: publish `docs/website/assetlinks.json` at
  `https://<domain>/.well-known/assetlinks.json` with your Play app-signing and
  upload key SHA-256 fingerprints.
* **JavaScript bridge** (`window.NexusApp`, only on HTTPS pages of your domain):

```js
if (window.NexusApp) {
  const code  = await NexusApp.scanQr();                          // string | null
  const photo = await NexusApp.pickImage({ source: 'camera', crop: true, square: true });
  // photo = { dataUrl, fileName, mimeType, size } | null
  await NexusApp.share({ text: 'Join me', url: location.href });
  await NexusApp.openPdf('/statements/2024-06.pdf');
  await NexusApp.download('/reports/team.xlsx', 'team.xlsx');
  const ok = await NexusApp.biometric('Confirm withdrawal');      // true | false
  const device = await NexusApp.deviceInfo();
  const push = await NexusApp.pushToken();                        // { fcm, onesignal }
  NexusApp.setReferralCode('ABC123');                             // used by "Share referral link"
  NexusApp.setUserId('42');
  NexusApp.logout();
}
```

* The user agent contains `NexusConsumersApp/<version>` so the site can tailor layout.
* **Remember / auto login** works with a standard HTML login form at `PATH_LOGIN`
  containing a password field. Credentials are stored with Android Keystore (AES-GCM).

## 8. Security notes

* `FLAG_SECURE` blocks screenshots, screen recording and the recents thumbnail;
  Android 15+ additionally reports recordings and the app hides its content.
* Cleartext HTTP is disabled, mixed content is blocked, Safe Browsing is on,
  `file://` access is disabled, cloud backup/device transfer is excluded.
* Release builds: R8 minification + resource shrinking, Dart obfuscation
  (`--obfuscate --split-debug-info`), WebView debugging off, the app exits if a
  debugger attaches.
* **Certificate pinning** (`SSL_PINS`): every native HTTPS request and every
  first-party page load in the WebView is checked against the pins.
  Generate with `tools/generate_ssl_pins.sh www.nexusglobalplc.com`. Pins are for the leaf
  certificate – include the next certificate's pin before each renewal.
* Session cookies are protected by HTTPS-only transport; mark them `Secure; HttpOnly;
  SameSite=Lax` on the server.

## 9. Branding

All brand images are generated from the official emblem
`assets/brand/logo_source.jpg`: in-app logo, launcher icons (legacy, adaptive,
round, Android 13 monochrome) and native splash (incl. Android 12).
To rebrand, replace that file and run:

```bash
python3 tools/generate_brand_assets.py
```

```bash
dart run flutter_launcher_icons
```

```bash
dart run flutter_native_splash:create
```

```bash
python3 tools/generate_brand_assets.py --round-only
```

The notification icon is the vector `android/app/src/main/res/drawable/ic_stat_notification.xml`.

## 10. Quality checks

```bash
flutter analyze
```

```bash
flutter test
```

## 11. Known toolchain notes

* `android.r8.proguardAndroidTxt.disallowed=false` in `android/gradle.properties` is
  required because `flutter_inappwebview_android` 1.1.x still references the legacy
  ProGuard file that AGP 9 rejects. Remove it once the plugin is updated.
* Flutter prints a warning that `flutter_downloader` and `flutter_image_compress`
  apply the Kotlin Gradle Plugin; builds work today, track plugin updates.
* `image_cropper` pulls uCrop from **jitpack.io**; the build machine needs access to it.
* `open_filex` declares `READ_MEDIA_IMAGES/VIDEO/AUDIO`; the app manifest removes them
  (`tools:node="remove"`) because files are opened from the app's own directory.
  This keeps the app out of Google Play's Photo & Video Permissions declaration.
