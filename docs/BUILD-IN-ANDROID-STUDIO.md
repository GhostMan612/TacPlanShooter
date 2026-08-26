# BUILD-IN-ANDROID-STUDIO.md — TacPlan Shooter on YOUR phone
> Agent codes; YOU build. Follow the RESCUE section first if the Export button is greyed out.

## RESCUE — fixing the greyed-out Export button (your exact 3 warnings)

| Warning you saw | Fix |
|---|---|
| "No export template found at …export_templates/4.0.stable/android_source.zip" | In that same dialog click **"Manage Export Templates"** → in the window that opens click **"Download and Install"** (top-right). ~1 GB download, needs internet, installs itself. Progress bar runs; wait for it. You only ever do this once per Godot version. |
| "Android build template not installed in the project." | **IGNORE IT FOR NOW.** The preset's "Use Gradle Build" checkbox is now OFF, so this is not needed for Route A. Only install it later if you want the Android Studio workflow (Route B): Project menu → Install Gradle Build Template. |
| "Debug keystore not configured…" | **DONE FOR YOU.** A debug keystore already exists at `C:\android\keystores\tacplan-debug.keystore`. Open Editor → Editor Settings → Export → Android and paste: Keystore Path = `C:\android\keystores\tacplan-debug.keystore` · User = `androiddebugkey` · Password = `android` |

After those three: back to **Project → Export…** → the **Export Project** button is now clickable.

## 0. What this produces

`builds\TacPlan-debug.apk` — portrait, ARM64, OpenGL ES 3.0, package `com.tacplan.game`, pure touch controls. Debug-signed side-load.

## 1. One-time Godot editor setup

Open `C:\TacPlan Shooter\project.godot` in Godot. Then **Editor → Editor Settings → Export → Android**:

| Setting | Value |
|---|---|
| Java SDK Path | only needed for Route B (Gradle). Set to `C:\Program Files\Android\Android Studio\jbr` when you get there. Route A ignores it — which is why you may not have noticed the box. |
| Android SDK Path | `C:\android\sdk` ✅ (you already did this) |
| Debug Keystore / User / Password | see RESCUE table above |

## 2–3. Routes to an APK

### Route A — fastest (current preset default)
1. **Project → Export… → Android preset → Export Project…** → keep *Export With Debug* checked → save as `builds\TacPlan-debug.apk`.
2. Done. No Gradle, no Android Studio, no Java involved.

### Route B — Android Studio standing workflow (later, optional)
1. Re-tick **Use Gradle Build** in the preset options.
2. Project menu → **Install Gradle Build Template** → accept (creates gitignored `android\`).
2. Project → Export… → Export Project (this fills that gradle project).
3. Android Studio → Open → `C:\TacPlan Shooter\android` → sync → **Build → Build APK(s)**.

## 4. Install on the device

Phone: Settings → About → tap Build Number ×7 → Developer Options → USB debugging ON. Then either:
- Android Studio Run ▶ (Route B), or
- `C:\android\sdk\platform-tools\adbinstall -r builds\TacPlan-debug.apk`

Launch **TacPlan Shooter**: portrait, dark blueprint grid, grey circles labelled 0 and 1.

## 5. Feel-test script (CP-030)

1. Drag → map pans, clamped at edges
2. Two-finger pinch → zoom
2. Long-press (~½ s) on an operative circle → cyan highlight + log `[PLAN] routing op N`
3. Drag a route → smooth cyan polyline (raw jitter decimated + Bezier-smoothed)
4. Release → `[PLAN] op N route committed: …`
5. Send me the `[PLAN]` lines + verdict sentences.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Export button STILL grey after templates | Check the message text again — each line maps to a row in the RESCUE table |
| Install fails "signature/certificate" over old build | Uninstall previous TacPlan first: `adb.exe uninstall com.tacplan.game` |
| Gradle sync fails: SDK location | `android\local.properties`: `sdk.dir=C:\\android\sdk` |
| Gradle sync fails: JDK mismatch | Use Studio's JBR path from step 1; File → Settings → Build tools → Gradle → Gradle JDK = Embedded JDK |
| First sync very slow | Normal — dependency downloads; later syncs are fast (warm `%USERPROFILE%\.gradle` cache) |
| APK boots then crashes | Send logcat filtered on `godot` + `TacPlan`; don't retry blind |
