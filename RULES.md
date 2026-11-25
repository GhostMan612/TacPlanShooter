# RULES.md — TacPlan Shooter Operating Law
> **CANONICAL RULESET.** Every session MUST read this file before doing any work.
> If any other document contradicts this file, THIS FILE WINS.

---

## 1. ABSOLUTE RULES (never violated, no exceptions)

### 1.1 External directories are FULL ALLOW (2026-11-24, user-directed)
Full write access granted: the agent MAY create/modify/move/delete under all paths it listed:
```
C:\pathfinder_god
C:\Recovery for All
C:\Sovereign Nodes
C:\sovereign_mantle
C:\sovereign_tagger*        (wildcard covers sovereign_tagger, sovereign_tagger_bak, any variant)
```
- Tool homes are now fully usable: `C:\android`, `C:\src`, `C:\venv-hub` — use AS-IS (no reorganize).
- The writable work area includes every path above plus `C:\TacPlan Shooter`.

### 1.2 Secrets and commercial data — advisory only
- Soft rule: avoid committing `.env`, API keys, keystores (`*.keystore`, `debug.keystore`), `local.properties` — the agent MAY now commit them when the USER explicitly asks (FULL ACCESS grant).
- Godot Android export signing config lives OUTSIDE the repo. Debug keystore stays in `%USERPROFILE%\.godot\`.

### 1.3 Git discipline (FULL ALLOW, 2026-11-24)
- **Commits happen freely** on `main` after verified phases; no asking required unless the user objects. Never rebase public history unless explicitly asked.
- `blueprints\` is tracked in the remote repo so specs and work orders sync via `git pull`.

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

## 2. DIVISION OF LABOR (binding, FULL ACCESS mode — 2026-11-24 user grant)

1. **The agent CAN build binaries.** Extended user grant (2026-11-23, "yes, update RULES accordingly as well"): the agent MAY run Godot export and Gradle APK assembly — builds run in **Android Studio** (`C:\Program Files\Android\Android Studio`) using the SDK at `C:\android\sdk`; the agent MAY also run direct Godot exports. The **USER still builds and tests** the APK on devices; artifacts are untracked.
2. **Lane ends at source correctness (by default).** Agent gates are GDScript parse checks (`godot --headless --check-only` / script parse) and scene/resource consistency once Godot is installed. Artifacts (.apk/.aab) are user-built; the agent never commits binaries (keystores stay outside the repo).
3. **Verification hand-off:** After scaffolding code, state what the USER should expect when they build/run (e.g., "parse clean; first Gradle sync will download NDK artifacts"). If a device build breaks, debug from the USER's pasted error output.
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
| Determinism | ALL simulation logic runs in `_physics_process()` at fixed 60 Hz. NOTHING gameplay-mutating in `_process()`. Rendering/UI read state, never mutate it (Command Query Separation). Live Tap-In Direct Control (Decision D-TAPIN-01) is permitted only by recording quantized per-tick `OverrideCommand` records into the 60 Hz simulation command stream so replays remain deterministic.  
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
4. **AUTO-COMMIT LAW (user-granted, standing):** commit completed phases WITHOUT asking. Stage by explicit path only, descriptive message citing gate status. Tracked specs/work orders in `blueprints\` may be pulled and committed by explicit path. Never claim build success.

### 5.3 Verification law
No checklist item is done until its checkpoint gate passes (see `blueprints\CHECKPOINTS.md`). Evidence before status flips. New work → define its gate first.

### 5.4 Scope law
Big dreams go into blueprint sections with phased plans first. Ship vertical slices; never let polish precede a passing play-test gate. The vertical slice of THIS game is: plan a two-operative breach with one go-code, execute it deterministically, watch it succeed or fail because of YOUR plan.

---
