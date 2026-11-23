# RULES.md — TacPlan Shooter Operating Law
> **CANONICAL RULESET.** Every session MUST read this file before doing any work.
> If any other document contradicts this file, THIS FILE WINS.

---

## 1. ABSOLUTE RULES (never violated, no exceptions)

### 1.1 External directories are READ-ONLY
Never create, modify, move, or delete ANYTHING under these paths:
```
C:\pathfinder_god
C:\Recovery for All
C:\Sovereign Nodes
C:\sovereign_mantle
C:\sovereign_tagger*        (wildcard: covers sovereign_tagger, sovereign_tagger_bak, any variant)
```
- Reading and copying FROM them into `C:\TacPlan Shooter` is allowed.
- Tool homes (usage approved, do not reorganize):
  - `C:\android` — Android SDK/NDK/build-tools/emulator (`C:\android\sdk`). Feeds the USER's Android Studio builds. Never restructure.
  - `C:\src` — Flutter/Dart source & tools. NOT used by this project unless the user explicitly directs it.
  - `C:\venv-hub` — global Python venv (Python 3.14.x). Use AS-IS; **ask first** before installing packages INTO it or adding files to it.
- The ONLY writable work area is `C:\TacPlan Shooter`.
- When in doubt: copy out, edit inside.

### 1.2 Secrets and commercial data never enter the repo
- Never commit: `.env`, API keys, keystores (`*.keystore`, `debug.keystore`), `local.properties`, `export_presets.cfg` signing sections.
- Godot Android export signing config lives OUTSIDE the repo. Debug keystore stays in `%USERPROFILE%\.godot\`.

### 1.3 Git discipline
- **Stage by explicit path only.** `git add -A` / `git add .` are FORBIDDEN — they pull in unrelated work.
- Commits happen as part of an approved session workflow; never force-push, rebase public history, or delete branches unless explicitly asked.
- `blueprints\` and `_archive\` are intentionally gitignored — do not "fix" this.

### 1.4 No real-world sensitive data
No real person names, unit designations tied to real operations, or personal data in committed source, tests, or fixtures. Synthetic placeholders only (e.g., `OPR_SAMPLE_01`).

### 1.5 Nothing outside the project without approval
Do not install software, modify system settings, or write to new locations outside `C:\TacPlan Shooter` / the tool homes above without asking the user first.

---

## 1A. CONTEXT & OUTPUT DISCIPLINE

- Filter all terminal output; pipe for failures only (`Select-String "error|fail|ERROR"`), never ingest passing noise.
- No massive file reads — probe large data files with short scripts instead.
- Targeted verification only during development; full verification reserved for staged-commit checkpoints.
- Spawn subagents for deep exploration when available; return summaries, not raw dumps.
- Proactively compact context after each verified+committed phase.

---

## 2. DIVISION OF LABOR (binding)

1. **The agent COD ONLY.** The agent NEVER builds, exports, or ships binaries: no Godot export, no Gradle APK assembly, no AAB. The **USER builds and tests in Android Studio** (`C:\Program Files\Android\Android Studio`) using the SDK at `C:\android\sdk`.
2. **Lane ends at source correctness.** Agent gates are GDScript parse checks (`godot --headless --check-only` / script parse) and scene/resource consistency once Godot is installed. Anything that emits an APK/AAB/binary is out of scope.
3. **Verification hand-off:** After scaffolding code, state what the USER should expect when they build/run (e.g., "parse clean; first Gradle sync will download NDK artifacts"). If a device build breaks, debug from the USER's pasted error output, never by rebuilding locally.
4. Commit messages must not claim build success — only parse/test status.

---

## 3. PROJECT CONVENTIONS

1. **Full code only** — no partial snippets, no TODO stubs.
2. **No comments in code** — except the Genesis header every `.gd` file must carry:
   ```
   # ============================================================
   # As Above, So Below. As Within, So Without.
   # The Future Dictates the Past and the Past is Always Present.
   # ============================================================
   ```
3. **The blueprint is canon** for all gameplay/architecture numbers: `blueprints\architecture-blueprint-source.txt` (plain-text extraction of `Tactical Android Game Development.rtf`). Where implementation deviates, the deviation must be logged as a Decision in the BP's footer + CHANGELOG.
4. **Typed GDScript everywhere** (`class_name` + static typing); autoload singletons only for SimClock/EventBus. The simulation layer (`scripts\sim\`) is pure autoload-free code (D-018). Test entry points under `tests\` are exempt from `class_name`.
5. **Scene names are string-coupled**: any scene referenced by path in code or export presets must be updated in both places on rename.

---

## 4. TECHNICAL LAWS (from the blueprint — see CHECKPOINTS gotchas G1–G14)

| Law | Rule |
|-----|------|
| Renderer | `gl_compatibility` (OpenGL ES 3.0) ONLY — set for BOTH desktop and mobile in `project.godot`. Never Forward+, never Mobile-Vulkan. Prevents Vulkan init attempts on old chipsets. |
| Determinism | ALL simulation logic runs in `_physics_process()` at fixed 60 Hz. NOTHING gameplay-mutating in `_process()`. Rendering/UI read state, never mutate it (Command Query Separation). |
| RNG | Seeded `RandomNumberGenerator` instances only; seed saved in the mission snapshot. NEVER global `randi()`/`randf()`/`randomize()` inside simulation code. |
| Pathfinding | `AStarGrid2D` ONLY. `NavigationAgent2D`/`NavigationRegion2D` are BANNED (float nondeterminism + mobile perf). Grid cells integer-based (default 16×16 px). |
| Avoidance | NO RVO/local avoidance. Strict path adherence: intersecting plans collide and HALT. Poor temporal planning is penalized, not papered over. |
| World↔Grid | One central utility converts world↔cell coords. No scattered division math. |
| LOS | Rotational sweep-line visibility polygons (O(n log n)): 3 rays per obstacle vertex (center, ±0.00001 rad); parametric intersection valid iff T1 > 0 AND 0 < T2 < 1; angular sort → closed polygon. Never naive 360-ray casting. |
| Fog rendering | GPU-masked via SubViewport high-contrast render + Light2D/shader sampling. "Visited but unseen" = additive buffer texture at 50% opacity. NEVER per-tile CPU arrays. |
| MSAA | OFF everywhere, especially every SubViewport (Line2D antialiasing relies on MSAA → set `antialiased=false`; smooth lines via alpha-gradient UV textures instead). |
| Draw calls | Texture atlases mandatory for UI/sprites; `MultiMeshInstance2D` for repeated props (desks/chairs/debris). |
| FPS caps | `Engine.max_fps = 30` during Planning; 60 during Execution; restore on phase exit. Battery/thermal law. |
| Touch input | Route-draw pipeline: decimation (min-distance threshold) → `Curve2D` Bezier smoothing → `get_baked_points()` → `Line2D`. Alternative strict mode: tap-to-cell, A* computes the path. |
| UI modes | Strict modal design: Observation (pan/pinch) · Routing (long-press operative, camera finger-offset, PiP loupe) · radial Command Node menu along bottom arc. Progressive disclosure always. |
| Audio | Dynamic ducking of ambient bus on breach/explosions; randomized radio squelch + telemetry blips on UI ops; operative damage → heartbeat drives a LowPassFilter over the mix. |
| Long processes | Launch DETACHED (no `-Wait`) and poll logs — tool timeouts kill child processes. |
| Verification signal | Godot 4.0 `--quit` ALWAYS exits code 1, even clean (proven via empty-project control) — NEVER use exit codes as pass/fail; filter logs for `ERROR|SCRIPT ERROR|Parse` instead. |
| Parse-check scope | `--check-only --script` compiles standalone WITHOUT autoload globals — scripts referencing autoloads fail there by design; the project-level headless boot is the authoritative gate. |
| Class cache | Adding a NEW `class_name` breaks dependent-script compilation on the FIRST editor import afterwards ("Identifier not declared") — run the headless editor import TWICE before judging; second pass refreshes the global class cache. |

---

## 5. WORKFLOW LAW

### 5.1 Cold start (every session, in order)
1. Read `blueprints\SESSION_HANDOFF.md`
2. Read THIS file (`RULES.md`)
3. Read `blueprints\CURRENT_STATE.md` → `CHECKLIST.md`
4. Work from the relevant `blueprints\blueprint-sections\BP-*.md`

### 5.2 Session end (every session)
1. Update `blueprints\CHANGELOG.md` (top entry, dated)
2. Tick `blueprints\CHECKLIST.md`; flip gates in `blueprints\CHECKPOINTS.md`
3. Refresh `blueprints\CURRENT_STATE.md`; rewrite handoff "Where we are" + "Next actions"
4. **AUTO-COMMIT LAW (user-granted, standing):** commit completed phases WITHOUT asking. Stage by explicit path only, descriptive message citing gate status. Never commit `blueprints\`. Never claim build success.

### 5.3 Verification law
No checklist item is done until its checkpoint gate passes (see `blueprints\CHECKPOINTS.md`). Evidence before status flips. New work → define its gate first.

### 5.4 Scope law
Big dreams go into blueprint sections with phased plans first. Ship vertical slices; never let polish precede a passing play-test gate. The vertical slice of THIS game is: plan a two-operative breach with one go-code, execute it deterministically, watch it succeed or fail because of YOUR plan.

---
