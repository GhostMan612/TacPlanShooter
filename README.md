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
├── blueprints\           ← governance + engineering canon (gitignored by design)
│   ├── SESSION_HANDOFF.md          ← cold start entry point
│   ├── Tactical Android Game Development.rtf   ← THE source document
│   └── blueprint-sections\         ← BP-01 … BP-10 engineering specs
├── game\                 ← Godot 4 project root (created in M1)
├── docs\                 ← supporting documentation
└── _archive\             ← retired material
```

## Build & test (human-owned)

Godot 4.x (Compatibility renderer) authors the project; Android debug/release builds are produced
by the human in **Android Studio** against the SDK at `C:\android\sdk`. Agents code and verify
parse-cleanliness only — see `RULES.md` §2.

## Status

Foundation day. See `blueprints\SESSION_HANDOFF.md`.
