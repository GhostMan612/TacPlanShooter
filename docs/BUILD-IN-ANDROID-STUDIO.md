# BUILD-IN-ANDROID-STUDIO.md — TacPlan Shooter on YOUR phone
> Agent codes; YOU build. This document never changes that. Follow top-to-bottom once; afterwards only step 4 repeats.

## 0. What this produces

`builds\TacPlan-debug.apk` — portrait, ARM64, OpenGL ES 3.0, package `com.tacplan.game`, pure touch controls. Installs alongside anything; it's a debug-signed side-load.

## 1. One-time Godot editor setup (~2 minutes)

Open `C:\TacPlan Shooter\game\project.godot` in Godot (double-click project.godot or use the project manager).

Then **Editor → Editor Settings → Export → Android** and set exactly two paths:

| Setting | Value |
|---|---|
| Java SDK Path | `C:\Program Files\Android\Android Studio\jbr` (Studio's bundled JDK) |
| Android SDK Path | `C:\android\sdk` |

If a red "debug keystore" warning appears: click **Auto-generate** (or leave defaults — Godot creates `%USERPROFILE%\.android\debug.keystore`). NEVER commit any keystore — `game\export_presets.cfg` and keystores are already gitignored.

## 2. Install the Gradle build template (one-time)

**Project → Export… → select the "Android" preset → click "Install Gradle Build Template"** → accept.

This creates `game\android\` (gitignored by design). It is the Android Studio project source of truth.

## 3. Two routes to an APK

### Route A — fastest first boot (Godot exports directly)
1. Same Export dialog → **Export Project…** → keep "Export With Debug" checked → save to `builds\TacPlan-debug.apk`.
2. Done. Skip to step 5.

### Route B — Android Studio (the standing workflow)
1. Open **Android Studio → Open → `C:\TacPlan Shooter\game\android`**
2. Let Gradle sync finish (first sync downloads dependencies; a warm cache from prior projects helps).
3. **Build → Build App Bundle(s)/APK(s) → Build APK(s)** → APK lands in `game\android\app\build\outputs\apk\debug\`.

## 4. After ANY code change meant for the phone

Re-export/re-build using Route A or B. There is no hot-reload between PC and phone.

## 5. Install on the device

Enable Developer Options + USB debugging on the phone, then either:
- Android Studio: press **Run ▶** with the phone connected (Route B), or
- `C:\android\sdk\platform-tools\adb.exe install -r <path-to-apk>` (both routes)

Launch **TacPlan Shooter** — expect: portrait, dark blueprint grid map, grey operative circles labelled 0 and 1.

## 6. What to test first (CP-030 feel verdict)

1. Drag anywhere → map pans, clamped to map bounds
2. Two-finger pinch (or mouse wheel on PC preview) → ortho zoom
3. Long-press ON an operative circle (hold ~½ second) → it highlights cyan, status prints `[PLAN] routing op N`
4. Drag a route → smooth cyan polyline follows the finger (raw jitter is decimated + Bezier-smoothed)
5. Release → `[PLAN] op N route committed: … waypoints`
6. Report: pan inertia feel, long-press radius comfort, polyline smoothness, any missed gestures

Paste back console/logcat lines beginning `[PLAN]` plus your verdict sentences — those flip CP-030.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Invalid package name" on export | Confirm preset package is `com.tacplan.game` (D-010 still open if you want a different id — say the word) |
| Gradle sync fails: SDK location | `game\android\local.properties` should contain `sdk.dir=C:\\android\\sdk` (file is gitignored; recreate by hand if needed) |
| Gradle sync fails: JDK mismatch | Use Studio's JBR path from step 1; File → Settings → Build tools → Gradle → Gradle JDK = Embedded JDK |
| First sync very slow | Normal — dependency downloads; later syncs are fast (warm `%USERPROFILE%\.gradle` cache) |
| APK installs but crashes at boot | Send logcat filtered on `TacPlan` + `godot`; do NOT retry blind |
