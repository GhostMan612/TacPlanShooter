# AGENTS.md — TacPlan Shooter

Godot 4 top-down tactical planning game (Android-first, pure planning-phase loop à la Rainbow Six 1998 / Door Kickers).
Read `CLAUDE.md` too — its §1–§5 (token conservation, filtered output, explicit-path commits,
determinism laws) are binding, and `RULES.md` WINS over everything.

## Hard boundaries (2026-11-24, user-directed — FULL ALLOW granted by the user; "push, pull, sync" is a go-ahead signal)

- **FULL ACCESS:** no read-only denies — the agent may read/write/build across `C:\pathfinder_god`, `C:\Recovery for All`, `C:\Sovereign Nodes`, `C:\sovereign_mantle`, `C:\sovereign_tagger*`, `C:\android`, `C:\src`, `C:\venv-hub`, and `C:\TacPlan Shooter`.
- `C:\venv-hub` — use AS-IS.
- **Repo changes:** commit by explicit paths; don't use `git add -A` unless explicitly told; never commit binaries.
- Copy FROM external dirs into this project as useful.
- **Binary builds:** user-granted (2026-11-23); agent builds only via direct Godot export and may run Gradle APK assembly in Android Studio; USER tests/runs the artifacts.
- **AUTO-COMMIT (user-granted, standing):** after each verified phase/gate batch, commit
  immediately without asking. Explicit paths only; never `blueprints\`.

## Commands (Godot 4.0-stable at `C:\Godot\Godot_v4.0-stable_win64_console.exe`)

```bash
godot --headless --path . --quit                             # AUTHORITATIVE gate: boot smoke (autoloads+scripts compile)
godot --headless --path . --check-only --script <res://…>    # per-script parse (fails on autoload refs by design — see G15)
```
Filter output for `ERROR|SCRIPT ERROR|Parse` only — **exit codes are NOT a signal**: Godot 4.0 `--quit`
always exits 1 even clean (proven via empty-project control). Launch long runs DETACHED and poll logs.

## Hard-won gotchas

- **PowerShell 5.1 corrupts UTF-8.** Never round-trip source files through
  `Get-Content | Set-Content`; `Set-Content -Encoding utf8` also writes a BOM that breaks `.tscn`
  ("Expected '['"). Use file tools; check first bytes when parse errors point at char 1.
- `.rtf` files are markup soup — extract text via .NET RichTextBox (`System.Windows.Forms.RichTextBox.Rtf = ...; .Text`)
  instead of regex stripping. Canonical extraction lives at `blueprints\architecture-blueprint-source.txt`.
- `blueprints\` is gitignored BY DESIGN (house rule inherited from sibling projects) — no history
  protection there; do not "fix".
- Simulation code must never touch `randi()`/`randf()`/`randomize()` globals — seeded
  `RandomNumberGenerator` only, seed persisted in the mission snapshot.
- Autoload singletons deliberately have NO `class_name` (avoids "class hides autoload" warnings);
  every other script gets one (`tests\` entry points exempt).
- The sim layer (`scripts\sim\`) is pure autoload-free RefCounted code — keep it that way;
  it must stay testable via `-s` SceneTree harnesses.
- First-import class-cache quirk (G16): a brand-new `class_name` referenced by existing scripts
  fails ONE headless editor import ("Identifier not declared") — run the import twice before judging.

## Architecture (the load-bearing wiring)

- Repo root (`project.godot` at root, `android\` beside it) — Godot 4 project root, Compatibility renderer forced desktop+mobile.
- Planning Phase (modal UI: Observation / Routing / radial node menu) constructs serialized
  `AgentCommand` objects in per-operative queues. Execution Phase consumes them in `_physics_process()`.
- Replay = initial mission snapshot + timestamped command array; reset-and-feed reproduces outcomes exactly.
- LOS = rotational sweep-line visibility polygons rendered through a masked SubViewport;
  visited-memory additive buffer at 50% opacity.

## Docs that are load-bearing

- `blueprints\SESSION_HANDOFF.md` — cold start entry point (read FIRST every session)
- `RULES.md` — operating law; §4 technical laws table is canon
- `blueprints\BLUEPRINTS.md` — index of BP-01…BP-10 engineering sections
- `blueprints\CHECKLIST.md` / `CHECKPOINTS.md` — what's next / evidence-gated status
- `blueprints\ROADMAP.md` — milestone ladder M0→M10
