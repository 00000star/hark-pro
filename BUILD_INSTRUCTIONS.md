# Hark Pro Mobile — Build & CI/CD Guide 🚀📱

This document describes how to build, run, and distribute the **Hark Pro** mobile application, both locally and through automated cloud continuous integration (GitHub Actions).

---

## 🏗️ 1. GitHub Actions CI/CD Overview

Automated workflows are configured to build the release Android APK in the cloud with zero local Android SDK configuration required.

### Workflow Files
- **Root Repository Workflow**: [`.github/workflows/build_apk.yml`](file:///sdcard/Antigravity_Projects/hark_agent/.github/workflows/build_apk.yml)  
  Used when cloning the top-level `hark_agent` monorepo. Configured to build from the `mobile/` directory.
- **Standalone Mobile Subproject Workflow**: [`mobile/.github/workflows/build_apk.yml`](file:///sdcard/Antigravity_Projects/hark_agent/mobile/.github/workflows/build_apk.yml)  
  Used if the `mobile` folder is pushed or mirrored as a dedicated repository.

### What the Pipeline Does
1. **Runner**: Runs on `ubuntu-latest`.
2. **Java 17 (Temurin)**: Configures the Java Development Kit required for modern Gradle and Android builds.
3. **Flutter Stable**: Caches and sets up the latest stable Flutter SDK via `subosito/flutter-action@v2`.
4. **Android Platform Scaffolding**: Dynamically generates the Gradle wrapper and `android/` project structure if not committed (`flutter create --platforms=android .`).
5. **Dependency Resolution**: Runs `flutter pub get` to install all dependencies (`flutter_shaders`, `web_socket_channel`, etc.).
6. **APK Compilation**: Runs `flutter build apk --release` with Dart compiler optimization.
7. **Artifact Archiving**: Uploads the resulting release APK using `actions/upload-artifact@v4` under the artifact name **`HarkPro-Release-APK`**.

---

## ⚡ 2. How to Trigger Cloud Builds

### Method A: Automated Push
Any commit pushed to the `main` or `master` branches will automatically trigger the `Build Hark Pro APK` action.

### Method B: Manual Trigger (`workflow_dispatch`)
You can trigger a build at any time from the GitHub Web UI:
1. Navigate to your repository on GitHub.
2. Click on the **Actions** tab at the top.
3. In the left sidebar, click on **Build Hark Pro APK**.
4. Click the **Run workflow** dropdown on the right side.
5. Select your target branch (`main` or `master`) and click the green **Run workflow** button.

---

## 📦 3. Downloading and Installing the APK

Once the workflow run completes (typically 3–5 minutes):

1. Go to the **Actions** tab in your GitHub repository.
2. Click on the completed workflow run (marked with a green checkmark ✔️).
3. Scroll down to the bottom of the **Summary** page to the **Artifacts** section.
4. Click on **`HarkPro-Release-APK`** to download the artifact zip archive.
5. Unzip the file to find `app-release.apk`.

### Sideloading onto Android
- **Via ADB**:
  ```bash
  adb install app-release.apk
  ```
- **Via Direct Transfer**:
  Send `app-release.apk` to your Android device (Google Drive, Telegram, USB, or local download), open the file in the device's file manager, and allow "Install from Unknown Sources" when prompted.

---

## 💻 4. Local Build and Development Instructions

### Prerequisites
- **Flutter SDK**: `3.0.0` or higher (`flutter --version`)
- **Java JDK**: Version 17
- **Android SDK**: Command-line tools or Android Studio with Platform Tools
- **Connected Device or Emulator** (`adb devices`)

### Step-by-Step Build Commands

1. **Navigate to the mobile directory**:
   ```bash
   cd mobile
   ```

2. **Scaffold Android platform files** (if missing or freshly cloned):
   ```bash
   if [ ! -d "android" ]; then
     flutter create --platforms=android .
   fi
   ```

3. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

4. **Run in development mode (with Hot Reload)**:
   ```bash
   flutter run
   ```

5. **Build release APK locally**:
   ```bash
   flutter build apk --release
   ```
   The compiled APK will be generated at:
   ```
   mobile/build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 🌐 5. Connecting to the Hark Backend

Hark Pro Mobile connects to the Hark Computer-Use streaming engine for live MJPEG video and telemetry.

1. **Start the backend server**:
   ```bash
   python -m src.stream.server
   # or
   uvicorn src.stream.server:app --host 0.0.0.0 --port 8000
   ```

2. **Host Configuration in Hark Pro Mobile**:
   - **Android Emulator**: Use `http://10.0.2.2:8000` (points to host machine loopback).
   - **Physical Device**: Use your workstation's LAN IP address (e.g., `http://192.168.1.100:8000`). Make sure your firewall allows incoming connections on port `8000`.
   - **Endpoints used**:
     - Live MJPEG Stream: `GET /stream/video`
     - WebSocket Telemetry: `WS /ws/telemetry`
     - Task Controls: `POST /api/task`, `POST /api/task/pause`, `POST /api/task/resume`
