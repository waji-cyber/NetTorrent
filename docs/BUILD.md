# NetTorrent — Build Guide (Windows + Android)

## 1. Prerequisites

| Tool | Minimum | Notes |
|---|---|---|
| Flutter SDK | **3.22** (Dart **3.4** bundled) | https://docs.flutter.dev/get-started/install — add `flutter` to PATH |
| git | any recent | Needed by `flutter` itself |
| Android build | Android Studio **or** command-line tools + Android SDK (API 34), JDK 17 | Set `ANDROID_HOME` / `ANDROID_SDK_ROOT`; accept licenses with `flutter doctor --android-licenses` |
| Windows build | **Visual Studio Build Tools** with the "Desktop development with C++" workload | `flutter doctor` must show a green check for Windows desktop |

Verify everything before you start:

```bat
flutter doctor
```

Every category you plan to build (Windows, Android) should show `[✓]`.

## 2. First-time setup: generate the platform folders

This repo ships the Dart code (`lib/`), assets, and docs. The native
`android/` and `windows/` folders are generated on your machine so the
Flutter version always matches your SDK:

```bat
cd nettorrent
flutter create --platforms=windows,android --org com.example .
flutter pub get
```

`flutter pub get` downloads the dependencies from `pubspec.yaml`
(`flutter_riverpod`, `dio`, `dtorrent_task_v2`, `shelf`, … — see
`DEPENDENCIES.md` / the license section of the report for the full list).

## 3. Verify the code

```bat
flutter analyze      :: static analysis — must report "No issues found"
flutter test         :: unit + widget tests in test/
```

Run these after every change. The project rule is: nothing is "done" until
`flutter analyze` and `flutter test` pass on the student's machine.

## 4. Run in debug mode

```bat
flutter run -d windows     :: desktop window on your PC
flutter run -d android     :: needs a connected device or running emulator
```

List available devices any time with `flutter devices`.

## 5. Release builds

```bat
flutter build windows --release
flutter build apk --release
```

### Where the outputs land

| Build | Output |
|---|---|
| Windows | `build\windows\x64\runner\Release\` — `NetTorrent.exe` plus its DLLs/data folder; zip the whole folder to distribute |
| Android | `build\app\outputs\flutter-apk\app-release.apk` — installable APK (enable "Install unknown apps" for your file manager / `adb install`) |

> The APK is signed with the debug key by default. For Play Store or wider
> distribution you must create a release keystore and add a
> `key.properties` — out of scope for this university build; document it as a
> limitation.

## 6. Browser extension

No build step needed — it is plain HTML/JS. Load it unpacked from
`browser-extension/` (see `browser-extension/README.md`), then pair the token
from NetTorrent → Settings.

## 7. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `flutter doctor` shows `X` for Windows | Install VS Build Tools with "Desktop development with C++"; reboot |
| `flutter doctor` shows `X` for Android | Set `ANDROID_HOME`; run `flutter doctor --android-licenses`; install API 34 + build-tools in SDK Manager |
| `flutter pub get` fails | Check network / proxy; `flutter pub cache repair` as a last resort |
| `flutter build apk` fails on signing | Expected for release keystore — use `--debug` APK for class demos, note the limitation |
| Bridge/extension shows "Not running" | Start the NetTorrent desktop app first; check nothing else uses port 17846 (`netstat -ano \| findstr 17846`) |
| Android "Share → NetTorrent" missing | Intent filters are documented in `PLATFORM_INTEGRATION.md`; verify them after `flutter create` regenerates `AndroidManifest.xml` |

## 8. Reproducibility notes for the report

- Record the exact `flutter --version` output on the build machine.
- Record SHA-256 of the release APK/EXE zip in the test report.
- Anything you could not run (e.g. no Android device available) must be marked
  **pending** in `TEST_PLAN.md`, never assumed to pass.
