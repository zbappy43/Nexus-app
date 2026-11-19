# App Signing Guide

Google Play uses **Play App Signing**: you sign uploads with an *upload key*,
Google re-signs the app with the *app signing key* it manages.

## 1. Create the upload keystore (once)

```bash
keytool -genkey -v -keystore ~/nexus-upload-keystore.jks -keyalg RSA -keysize 4096 -validity 10000 -alias nexus-upload
```

Answer the prompts (name, organisation "Nexus Consumers Limited", country code).
Use a strong password and store the keystore + passwords in a password manager
and an offline backup. **If the upload key is lost you must request a reset from
Google Play support.**

## 2. Reference it from the project

Create `android/key.properties` (already git-ignored – never commit it):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=nexus-upload
storeFile=/absolute/path/to/nexus-upload-keystore.jks
```

`android/app/build.gradle.kts` loads this file automatically. When it is missing
the release build is signed with the debug key and Gradle prints a warning.

## 3. Build signed artifacts

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```

## 4. Verify the signature

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## 5. Fingerprints (Firebase, App Links)

Upload key SHA-1 / SHA-256:

```bash
keytool -list -v -keystore ~/nexus-upload-keystore.jks -alias nexus-upload
```

App signing key: Play Console → *Test and release → Setup → App signing* →
"App signing key certificate".

Add **both** SHA-256 fingerprints to:

* Firebase project settings → Android app → SHA certificate fingerprints
* `https://<domain>/.well-known/assetlinks.json` (template in `docs/website/`)

## 6. CI signing (optional)

Store the keystore as a base64 secret and recreate it during the build:

```bash
echo "$UPLOAD_KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks
```

Then write `android/key.properties` from secrets with
`storeFile=upload-keystore.jks` (paths are resolved relative to `android/app`).
