# TacPlan Shooter

A pure top-down tactical planning game for Android, built in **Godot 4** (Compatibility renderer).

You are the commander, not the trigger-puller: draw insertion routes on a blueprint-style map,
assign stances (Blitz / Normal / Cautious), synchronized go-codes (Alpha / Bravo / Charlie),
tactical actions (flashbang, frag, gas, breach charges), and fields of fire — then commit the plan
and watch autonomous operatives execute it frame-perfectly, or fail because your timing was wrong.

Distills the pre-mission planning loop of Rainbow Six (1998) into a 2D asynchronous mobile loop:
ten meticulous minutes of planning on a commute, a frantic two-minute execution burst, instant
replay scrubbing to iterate.

## Architectural pillars (from the blueprint — see `blueprints/`)

1. **Strict determinism** via the Command Pattern + Command Query Separation; fixed 60 Hz physics
   tick; seeded RNG snapshots; replay = reset-and-feed.
2. **AStarGrid2D navigation** (integer grid, ~16 px cells) — no NavPoly floats, no RVO avoidance;
   intersecting plans collide and halt.
3. **True line-of-sight** — O(n log n) rotational sweep-line visibility polygons, GPU-masked fog of
   war with a "visited but unseen" memory layer.
4. **Touch-first UX** — modal interface (Observation / Routing / radial menus), decimated +
   Bezier-smoothed route drawing, finger-offset camera, magnifier loupe.
5. **Mobile-first performance** — OpenGL ES 3.0 Compatibility renderer, MSAA off, texture atlases,
   MultiMesh props, 30 FPS planning / 60 FPS execution battery caps.

## Repository map

```
├── RULES.md              ← CANONICAL OPERATING LAW (read first)
├── CLAUDE.md             ← agent guidelines
├── AGENTS.md             ← agent quick reference
├── project.godot         ← Godot 4 project root (portrait primary, gl_compatibility locked)
├── scenes\               ← Godot scenes (planning.tscn)
├── scripts\              ← autoload\, sim\, planning\
├── tests\                ← SceneTree harnesses & probes
├── android\              ← gitignored Gradle template (Route B currently blocked)
├── docs\                 ← BUILD-IN-ANDROID-STUDIO.md + supporting documentation
├── blueprints\           ← governance + engineering canon (gitignored by design)
│   ├── SESSION_HANDOFF.md          ← cold start entry point
│   ├── Tactical Android Game Development.rtf   ← THE source document
│   └── blueprint-sections\         ← BP-01 … BP-10 engineering specs
└── _archive\             ← retired material
```

## Build & test (human-owned)

Godot 4.x (Compatibility renderer) authors the project; Android debug APKs are exported via
Route A (direct Godot export) per `docs\BUILD-IN-ANDROID-STUDIO.md` (Route B Android Studio
Gradle builds are currently blocked on JDK/SDK template version alignment). Agents code and verify
parse-cleanliness only — see `RULES.md` §2.

## Status

M2 sim core + M3 planning v1; audit remediation S3. See `blueprints\SESSION_HANDOFF.md`.
