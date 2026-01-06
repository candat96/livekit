# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter cross-platform video call application targeting Android, iOS, Web, Windows, macOS, and Linux. The project uses Dart 3.6.1+ with Material Design 3.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app (connected device/emulator)
flutter run

# Run static analysis/linting
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build for specific platforms
flutter build apk          # Android APK
flutter build ios          # iOS (requires macOS)
flutter build web          # Web
flutter build macos        # macOS desktop
flutter build windows      # Windows desktop
flutter build linux        # Linux desktop

# Check for outdated dependencies
flutter pub outdated
```

## Architecture

Currently a minimal starter project with all application code in `lib/main.dart`. As the project grows, follow Flutter conventions:

- **lib/** - Main Dart source code
- **test/** - Widget and unit tests
- **android/**, **ios/**, **web/**, **macos/**, **windows/**, **linux/** - Platform-specific native code

## Code Conventions

- **Classes**: PascalCase (e.g., `MyHomePage`)
- **Private members**: Leading underscore (e.g., `_counter`, `_MyHomePageState`)
- **Files**: snake_case (e.g., `main.dart`)
- **Null safety**: Enabled (Dart 3.6.1+)
- **Linting**: Uses `flutter_lints` package with Flutter recommended rules

## Testing

Widget tests use `flutter_test` and `WidgetTester`. Import app files using package syntax:
```dart
import 'package:videocall/main.dart';
```
