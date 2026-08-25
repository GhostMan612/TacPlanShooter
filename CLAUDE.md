# TacPlan Shooter - Claude/opencode Guidelines

You are working on **TacPlan Shooter** — a pure top-down tactical planning game for Android built in **Godot 4** (Compatibility renderer), distilling the Rainbow Six (1998) pre-mission planning loop into a 2D touchscreen experience. Absolute precision and deterministic architecture are required. Because the simulation core depends on replay-exact behavior, **architectural discipline outranks velocity**, and token conservation is your top operational priority.

Follow these workflow rules strictly:

## 1. CLI Execution & Testing
*   **Filter All Terminal Output:** Never read massive CLI outputs, full parse logs, or raw payloads directly into context. Pipe through failure filters.
*   **Targeted Verification:** Do not run full verification after every minor edit. Run targeted parse checks for the module you edited. Full gates run only when a commit is staged.
*   **NEVER BUILD BINARIES.** No Godot export, no Gradle packaging, no APK/AAB emission. The human builds and tests in Android Studio (SDK at `C:\android\sdk`). Your lane ends at source correctness: GDScript parse checks and static consistency.

## 2. Context Window & Token Management
*   **Use Native Subagents:** For deep file exploration or complex debugging, spawn a subagent; let it isolate heavy reading and return a concise summary.
*   **Proactive Compacting:** Automatically clear dead context after verifying and committing a distinct phase of work.
*   **No Massive File Reads:** Probe large data files with short scripts, never full reads.

## 3. Architecture Discipline (non-negotiable — see RULES.md §4)
*   **Determinism first:** every sim mutation lives in `_physics_process()` (60 Hz fixed tick). UI/render layers are read-only over game state (Command Query Separation).
*   **Commands, not actions:** planning-phase input constructs serialized command objects queued per operative; nothing executes until the Execution Phase starts.
*   **AStarGrid2D only. NavigationAgent2D banned. RVO avoidance banned.** Strict path adherence; intersecting paths halt.
*   **Seeded RNG only** in simulation; seeds live in mission snapshots (replay requirement).
*   **Compatibility renderer locked** in `project.godot` for desktop AND mobile targets.
*   **MSAA off everywhere** (SubViewports included); Line2D `antialiased=false` with alpha-gradient UV smoothing.
*   **FPS caps:** 30 planning / 60 execution via `Engine.max_fps`.

## 4. Data Handling
*   Synthetic data only — no real names/personal data in source or fixtures.
*   The canonical design source is `blueprints\architecture-blueprint-source.txt`. Deviations require a logged Decision.

## 5. Git Workflow
*   **Explicit Commits:** Only stage by explicit path. Never `git add .` or `-A`.
*   `blueprints\` and `_archive\` stay unversioned by design.
*   **Approval:** ~~Wait for explicit approval~~ **AUTO-COMMIT LAW (user-granted, standing):** commit finished work automatically after each verified phase/gate batch — no confirmation needed. Stage by explicit path; never `blueprints\`; never claim build success.
