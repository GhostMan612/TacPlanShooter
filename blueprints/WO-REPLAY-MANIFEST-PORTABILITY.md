# WORK ORDER: WO-REPLAY-MANIFEST-PORTABILITY
Repo: `C:\TacPlan Shooter` (GhostMan612/TacPlanShooter, branch: `main`)
Origin: reference audit of `C:\android\apk\doom` (two Freedoom/GZDoom APKs). Doom's transferable idea is the **demo file**: a versioned, shareable recording of inputs against a fixed-tick simulation. TacPlan already has the fixed-tick engine and in-memory reset-and-feed replay; it lacks a portable, integrity-checked artifact.
Governing Law: read `RULES.md` first. Full files only. Zero comments except the 4-line Genesis header in every `.gd`. Typed GDScript everywhere. `gl_compatibility`, `msaa_2d=0`, Nearest filtering. `scripts/sim/` stays pure `RefCounted`, autoload-free (D-018). No binary commits. `HYGIENE_COMMENTS=0`, `VERIFY_ASSETS PASS`, Headless CI green.

## OBJECTIVE
Add a shareable replay manifest: `schema_version` + tick-0 `MissionSnapshot` + tick-indexed external input stream + final `state_hash` + integrity hash, with export/import UI and deterministic verification. A manifest loaded on any device must reproduce the recorded mission bit-for-bit and prove it with a hash.

## 0. Scope and non-goals
- **In scope:** artifact schema, recorder, deterministic playback/verification, local storage + JSON/clipboard transfer, AAR save button, replay list screen, one new harness and gate `CP-104`.
- **Out of scope:** networked spectating, video capture, new command types, tick-indexed general `AgentCommand` injection, time-scale hitstop, changes to the 60 Hz sim contract.
- Planned commands are already embedded in the tick-0 snapshot via `SimOperative.queue` (`scripts/sim/sim_operative.gd:65`, `sim_world.gd:134-142`). The manifest must **not** duplicate them. `input_stream` carries only the two externally time-scheduled input types that actually exist: go-codes and Tap-In overrides.
- No real-world names or identifiers in fixtures or UI strings (RULES §1.4). Use `op0`/`op1`, `OPR_SAMPLE_01`.

## 1. Artifact schema — `scripts/sim/replay_manifest.gd`
`class_name ReplayManifest extends RefCounted`. Pure serialization and validation only; no `FileAccess`, no autoloads, no `ResourceSaver`.

```
{
  "manifest_format": "tacplan-replay",
  "schema_version": 1,
  "app_version": "1.0.0",
  "map_id": "op01_glass_house",
  "map_sha256": "<sha256 of canonical GreyboxMap.to_dict()>",
  "initial_tick": 0,
  "terminal_tick": 197,
  "initial_snapshot": { ...world.snapshot_data() captured at tick 0... },
  "input_stream": [
    {"kind": "go_code", "tick": 21, "seq": 0, "code": "ALPHA"},
    {"kind": "override", "tick": 34, "seq": 1, "data": { ...OverrideCommand.to_dict()... }}
  ],
  "final_state_hash": "<world.state_hash() at terminal_tick>",
  "journal_digest": "<sha256 of JSON.stringify(journal, "", true, true)>",
  "integrity_hash": "<sha256 of canonical JSON of all fields above>"
}
```

- `SCHEMA_VERSION: int = 1`; reject any other version with an explicit reason (future versions are not silently accepted). `REPLAY_FORMAT` is a fixed string gate.
- `static func create(world: SimWorld, initial_snapshot: MissionSnapshot, go_codes: Array, overrides: Array) -> ReplayManifest`: requires `world.tick == initial_snapshot.captured_tick + recorded_ticks`, `initial_snapshot.captured_tick == 0`; stores `final_state_hash = world.state_hash()` at the terminal tick.
- `func to_dict() -> Dictionary` and `static func from_dict(d: Dictionary) -> ReplayManifest`, both canonical: `JSON.stringify(d, "", true, true)` (sorted keys, full precision — the same canonicalizer used by `SimWorld.state_hash()`, `sim_world.gd:522-523`).
- `func compute_integrity() -> String`: SHA-256 of canonical JSON with `integrity_hash` removed. `func integrity_ok() -> bool` recomputes and compares. This is file-integrity (tamper/truncation), distinct from `final_state_hash` (simulation integrity).
- `static func validate(d: Dictionary) -> Array[String]`: returns reasons, never throws. Requires all keys above with correct types; `initial_tick == 0`; `1 <= terminal_tick <= MAX_TICKS`; every event `tick >= 1`, `kind` in `{go_code, override}`, `seq` unique and increasing, `code` a recognized go-code, `data` a valid `OverrideCommand.to_dict()` shape; hex hashes are 64 chars.
- Hard caps to prevent mobile ANR/DoS: `MAX_BYTES = 4 * 1024 * 1024`, `MAX_EVENTS = 4096`, `MAX_TICKS = 216000` (1 h at 60 Hz). Reject oversized manifests before full parse where possible.
- `map_sha256` is provenance/compat metadata only: the snapshot is self-contained (`restore_from_data` rebuilds map and floor slices at `sim_world.gd:461-470`), so a renamed map file does not break playback — surface a non-fatal warning when the map id/hash is unknown.
- `journal_digest` is an audit convenience for the AAR timeline; verification may check it but must not substitute it for `final_state_hash`.

## 2. Deterministic playback — `scripts/sim/replay_player.gd`
`class_name ReplayPlayer extends RefCounted`. Pure; consumes a `ReplayManifest` or raw arrays; no scene/autoload references.

Critical protocol (derived from the actual ingestion code — do **not** inject streams directly):
- `SimWorld.schedule_go_code()` appends `{"t": tick + 1, "code": ...}` and `_process_go_code_stream()` fires at that tick (`sim_world.gd:226-233`); `issue_go_code()` journals at the firing tick (`sim_world.gd:236-240`).
- `SimWorld.apply_override()` spends CP, sets cooldowns, increments bursts, appends a deep copy and journals `{"t": oc.tick, "ev": "override"}` **at call time**; `_process_overrides()` applies the effect only when `oc.tick == tick` (`sim_world.gd:159-224`).
- Therefore both event kinds must be **re-issued at `tick = event.tick - 1`** through the same public methods the live game used. Direct assignment into `world.go_code_stream` / `world.override_stream` (current `PlanningRoot.scrub_replay_to_tick`, L1452-1456) skips CP/cooldown/journal effects and cannot reproduce the hash.

```
static func replay_into(world: SimWorld, snapshot_data: Dictionary, events: Array, target_tick: int) -> void:
    world.restore_from_data(snapshot_data)
    sort events by (tick, seq)
    for e in events:
        if int(e["tick"]) > target_tick: break
        while world.tick < int(e["tick"]) - 1: world.step()
        if world.tick != int(e["tick"]) - 1: reject("event ordering")
        if e["kind"] == "go_code": world.schedule_go_code(StringName(String(e["code"])))
        else: world.apply_override(OverrideCommand.from_dict(e["data"]))
    while world.tick < target_tick: world.step()
```

- `static func verify(manifest: ReplayManifest) -> Dictionary`: `SimWorld.new()` → `replay_into(..., manifest.terminal_tick)` → compare `world.state_hash()` with `manifest.final_state_hash` (and `journal_digest`); return `{"ok": bool, "expected": ..., "actual": ..., "ticks": ...}`. `SimWorld.new().restore_from_data()` is self-contained — no `setup()` or map load needed (`sim_world.gd:454-519`).
- `static func from_manifest_events(manifest: ReplayManifest) -> Array[Dictionary]`: convert to the in-memory shape used by `PlanningRoot` so scrub and verification share one protocol.
- **Unify AAR scrub:** rewrite `PlanningRoot.scrub_replay_to_tick()` (L1449-1487) to call `ReplayPlayer.replay_into(world, _initial_snapshot.data, merged_stream, target_tick)`, merging `_recorded_go_codes` and `_recorded_overrides` into one tick-sorted stream. This closes the existing divergence where on-screen scrub cannot hash-match the original (`_test_override_replay` at `determinism_harness.gd:584-609` sidesteps it by restoring a post-application snapshot).
- Never use wall-clock time in the manifest. Key everything off `world.tick`; `SimClock.tick` is a separate counter (`sim_clock.gd:13`) and must not be used for replay.

## 3. Recorder — `scripts/planning/replay_recorder.gd`
- `static func capture(world: SimWorld, initial: MissionSnapshot, max_tick: int) -> ReplayManifest`: merge `world.go_code_stream.duplicate(true)` (`sim_world.gd:15`) and deep-copied `world.override_stream` (`sim_world.gd:22`) into the tick-sorted `input_stream`; call `ReplayManifest.create(...)`.
- Hook: `PlanningRoot._show_result()` already records `_recorded_go_codes`, `_recorded_overrides` and `_recorded_max_tick` (L1400-1440) — call the recorder there and cache the manifest on the root for the AAR `SAVE REPLAY` action.
- The manifest is created at mission end, never during `_process()`; sim mutation stays in `_physics_process()` (RULES §4 CQS law).

## 4. Storage, validation and `.bak` — `scripts/meta/replay_store.gd`
- `REPLAY_DIR := "user://replays"`; filename pattern `<safe_id>.json` where `<safe_id>` matches `[A-Za-z0-9_-]{1,64}` (reject path separators and `..`). Use `DirAccess.make_dir_recursive_absolute`, `FileAccess.open`, `store_string`, `get_as_text` — the same pattern as `MapEditorScreen.export_map/import_map` (L293-315).
- `save(manifest) -> String` writes canonical JSON atomically (`<id>.tmp` → remove existing → rename), recomputes `integrity_hash` before writing, then calls `verify()` as a self-check and refuses to save a manifest that fails its own hash.
- `load(path) -> ReplayManifest` runs size gate → `JSON.parse_string` → `validate()` → `integrity_ok()` → return; on any failure writes the raw text to `path + ".bak"` and returns an empty result with the reason (modeled on `ThemeManager.load_settings` L100-126 and `ProgressionSave.load_from_disk` L84-97). Do not partially apply a rejected manifest.
- `list() -> Array[Dictionary]` enumerates `*.json` with id, terminal tick, map id, schema and a verified flag; `remove(id)` deletes only sanitized names.
- Transfer: `copy_json(manifest)` / `paste_json()` use `DisplayServer.clipboard_set/get` when available, with a fallback to `user://replays/import.txt` for `adb push/pull`. Clipboard is best-effort; never a hard dependency.

## 5. UI
- `scripts/ui/aar_screen.gd`: add a `SAVE REPLAY` button beside `REPLAY` (L74) emitting `save_replay_requested`; add a small status label fed by the save result (`SAVED <id>` / `HASH MISMATCH - NOT SAVED`). Do not disturb `ReplayScrubber`, `scrub_label`, or the existing timeline layout assertions in `tests/scene_smoke.gd:249-251`.
- `scenes/replays.tscn` + `scripts/ui/replays_screen.gd`: `REPLAYS` button on `TitleScreen` (`scripts/ui/title_screen.gd:25-31`), screen built with `UiKit`/`ThemeManager`, listing local manifests with `WATCH` / `DELETE` / `IMPORT JSON` / `COPY JSON`. `WATCH` verifies first; on failure show the reason and do not enter playback.
- `scripts/planning/planning_root.gd`: add `play_manifest(manifest)` — restore tick-0 snapshot into the live world and drive `_physics_process()` from the manifest's `input_stream` (no human go-code/Tap-In input accepted), show a `REPLAY ✓` HUD badge, and let `AarScreen` continue to work. Route `ScreenRouter.Stage.REPLAYS` addition in `screen_router.gd:9` and keep all scene paths string-coupled in `export_presets.cfg.example`.
- Touch ergonomics: all buttons honor `ThemeManager.touch_min(...)`; no new overlays near the top-left tutorial strip (regression guarded by `scene_smoke`).

## 6. Tests and CI gate
- New `tests/replay_manifest_harness.gd` (`extends SceneTree`, `tests\` exempt from `class_name`), prints `[REPLAY] RESULT PASS failures=%d`. Fixtures are **generated in-process** — no binary files committed:
  1. `op01_glass_house` two-operative plan + one go-code + one Tap-In override; step to terminal tick; capture; round-trip through `to_dict`/`from_dict` and through `JSON.stringify`/`parse_string`; assert `integrity_ok()`, `final_state_hash` equality and `journal_digest` equality after `verify()`.
  2. `op05_penthouse_lock` multi-floor plan with `USE_STAIRS` (verifies floor slices and queue cursors survive the snapshot).
  3. Scrub parity: `replay_into(..., t)` for every sampled tick matches the original step-by-step `state_hash()` at the same tick (including CP/cooldown state after an override).
  4. Negative cases: tampered `final_state_hash`, bad `integrity_hash`, truncated JSON, `schema_version=2`, unknown `kind`, out-of-range tick, duplicate `seq`, oversized event count, path-traversal filename — all rejected with a reason, no crash.
- Add one step to `.github/workflows/headless-ci.yml` using the established pattern:
  `timeout 120 stdbuf -oL -eL ./bin/godot --headless --path . --script res://tests/replay_manifest_harness.gd 2>&1 | tee replay_manifest.log || true`
  then `bash tools/ci_gate.sh replay_manifest.log "[REPLAY] RESULT PASS"` (CI 27 → 28 steps).
- New `class_name`s trigger the first-import cache quirk (G16): run the headless editor import twice before judging parse failures.

## 7. Decisions and risk register
- **D-REPLAY-01:** manifest stores the full tick-0 snapshot (which embeds planned queues) and only tick-indexed go-codes/overrides as `input_stream`. No new `AgentCommand.tick` field; no duplicated plan representation.
- **D-REPLAY-02:** verification re-issues inputs via `schedule_go_code()` / `apply_override()` at `tick - 1`, never by direct stream injection. This is the only protocol that reproduces CP spend, cooldowns and journal events.
- **D-REPLAY-03:** `final_state_hash` is the hash of the *reconstructed terminal world*, not of the initial snapshot; `integrity_hash` is a separate file-level guard.
- **Risk:** `state_hash()` includes `tick`, `journal`, `go_code_stream`, `override_stream` and `tapin_*` (`sim_world.gd:365-426`); any divergence in event ordering or CP accounting fails verification. Mitigated by sharing one `ReplayPlayer` between scrub and verify.
- **Risk:** `AgentCommand.from_dict()` has no enum bounds validation (`agent_command.gd:39-51`); the manifest's `validate()` must reject unknown enums before any `from_dict` call.
- **Risk:** scrub is currently O(target_tick) with no checkpoints (`planning_root.gd:1463-1465`); acceptable for ~200-tick missions with the `MAX_TICKS` cap. Periodic checkpoint snapshots are explicitly deferred.

## 8. Acceptance gates (define before implementation — `CHECKPOINTS.md` rule 3)
| ID | Gate | Pass criteria | Evidence |
|----|------|---------------|----------|
| CP-104A | Manifest schema + integrity | Round-trip JSON identical; `integrity_ok()` true; bad schema/hash rejected | `replay_manifest_harness` cases 1, 4 |
| CP-104B | Replay fidelity | `verify().ok` true for normal + Tap-In + multi-floor; scrub parity at sampled ticks | `replay_manifest_harness` cases 1-3 |
| CP-104C | Hostile-input safety | All negative cases rejected without crash or partial apply | `replay_manifest_harness` case 4 |
| CP-104D | Device replay QA (**USER**) | On BLU `B160V` + Moto G 2025: save from AAR, list, import/paste, `WATCH` shows `REPLAY ✓`, scrub reproduces timeline, `godot:E` = 0 | screenshots + logcat, recorded verbatim |
| CI | Headless suite | 28/28 steps green, `HYGIENE_COMMENTS=0`, `VERIFY_ASSETS PASS failures=0`, `parse_all` PASS | Actions run + local gate log |

## 8.5 Phase 1 implementation notes (2026-11-28)
- Shipped `scripts/sim/replay_manifest.gd`, `scripts/sim/replay_player.gd`, `tests/replay_manifest_harness.gd` and the CI harness step. AAR/replay-list UI, `ReplayStore`, and `PlanningRoot` scrub unification remain Phase 2.
- **D-REPLAY-04:** `ReplayManifest.canonical()` is a deterministic hand-rolled serializer (sorted keys, integral floats emitted as integers) instead of a single `JSON.stringify` call. Godot's `JSON.parse_string` returns every number as `float`, so whole-number fields would otherwise render as `1.0` after a file round-trip and break `integrity_hash`.
- **D-REPLAY-05:** `rng_seed` and `rng_state` are stored as decimal strings inside `initial_snapshot`. `rng_state` is a signed 64-bit value and loses precision above 2^53 when parsed as a float; `restore_from_data()` already casts both through `int()`, so replay fidelity is preserved.
- **D-REPLAY-06:** `ReplayPlayer.replay_into()` returns `bool` rather than `void` so invalid event ordering is reported instead of silently producing a divergent world.
- **D-REPLAY-07:** the harness verifies size caps and schema/hash/event validation but does not intentionally feed truncated JSON to `JSON.parse_string`, because Godot logs `ERROR: Parse JSON failed` to stderr and the CI gate rejects any `ERROR:` line. Truncated-file handling belongs to `ReplayStore` (Phase 2), which pre-validates text before parsing.
- Godot 4.0 cannot bind private static methods as `Callable`s from a class reference inside static functions; sort comparators are inline lambdas.

## 9. Completion protocol
Update `blueprints/CHANGELOG.md` (top, dated), tick `blueprints/CHECKLIST.md` with an `M12 - Replay portability` section, flip CP-104A…D in `CHECKPOINTS.md`, refresh `CURRENT_STATE.md` and `SESSION_HANDOFF.md`, then auto-commit by explicit path (RULES §5.2). Never commit `builds/`, `*.apk`, `*.aab`, `*.keystore`. Do not claim build success in a commit message — gate status only.
