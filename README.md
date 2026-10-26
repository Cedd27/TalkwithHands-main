Talk with Hands/
├─ lib/                         # Main app source (Dart)
│  ├─ main.dart                 # App entrypoint, theme, initial route
│  ├─ classifiers/
│  │  └─ sign_classifier.dart   # Hand-landmark to sign classification logic
│  ├─ painters/
│  │  └─ landmark_painter.dart  # Draws hand/face landmarks on camera preview
│  ├─ screens/
│  │  ├─ splash_screen.dart     # Startup screen
│  │  ├─ landing_screen.dart    # Landing / auth choice
│  │  ├─ auth_screen.dart       # Login / signup UI
│  │  ├─ welcome_screen.dart    # Post-login home/welcome
│  │  ├─ sign_detector_screen.dart # Camera + detection + sentence builder
│  │  └─ progress_screen.dart   # User progress view
│  ├─ services/
│  │  └─ tts_service.dart       # Text-to-speech wrapper
│  └─ ui/
│     └─ app_shell.dart         # Shared UI shell/components
│
├─ test/
│  └─ widget_test.dart          # Basic Flutter widget test
│
├─ android/                     # Android runner project
│  ├─ app/src/main/             # Android app code/resources/manifest
│  ├─ gradle/                   # Gradle wrapper config
│  ├─ build.gradle.kts          # Android build config
│  └─ settings.gradle.kts       # Android modules settings
│
├─ ios/                         # iOS runner project
│  ├─ Runner/                   # iOS app code/plist/assets
│  ├─ Flutter/                  # Flutter iOS bridge config (+ ephemeral generated)
│  ├─ Runner.xcodeproj/         # Xcode project
│  └─ Runner.xcworkspace/       # Xcode workspace
│
├─ web/
│  ├─ index.html                # Web host page
│  └─ manifest.json             # Web app manifest
│
├─ windows/                     # Windows runner
├─ linux/                       # Linux runner
├─ macos/                       # macOS runner
│
├─ build/                       # Generated build outputs
├─ .dart_tool/                  # Dart/Flutter tool state (generated)
├─ .idea/                       # IntelliJ/Android Studio project settings
├─ .vscode/                     # VSCode/Cursor workspace settings
│
├─ pubspec.yaml                 # Dependencies, assets, app metadata
├─ analysis_options.yaml        # Lints/analyzer rules
├─ README.md                    # Project documentation
├─ .gitignore                   # Git ignore rules
└─ .metadata                    # Flutter project metadata


Important Notes
Main app logic is in lib/ (this is the folder you’ll edit most).
build/, .dart_tool/, and */Flutter/ephemeral/ are generated files/folders.
android_old/ exists and looks like a legacy duplicate Android folder.
I also noticed pubspec.yaml references assets/images/app_logo.png; if that file is missing, the app may fail when loading assets.


1) Directory structure (very thorough)
Root: c:\Users\Mary Jasmine\Downloads\Talk with Hands

c:\Users\Mary Jasmine\Downloads\Talk with Hands
├─ .dart_tool/
│  ├─ dartpad/
│  ├─ flutter_build/
│  │  └─ 4db66e48dc3aef4a893b3695e3323a28/
│  ├─ package_config.json
│  ├─ package_graph.json
│  └─ version
├─ .idea/
│  ├─ libraries/
│  ├─ runConfigurations/
│  └─ workspace.xml
├─ .vscode/
│  └─ settings.json
├─ android/
│  ├─ .gradle/
│  │  └─ buildOutputCleanup/
│  ├─ .kotlin/
│  │  └─ errors/
│  ├─ app/
│  │  ├─ src/
│  │  │  ├─ debug/
│  │  │  ├─ main/
│  │  │  │  ├─ java/io/flutter/plugins/
│  │  │  │  ├─ kotlin/com/example/sign_language_app/
│  │  │  │  └─ res/
│  │  │  │     ├─ drawable/
│  │  │  │     ├─ drawable-v21/
│  │  │  │     ├─ values/
│  │  │  │     └─ values-night/
│  │  │  └─ profile/
│  │  └─ build.gradle.kts
│  ├─ gradle/wrapper/
│  ├─ build.gradle.kts
│  ├─ settings.gradle.kts
│  ├─ gradlew
│  └─ gradlew.bat
├─ android_old/   (legacy copy)
│  ├─ .gradle/
│  ├─ app/
│  │  ├─ src/
│  │  │  ├─ debug/
│  │  │  ├─ main/
│  │  │  │  ├─ java/io/flutter/plugins/
│  │  │  │  ├─ kotlin/
│  │  │  │  │  ├─ com/example/sign_language_app/
│  │  │  │  │  └─ MainActivity.kt
│  │  │  │  └─ res/
│  │  │  └─ profile/
│  │  ├─ build.gradle
│  │  └─ build.gradle.kts
│  ├─ gradle/wrapper/
│  ├─ build.gradle.kts
│  └─ settings.gradle.kts
├─ build/   (generated, large)
│  ├─ .cxx/
│  │  └─ debug/69514j1v/
│  │     ├─ arm64-v8a/
│  │     ├─ armeabi-v7a/
│  │     └─ x86_64/
│  ├─ 828e58b2a4dd2b7dc5055b41a609f2af/
│  ├─ app/
│  │  ├─ intermediates/
│  │  │  ├─ assets/debug/mergeDebugAssets/
│  │  │  ├─ cxx/debug/69514j1v/
│  │  │  ├─ flutter/debug/
│  │  │  ├─ incremental/
│  │  │  ├─ merged_res_blame_folder/
│  │  │  └─ ...
│  │  └─ outputs/
│  │     ├─ apk/debug/
│  │     └─ flutter-apk/
│  ├─ jni/intermediates/cxx/Debug/4x6bn334/
│  ├─ native_hooks/
│  └─ reports/problems/
├─ ios/
│  ├─ Flutter/
│  │  ├─ ephemeral/
│  │  ├─ AppFrameworkInfo.plist
│  │  ├─ Debug.xcconfig
│  │  ├─ Generated.xcconfig
│  │  └─ Release.xcconfig
│  ├─ Runner/
│  │  ├─ Assets.xcassets/
│  │  │  ├─ AppIcon.appiconset/
│  │  │  └─ LaunchImage.imageset/
│  │  ├─ Base.lproj/
│  │  ├─ AppDelegate.swift
│  │  ├─ GeneratedPluginRegistrant.h
│  │  ├─ GeneratedPluginRegistrant.m
│  │  ├─ Info.plist
│  │  └─ SceneDelegate.swift
│  ├─ Runner.xcodeproj/
│  │  ├─ project.pbxproj
│  │  ├─ project.xcworkspace/
│  │  └─ xcshareddata/xcschemes/
│  ├─ Runner.xcworkspace/
│  └─ RunnerTests/
├─ lib/
│  ├─ classifiers/
│  │  └─ sign_classifier.dart
│  ├─ painters/
│  │  └─ landmark_painter.dart
│  ├─ screens/
│  │  ├─ auth_screen.dart
│  │  ├─ landing_screen.dart
│  │  ├─ progress_screen.dart
│  │  ├─ sign_detector_screen.dart
│  │  ├─ splash_screen.dart
│  │  └─ welcome_screen.dart
│  ├─ services/
│  │  └─ tts_service.dart
│  ├─ ui/
│  │  └─ app_shell.dart
│  └─ main.dart
├─ linux/
│  ├─ flutter/
│  ├─ runner/
│  └─ CMakeLists.txt
├─ macos/
│  ├─ Flutter/
│  │  └─ ephemeral/
│  ├─ Runner/
│  │  ├─ Assets.xcassets/
│  │  ├─ Base.lproj/
│  │  └─ Configs/
│  ├─ Runner.xcodeproj/
│  ├─ Runner.xcworkspace/
│  └─ RunnerTests/
├─ test/
│  └─ widget_test.dart
├─ web/
│  ├─ index.html
│  └─ manifest.json
├─ windows/
│  ├─ flutter/
│  ├─ runner/
│  └─ CMakeLists.txt
├─ .flutter-plugins-dependencies
├─ .gitignore
├─ .metadata
├─ analysis_options.yaml
├─ pubspec.yaml
└─ README.md


2) Categorized key files and what each does
App source / business logic
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\main.dart — Flutter entrypoint; sets theme and launches splash.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\screens\sign_detector_screen.dart — camera stream, hand detection, hold-to-confirm logic, sentence building, and UI controls.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\classifiers\sign_classifier.dart — rule-based alphabet/number/word sign classification from hand landmarks.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\painters\landmark_painter.dart — draws hand skeleton, face points, and bounding box overlays.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\services\tts_service.dart — text-to-speech wrapper (flutter_tts).
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\ui\app_shell.dart — reusable app shell widgets (background, menu, top bar, buttons).
UI screens / navigation flow
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\screens\splash_screen.dart — animated startup and transition to landing.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\screens\landing_screen.dart — log-in/sign-up entry screen.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\screens\auth_screen.dart — login/register form UI (currently local/mock flow).
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\screens\welcome_screen.dart — post-auth welcome and menu access.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\screens\progress_screen.dart — progress dashboard visuals.
Project config and docs
c:\Users\Mary Jasmine\Downloads\Talk with Hands\pubspec.yaml — package metadata, dependencies, and Flutter assets declarations.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\analysis_options.yaml — lint/analyzer rules.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\README.md — project overview, features, setup, and architecture notes.
Platform runners
c:\Users\Mary Jasmine\Downloads\Talk with Hands\android\app\src\main\kotlin\com\example\sign_language_app\MainActivity.kt — Android app entry activity.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\android\app\src\main\AndroidManifest.xml — Android permissions/app manifest.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\ios\Runner\AppDelegate.swift — iOS app delegate entrypoint.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\ios\Runner\Info.plist — iOS app metadata/permissions.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\windows\runner\main.cpp and c:\Users\Mary Jasmine\Downloads\Talk with Hands\linux\runner\main.cc — desktop launcher entrypoints.
c:\Users\Mary Jasmine\Downloads\Talk with Hands\web\index.html — web host page.
3) Generated/build folders vs source folders
Generated / build / tool-state (safe to clean/regenerate)
c:\Users\Mary Jasmine\Downloads\Talk with Hands\build\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\.dart_tool\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\ios\Flutter\ephemeral\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\macos\Flutter\ephemeral\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\android\.gradle\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\android\.kotlin\
Generated registrant files (platform glue), e.g. GeneratedPluginRegistrant.*, generated_plugin_registrant.*, generated_plugins.cmake
Source / maintained code
c:\Users\Mary Jasmine\Downloads\Talk with Hands\lib\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\test\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\android\app\src\main\ (except generated Java registrant file)
c:\Users\Mary Jasmine\Downloads\Talk with Hands\ios\Runner\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\linux\runner\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\windows\runner\
c:\Users\Mary Jasmine\Downloads\Talk with Hands\web\
4) Legacy/backup folders and duplicates
Legacy duplicate folder found: c:\Users\Mary Jasmine\Downloads\Talk with Hands\android_old\

Appears to be an older/full copy of Android project structure.
Contains duplicate Gradle files and duplicate MainActivity.kt locations.
Coexists with active android\, so this is likely archival/legacy and may cause confusion.
No explicit backup-name folders found like backup, bak, or copy (by name pattern).

Potential config/content mismatch: pubspec.yaml references assets/images/app_logo.png, but no file under assets/images/ was discovered in current file index (may be missing/untracked).














# Talk With Hands — Flutter Mobile App

A **native mobile sign language detector** for Android and iOS that replicates
your working `mediapipe_holistic.html` web app — fully ported to Flutter with
no WebView.

---

## ✨ Features (same as your old web version)

| Feature | Status |
|---|---|
| Live camera feed (front camera) | ✅ |
| Hand landmark overlay (skeleton + bounding box) | ✅ |
| Face landmark overlay | ✅ |
| A–Z Alphabet detection | ✅ |
| 0–10 Number detection | ✅ |
| Common words/phrases (hello, help, I love you…) | ✅ |
| Hold-to-confirm (22-frame hold) | ✅ |
| Auto-complete word suggestions (A–Z mode) | ✅ |
| Text-to-speech voice output | ✅ |
| Voice on/off toggle | ✅ |
| Pause/Resume camera | ✅ |
| Delete last / Space / Clear all | ✅ |
| Sentence builder | ✅ |
| History pill log | ✅ |

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── screens/
│   └── sign_detector_screen.dart      # Main UI + camera loop + state
├── classifiers/
│   └── sign_classifier.dart           # Dart port of your JS classifiers
├── painters/
│   └── landmark_painter.dart          # CustomPainter for hand/face overlay
└── services/
    └── tts_service.dart               # Text-to-speech wrapper
```

---

## 🚀 Setup & Run

### Prerequisites

```bash
flutter --version   # needs Flutter 3.10+ / Dart 3.0+
```

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Run on Android

```bash
flutter run
```

Connect your Android phone via USB with developer mode + USB debugging enabled.
The app requires **Android 5.0+ (minSdk 21)**.

### 3. Run on iOS

```bash
cd ios && pod install && cd ..
flutter run
```

You need Xcode + an Apple Developer account (free is fine for device testing).

---

## 🔑 Permissions

The app will ask for camera permission on first launch. Grant it when prompted.

**Android** — declared in `AndroidManifest.xml`:
- `CAMERA`
- `INTERNET` (for ML Kit model download on first run)

**iOS** — declared in `Info.plist`:
- `NSCameraUsageDescription`

---

## ⚙️ How It Works

### Detection Pipeline

```
Camera Frame (CameraImage)
        ↓
Google ML Kit Pose Detector
        ↓
Extract wrist + finger landmarks
        ↓
Build 21-point hand model
        ↓
SignClassifier (Dart port of your JS logic)
        ↓
Hold-to-confirm (22 frames = ~0.7s)
        ↓
Sentence builder + TTS
```

### Key Files to Edit

- **Add new signs**: Edit `lib/classifiers/sign_classifier.dart` — same logic as your JS.
- **Change hold time**: Change `_holdNeed = 22` in `sign_detector_screen.dart`.
- **Add words to dictionary**: Edit `kDict` list at the top of `sign_detector_screen.dart`.
- **Adjust detection thresholds**: Modify confidence values in `sign_classifier.dart`.

---

## 🔧 Improving Detection Accuracy

The current version uses **ML Kit Pose Detection** which gives wrist + 4 fingertip
landmarks. For production-grade accuracy matching MediaPipe Holistic, consider:

### Option A: MediaPipe Flutter (best match to your web version)
```yaml
# pubspec.yaml — add:
mediapipe_task_vision: ^0.10.14
```
This gives you the exact same 21-point hand model as your web version.

### Option B: Google ML Kit Hand Detection (if/when available)
ML Kit's hand landmark detection is available on Android via:
```yaml
google_mlkit_hand_landmark_detection: ^0.1.0  # check pub.dev for latest
```

### Option C: Platform channel to MediaPipe native SDK
Write a platform channel that calls the native MediaPipe Android/iOS SDK directly.

---

## 📱 Testing Tips

- Use **good lighting** facing your hand
- Keep hand **within frame** and centered
- Hold signs steady for ~0.7 seconds to confirm
- Front camera works best (mirrored like your web version)
- If detection seems off, switch to **A–Z mode** and try individual letters first

---

## 🐛 Known Limitations

- ML Kit Pose only gives 4 hand points (wrist + 3 fingertips). The 21-point hand
  model is **interpolated**, so complex signs requiring individual finger positions
  may be less accurate than the MediaPipe Holistic web version.
- First run downloads the ML Kit model (~20 MB) — needs internet connection.
- iOS TTS voice quality depends on the device's installed voices.

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `camera` | Live camera feed |
| `google_mlkit_pose_detection` | Hand/pose landmark detection |
| `flutter_tts` | Text-to-speech |
| `permission_handler` | Runtime camera permission |
