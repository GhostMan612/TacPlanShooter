# BUILD-IN-ANDROID-STUDIO.md — TacPlan Shooter on YOUR phone
> **Route A (direct Godot export) is the default.** No Gradle, Java, or Android Studio build is needed. Agents code; YOU export and test on device.

## 0. What this produces

- Output: `builds\TacPlan-debug.apk` (gitignored)
- Target: Portrait (`1080×1920`), ARM64 (`arm64-v8a`), OpenGL ES 3.0 (`gl_compatibility`), package `com.tacplan.game`, debug-signed side-load.

## 1. One-time Godot editor setup

Open `C:\TacPlan Shooter\project.godot` in Godot (`C:\Godot\Godot_v4.0-stable_win64.exe`).

- **Export templates:** Already installed at `%APPDATA%\Godot\export_templates\4.0.stable\`. If Godot ever prompts for missing templates, open **Editor → Manage Export Templates… → Download and Install**.
- Open **Editor → Editor Settings → Export → Android** and set:

| Setting | Value |
|---|---|
| Android SDK Path | `C:\android\sdk` |
| Debug Keystore | `C:\android\keystores\tacplan-debug.keystore` |
| Debug Keystore User | `androiddebugkey` |
| Debug Keystore Pass | `android` |
| Java SDK Path | Not used by Route A |

## 2. Route A — Direct Godot APK export (default)

1. Open **Project → Export…** and select the **Android** preset.
2. Ignore any note about the Android build template not being installed — **Use Gradle Build** is OFF for Route A, so the prebuilt template APK is used directly.
3. Click **Export Project…**, keep **Export With Debug** ticked, and save to `builds\TacPlan-debug.apk`.

## 3. Install on the device

On your Android phone: **Settings → About phone → tap Build Number ×7 → Developer Options → USB debugging ON**, then connect via USB and accept the RSA debugging prompt.

Run:
```powershell
C:\android\sdk\platform-tools\adb.exe install -r "C:\TacPlan Shooter\builds\TacPlan-debug.apk"
```

Expected screen on launch: portrait view, dark blueprint grid, and two small grey circles labelled `0` and `1`.

## 4. Feel-test script (CP-030)

1. Pan stops at the map edges, with no dead zone when dragging back.
2. Pinch zooms around the point between the fingers.
3. Long-press turns the operative cyan and logs `[PLAN] routing op N`.
4. Dragging draws a smooth curve.
5. On release the line stays (dimmer) and logs `[PLAN] op N route committed`.
6. Do the second operative; both routes stay visible.
7. Send the log from `adb.exe logcat -s godot` plus a verdict for each step.

## 5. Route B — Android Studio Gradle build: BLOCKED

Route B is currently **BLOCKED** by a toolchain mismatch in Godot 4.0's Android template:

- The Godot 4.0 template in `android\build\` pins **Gradle 7.4**, **AGP 7.2.1**, **Java 11**, **compileSdk / targetSdk 32**, **buildTools 32.0.0**, and **NDK 23.2.8568313**.
- This machine has **JDK 25** at `C:\android\Android Studio\jbr` (note: `C:\Program Files\Android\Android Studio\jbr` is broken and missing `lib\jvm.cfg`). **Gradle 7.4 cannot run on JDK 25.**
- Installed SDK components under `C:\android\sdk`: platforms `24, 31, 33, 34, 35, 36, 36.1, 37.0`, build-tools `34.0.0–37.0.0`, and NDK `27.0–30.0` (platform 32, build-tools 32.0.0, and NDK 23.2.8568313 are absent).

**To unblock Route B later:** either install **JDK 11 or 17 + Android SDK platform 32 + build-tools 32.0.0 + NDK 23.2.8568313**, or upgrade the project off Godot 4.0 to a newer Godot 4.x release (decision pending).

When unblocked, open **`C:\TacPlan Shooter\android\build`** (the folder containing `settings.gradle`) in Android Studio — **not** `android\`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Export button greyed out | Read the red warning lines at the bottom of the Export dialog and fix the matching setting in §1 (templates path, SDK path, or debug keystore path/user/pass). |
| Install fails with signature mismatch | Uninstall the previous package first: `C:\android\sdk\platform-tools\adb.exe uninstall com.tacplan.game` |
| `adb` shows no devices | Re-plug the USB cable, unlock the phone, accept the USB debugging RSA prompt, and verify with `C:\android\sdk\platform-tools\adb.exe devices`. |
| App crashes on launch or during test | Capture and send `C:\android\sdk\platform-tools\adb.exe logcat -s godot` output; do not retry blind. |
