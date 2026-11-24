# BUILD-IN-ANDROID-STUDIO.md — TacPlan Shooter on YOUR phone
> **Route A (direct Godot export) is the default.** Godot packages the prebuilt Android template and uses the SDK to sign it. The Gradle and Android Studio workflow is Route B. Device verification is done on a handset.

## 0. What this produces

- Output: `builds\TacPlan-debug.apk` (gitignored)
- Target: Portrait (`1080×1920`), ARM64 (`arm64-v8a`), OpenGL ES 3.0 (`gl_compatibility`), package `com.tacplan.game`, debug-signed side-load.

## 1. One-time Godot editor setup

Open `C:\TacPlan Shooter\project.godot` in Godot. The clean-checkout build was verified with Godot `4.0.4.stable`, its matching export templates, and Android Build-Tools `33.0.2`.

- **Export templates:** In **Editor → Manage Export Templates…**, install templates matching the exact Godot editor version.
- **Android tools:** Install SDK platform-tools and build-tools with a working `apksigner`. `apksigner` needs Java available in the editor process environment. The Godot 4.0 documentation recommends OpenJDK 11.
- Open **Editor → Editor Settings → Export → Android** and set:

| Setting | Value |
|---|---|
| Android SDK Path | `C:\android\sdk` |
| Debug Keystore | `C:\android\keystores\tacplan-debug.keystore` |
| Debug Keystore User | `androiddebugkey` |
| Debug Keystore Pass | `android` |

## 2. Route A — Direct Godot APK export (default)

1. On a clean checkout, copy [export_presets.cfg.example](../export_presets.cfg.example) to `export_presets.cfg` in the project root. For an existing preset, check **Use Gradle Build** is off, **arm64-v8a** is on, **Package / Unique Name** is `com.tacplan.game`, and the Resources tab includes the non-resource filter `data/maps/*.json`. Keep your debug signing settings in Editor Settings.
2. Open **Project → Export…**, select **Android**, and click **Export Project…** with **Export With Debug** checked. Create `builds` if needed and save to `builds\TacPlan-debug.apk`.
3. From the project root in PowerShell, verify the APK signature and compare its map entries to the checked-out sources.

```powershell
$apk = (Resolve-Path .\builds\TacPlan-debug.apk).Path
& C:\android\sdk\build-tools\33.0.2\apksigner.bat verify --verbose $apk
if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($apk)
try {
    $expected = @(Get-ChildItem .\data\maps\*.json | ForEach-Object { "assets/data/maps/$($_.Name)" })
    $packaged = @($archive.Entries.FullName | Where-Object { $_ -like "assets/data/maps/*.json" })
    if ($expected.Count -eq 0 -or $packaged.Count -eq 0 -or (Compare-Object $expected $packaged)) {
        throw "APK campaign maps differ from the checkout"
    }
} finally {
    $archive.Dispose()
}
```

## 3. Install on the device

On your Android phone: **Settings → About phone → tap Build Number ×7 → Developer Options → USB debugging ON**, then connect via USB and accept the RSA debugging prompt.

Run:
```powershell
C:\android\sdk\platform-tools\adb.exe install -r "C:\TacPlan Shooter\builds\TacPlan-debug.apk"
```

On launch, confirm splash and title, then open **Campaign** to check the map list. Open **Quick Operation (OP-01)** for the touch checks below.

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

- The original Godot `4.0.stable` template pins **Gradle 7.4**, **AGP 7.2.1**, **Java 11**, **compileSdk / targetSdk 32**, **Build-Tools 32.0.0**, and **NDK 23.2.8568313**. The official `4.0.4.stable` template uses **Gradle 7.4.2**, **compileSdk / targetSdk 33**, and **Build-Tools 33.0.2** with the same AGP, Java, and NDK versions. Check the generated `android\build\config.gradle` and `gradle\wrapper\gradle-wrapper.properties` for your template.
- This machine has **JDK 25** at `C:\android\Android Studio\jbr` (note: `C:\Program Files\Android\Android Studio\jbr` is broken and missing `lib\jvm.cfg`). **Gradle 7.4 cannot run on JDK 25.**
- Installed SDK components under `C:\android\sdk`: platforms `24, 31, 33, 34, 35, 36, 36.1, 37.0`, build-tools `34.0.0–37.0.0`, and NDK `27.0–30.0` (platform 32, build-tools 32.0.0, and NDK 23.2.8568313 are absent).

**To unblock Route B later:** select JDK 11 for Gradle and install the Android SDK platform, build-tools, and NDK versions pinned by the generated template.

When unblocked, open **`C:\TacPlan Shooter\android\build`** (the folder containing `settings.gradle`) in Android Studio — **not** `android\`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Export button greyed out | Read the red warning lines at the bottom of the Export dialog and fix the matching setting in §1 (templates path, SDK path, or debug keystore path/user/pass). |
| Install fails with signature mismatch | Re-export with the same debug key used for the installed APK. |
| `adb` shows no devices | Re-plug the USB cable, unlock the phone, accept the USB debugging RSA prompt, and verify with `C:\android\sdk\platform-tools\adb.exe devices`. |
| App crashes on launch or during test | Capture and send `C:\android\sdk\platform-tools\adb.exe logcat -s godot` output; do not retry blind. |
