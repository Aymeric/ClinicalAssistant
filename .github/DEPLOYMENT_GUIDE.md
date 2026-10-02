# GitHub CI/CD & Store Deployment Guide

This repository contains automated GitHub Actions workflows for continuous integration and automated store releases:

- **`.github/workflows/ci.yml`**: Runs formatting, static analysis (`dart analyze`), and tests (`flutter test`) on every push to `main` and pull request.
- **`.github/workflows/release.yml`**: Builds, signs, and deploys Android (`.aab` / `.apk`) to **Google Play Store** and iOS (`.ipa`) to **Apple TestFlight / App Store**, and attaches binaries to a GitHub Release.

---

## 1. Triggering Releases

### Manual Release (`workflow_dispatch`)
1. Go to **Actions** → **Release (Google Play & Apple App Store)**.
2. Click **Run workflow**.
3. Select your deployment options:
   - **Google Play Track**: `internal` (recommended for testing), `alpha`, `beta`, `production`, or `none` (skip).
   - **Deploy to Apple**: Check to upload to TestFlight / App Store.
   - **Release notes**: Short changelog or "What to test" notes.
   - **Create draft GitHub Release**: Attach the compiled `.apk`, `.aab`, and `.ipa` to a GitHub Release draft.

### Tag-Based Release
Pushing any git tag matching `v*.*.*` automatically triggers the full release pipeline:
```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 2. GitHub Secrets Setup

Navigate to your repository on GitHub:
**Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

### A. Android & Google Play Secrets

| Secret Name | Description | How to obtain |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore (`.jks` / `.keystore`) | `openssl base64 < upload-keystore.jks \| tr -d '\n'` |
| `ANDROID_KEYSTORE_PASSWORD` | Password protecting the keystore file | Provided during keystore generation |
| `ANDROID_KEY_ALIAS` | Alias name for the upload key | (e.g., `upload` or `clinical_assistant`) |
| `ANDROID_KEY_PASSWORD` | Password for the key alias | Provided during keystore generation |
| `PLAY_STORE_UPLOAD_SERVICE_ACCOUNT_JSON` | Google Play Service Account JSON key | Google Cloud Console → Service Accounts with Google Play Developer API permissions |
| `ANDROID_PACKAGE_NAME` *(optional)* | Application ID in Google Play Console | Defaults to `com.example.clinical_assistant` |

#### Generating an Android Keystore (if you do not have one):
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

#### Google Play Service Account Setup:
1. Open [Google Play Console](https://play.google.com/console) → **API access**.
2. Link or create a Google Cloud Project.
3. Click **Create new service account** and follow the link to Google Cloud Console.
4. In Google Cloud Console, grant the service account permissions for the Google Play Android Developer API.
5. Generate a **JSON** key and download it.
6. In Google Play Console, grant the service account access to your app (Releases, App bundles).
7. Paste the entire JSON file contents into `PLAY_STORE_UPLOAD_SERVICE_ACCOUNT_JSON`.

---

## 3. Apple App Store & TestFlight Secrets

| Secret Name | Description | How to obtain |
|---|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID | App Store Connect → Users and Access → Integrations → Keys |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID | App Store Connect → Users and Access → Integrations → Keys |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | Contents of the `.p8` private key file | Downloaded when creating the API key |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID | Apple Developer Portal → Membership |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution Certificate (`.p12`) | `openssl base64 < Certificates.p12 \| tr -d '\n'` |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password chosen when exporting `.p12` from Keychain | Export password |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store Provisioning Profile (`.mobileprovision`) | `openssl base64 < profile.mobileprovision \| tr -d '\n'` |
| `IOS_BUNDLE_ID` *(optional)* | Bundle identifier of the app | Defaults to `com.aymericgrassart.clinicalAssistant` |

#### Generating Apple Distribution Certificate & Profile:
1. In macOS Keychain Access, create a Certificate Signing Request (CSR).
2. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list) → Create an **Apple Distribution** certificate.
3. Download the certificate, double-click to install it into Keychain Access.
4. In Keychain Access, right-click the certificate and select **Export "Apple Distribution: ..."** as a `.p12` file with a strong password.
5. In Apple Developer portal, create an **App Store** provisioning profile for your Bundle ID, download the `.mobileprovision` file.
6. Convert both to base64 strings and add them to GitHub Secrets.

---

## 4. Local Build Verification

To test building release binaries locally before pushing:

### Android:
```bash
# Build release APK
flutter build apk --release

# Build AppBundle for Google Play
flutter build appbundle --release
```

### iOS:
```bash
# Build archive & IPA (requires macOS and Xcode)
flutter build ipa --release
```
