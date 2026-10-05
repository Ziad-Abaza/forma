# Forma Mobile Application

Forma is a modern, bilingual (Arabic RTL & English LTR) health and fitness companion application built with Flutter, Dart, and Riverpod.

## Self-Contained Directory Architecture

This directory is completely self-contained. It contains:
- Environment configuration templates and local files (`.env`, `.env.example`)
- Environment configuration provider (`lib/core/config/env_config.dart`)
- Local assets, typography, and theme definitions
- Bilingual internationalization files (`lib/l10n/`)
- Presentation layers, screens, and custom widgets
- Dedicated widget and unit test suites (`test/`)
- Platform-specific deployment wrappers (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`)

## Prerequisites

- **Flutter SDK**: `>=3.13.1` (tested with Flutter 3.24+)
- **Dart SDK**: `^3.13.1`
- **Android Studio** / **Xcode**: For emulator or physical device development

## Getting Started

### 1. Environment Configuration

Copy the example environment file:
```bash
cp .env.example .env
```

Customize `.env` according to your target runtime:
```env
# Backend API Base URL
# - For iOS Simulator / Web / Desktop: http://localhost:3000
# - For Android Emulator: http://10.0.2.2:3000
# - For Physical Device: http://<YOUR_LOCAL_IP>:3000
API_BASE_URL=http://localhost:3000

ENVIRONMENT=development
API_TIMEOUT_MS=15000
ENABLE_ANALYTICS_LOGS=false
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Localizations

Generate the bilingual localization delegates (`en`, `ar`):
```bash
flutter gen-l10n
```

### 4. Run the Application

Launch the application with the local environment file loaded:
```bash
flutter run --dart-define-from-file=.env
```

Or target a specific device:
```bash
# Run on connected Chrome browser
flutter run -d chrome --dart-define-from-file=.env

# Run on Android emulator
flutter run -d emulator-5554 --dart-define-from-file=.env

# Run on Windows desktop
flutter run -d windows --dart-define-from-file=.env
```

## Running Tests & Static Analysis

- **Run all widget and unit tests**:
  ```bash
  flutter test
  ```
- **Run static analyzer and linter**:
  ```bash
  flutter analyze
  ```

## Building for Release

### Android APK:
```bash
flutter build apk --release --dart-define-from-file=.env
```

### Android App Bundle (Google Play):
```bash
flutter build appbundle --release --dart-define-from-file=.env
```

### iOS:
```bash
flutter build ipa --release --dart-define-from-file=.env
```

### Web:
```bash
flutter build web --release --dart-define-from-file=.env
```
