# Release Signing — v1.0.0-rc1

Signing credentials are **never committed**. Generate a local keystore (USER-owned, outside the repo):

```
keytool -genkeypair -v -keystore $env:TPS_KEYSTORE_PATH -alias tacplan -keyalg RSA -keysize 2048 -validity 10000
```

Set env vars before release builds: `TPS_KEYSTORE_PATH`, `TPS_KEYSTORE_USER`, `TPS_KEYSTORE_PASS`, `TPS_KEY_PASS`.

Run `powershell -File tools/build_release.ps1 -Target android-aab` (or `-Target android-apk`). Output goes to gitignored `builds\TacPlan-1.0.0-release.aab`; the script verifies with `apksigner verify` / `jarsigner -verify` and prints SHA-256.

**Play Console checklist:** Target API 35/36, 16 KB page-size support. If the Console requires a newer NDK/API than Godot 4.0.4 provides, upgrade to Godot 4.3/4.4 LTS and re-run all headless gates before resubmission.
