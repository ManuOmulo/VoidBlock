# Building Release APK

This document explains how to build a production release APK for FocusGuard.

## Quick Build Command

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Build Options

### Standard Release APK
```bash
flutter build apk --release
```
- Single APK for all architectures
- Larger file size
- Output: `build/app/outputs/flutter-apk/app-release.apk`

### Split APKs (per architecture)
```bash
flutter build apk --split-per-abi --release
```
- Separate APKs for each CPU architecture (arm64-v8a, armeabi-v7a, x86_64)
- Smaller file sizes per APK
- Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, etc.

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
- Recommended for Google Play Store
- Output: `build/app/outputs/bundle/release/app-release.aab`

## Signing Configuration

The app is configured with release signing using the keystore at `android/upload-keystore.jks`.

**Important:** The keystore and `android/key.properties` are in `.gitignore` for security. Keep backups of:
- `android/upload-keystore.jks` - The keystore file
- Keystore password and key password - Stored in `android/key.properties`

**If you lose the keystore, you cannot update the app on Play Store.**

## Obfuscation

Code obfuscation is enabled in `android/app/build.gradle`:
- `minifyEnabled true` - Shrinks and obfuscates code
- `shrinkResources true` - Removes unused resources
- ProGuard rules in `android/app/proguard-rules.pro`

## Testing Before Release

1. Test with debug build:
   ```bash
   flutter run
   ```

2. Test with release build (uses debug signing):
   ```bash
   flutter run --release
   ```

3. Build production APK (uses keystore signing):
   ```bash
   flutter build apk --release
   ```

## Installing the APK

1. Transfer the APK to your device (USB, cloud, etc.)
2. Enable "Install from unknown sources" in device settings
3. Tap the APK file to install

## Version Updates

To update the app version, edit `android/app/build.gradle`:
- `versionCode` - Increment for each release (integer)
- `versionName` - User-facing version string (e.g., "1.0.0")

Or update in `pubspec.yaml` (Flutter will sync to Android).

## Troubleshooting

**Build fails with signing error:**
- Ensure `android/key.properties` exists
- Ensure `android/upload-keystore.jks` exists
- Check passwords in `key.properties` are correct

**APK won't install:**
- Ensure "Install from unknown sources" is enabled
- Try uninstalling the old version first
- Check that versionCode is higher than previous version
