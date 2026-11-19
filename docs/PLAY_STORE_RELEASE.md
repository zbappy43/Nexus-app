# Google Play Release Guide

## 1. Before the first release

- [ ] Real domain configured (`BASE_URL`, `nexus.webHost`)
- [ ] `google-services.json` added, test push received
- [ ] Upload keystore created and `android/key.properties` in place (`SIGNING.md`)
- [ ] Brand artwork final (`tools/generate_brand_assets.py`, README §9)
- [ ] `https://<domain>/app/version.json` published
- [ ] `https://<domain>/.well-known/assetlinks.json` published
- [ ] Privacy policy page live at `PATH_PRIVACY`
- [ ] Manual checklist in `BUILD_APK.md` §7 passed on a real device

## 2. Versioning

`pubspec.yaml` → `version: <versionName>+<versionCode>`, e.g. `1.0.0+1`.
Every upload needs a **higher versionCode**: `1.0.1+2`, `1.1.0+3`, …

After publishing, update `version.json` → `latest_version`. Only raise
`min_supported_version` when old versions must stop working (force update).

## 3. Build the bundle

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```

Archive `build/symbols/` together with the release tag.

## 4. Play Console setup (first time)

1. **Create app** → name *Nexus Consumers*, default language, App, Free.
2. **Store listing**: short description (≤ 80 chars), full description, app icon
   512×512 (`assets/icons/app_icon.png` resized), feature graphic 1024×500,
   at least 2 phone screenshots (build once with `--dart-define=SECURE_SCREEN=false`
   to capture them – do **not** ship that build).
3. **App content**
   * Privacy policy URL: `https://<domain>/privacy-policy`
   * Data safety: declare collected data – account info (login), device IDs
     (push token), photos (only uploaded by the user), approximate/precise
     location (only when the website asks), crash logs if you add a crash SDK.
     Data is encrypted in transit; users can request deletion via the website.
   * Ads: No (unless the website shows ads)
   * Target audience, content rating questionnaire, news app: No
   * Financial features declaration if wallet/payments are offered
4. **Permissions declarations**: the app requests camera, microphone, location
   and Bluetooth only when used; no background location; no SMS/call log;
   no `MANAGE_EXTERNAL_STORAGE` / `QUERY_ALL_PACKAGES`. Explain foreground use of
   camera (QR scanning, photo upload) and microphone (website audio/video).
5. **App signing**: accept Play App Signing on the first upload.

## 5. Release tracks

1. **Internal testing** → upload the `.aab`, add testers, install from the opt-in link.
   In-app updates are testable from this track (install an older build via the
   Play link, publish a newer one).
2. **Closed testing** – personal developer accounts created after Nov 2023 must
   run a closed test with ≥ 12 testers for 14 days before production.
3. **Production** → staged rollout (10 % → 50 % → 100 %), watch *Android vitals*.

## 6. In-app updates

* Default: Play shows a **flexible** update; the app offers "Restart" when downloaded.
* For urgent releases set **in-app update priority 4 or 5** via the Play Developer
  API (`inAppUpdatePriority` on the track release) → the app runs an **immediate**
  (blocking) update. Updates older than 7 days are also applied immediately.
* For a hard cut-off use `min_supported_version` in `version.json`.

## 7. After each release

- [ ] Update `version.json` (`latest_version`)
- [ ] Tag the commit (`git tag v1.0.1+2`) and archive `build/symbols`
- [ ] Check pre-launch report and Android vitals for crashes/ANRs
