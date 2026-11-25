# WORK ORDER: SESSION 21 — Live Mission Prep Flow & 2-Player LAN Lockstep Lobby
Repo: C:\TacPlan Shooter (GhostMan612/TacPlanShooter, branch: main, baseline: b22f33ff, 12/12 CI green)
Governing Law: Read RULES.md first. Full files only. Zero comments except the 4-line Genesis header. Typed GDScript everywhere. Pure autoload-free code under `scripts/sim/`. Keep all 12 Headless CI gates + `HYGIENE_COMMENTS=0` green.

## TRACK 1 — Live N64 Mission Prep Flow & Armory RP Loop (Do First)
Wire the 6 pre-mission N64 stages cleanly between `CampaignScreen` and `PlanningRoot` so players experience the full RTS-RPG loop:
`CampaignScreen` (select OP-01..OP-10) -> `MissionPrepScreen` (`Briefing` -> `Intel` -> `Roster` -> `Kit` -> `Team`) -> `PlanningRoot` (`Planning` -> `Execute` -> `AarScreen` -> RP saved in `ProgressionSave`).

### Target Files (Track 1)
- CREATE: `scenes/mission_prep.tscn` + `scripts/ui/mission_prep_screen.gd` (screen-space `CanvasLayer` hosting `MissionPrepFlow` + `MissionPrepPanels` with top breadcrumb tabs, `< BACK` / `NEXT >` / `DEPLOY TO PLAN` buttons, and portrait `720×1612` / `1080×1920` responsive layout)
- MODIFY: `scripts/ui/mission_prep_panels.gd`
  - `Briefing`: Populates live mission codename, objectives, floor count, and RP reward from the selected `data/maps/opXX_*.json`.
  - `Intel`: Displays hostiles/hostages/jammer counts, lighting, and floor summary.
  - `Roster`: Displays persistent operatives from `UnitProfile` / `ProgressionSave` with N64 5-Trait/5-Skill horizontal bar graphs, `HEALTHY`/`WOUNDED`/`KIA` status, optional `assets/portraits/opr_01..06.png` thumbnails (graceful fallback if absent), and select/deselect up to 4 operatives.
  - `Kit`: Lets players spend earned RP from `ProgressionSave` to unlock & equip Primary, Secondary, 2 Equipment slots (including Heartbeat Sensor, Flashbang, Frag, C4, Lockpick, Drone), Armor class (`Light`/`Medium`/`Heavy`), and Insertion Vehicle (`NONE`/`VAN`/`BEARCAT`/`HELO`), plus `"APPLY KIT TO SQUAD"`.
  - `Team`: Assigns selected operatives into `RED`/`BLUE`/`GREEN`/`GOLD` squads and promotes Team Leader (showing live `leadership` Tap-In cooldown bonus).
- MODIFY: `scripts/ui/campaign_screen.gd` & `scripts/ui/screen_router.gd`: Route campaign launch through `scenes/mission_prep.tscn` (keeping `Quick Operation` on `TitleScreen` as a fast-launch bypass straight to `planning.tscn`).
- MODIFY: `scripts/planning/planning_root.gd`: Accept the configured `SquadConfig` + `OperativeProfile` + `KitCatalog` loadouts + chosen vehicle/drone from `MissionPrepScreen` (falling back cleanly to default demo operatives when launched directly).
- MODIFY: `tests/scene_smoke.gd`: Add `mission_prep_flow_smoke` verifying `Briefing -> Intel -> Roster -> Kit (RP spend) -> Team -> PlanningRoot` handoff with zero errors.

## TRACK 2 — 2-Player LAN Lockstep Lobby (Co-op & Blind-Planning PvP)
Build the live Host/Join LAN lobby reusing Track 1's `Roster`/`Kit`/`Team` screens and re-enable `2-PLAYER` on `TitleScreen`.

### Target Files (Track 2)
- CREATE: `scenes/mp_lobby.tscn` + `scripts/ui/mp_lobby_screen.gd`:
  - Mode picker: `CO-OP ASSAULT (2vAI)`, `PVP: BREACHERS VS DEFENDERS`, `PVP: EXTRACTION SKIRMISH`.
  - Map picker (`op01`..`op10` + custom maps from `user://custom_maps/`), Planning Timer selector (`60s` / `90s` / `120s` for blind PvP), and Fair-Play Equal-RP Budget toggle.
  - `HOST LAN` (displays local LAN IP + port `7600`, calls `LockstepSession.host()`) and `JOIN LAN` (IP input field + `CONNECT`, calls `LockstepSession.connect_client()`).
  - Ready-check + `CommitReveal` SHA-256 hash exchange status indicator (`WAITING FOR PEER` -> `PLANS LOCKED` -> `HASH VERIFIED` -> `DEPLOY`).
- MODIFY: `scripts/ui/title_screen.gd`: Re-enable the `2-PLAYER (CO-OP / PVP)` button routing to `scenes/mp_lobby.tscn`.
- MODIFY: `scripts/planning/planning_root.gd`: Support `mp_session: LockstepSession` + `local_faction_id` (`0` = Breachers/Co-op, `1` = Defenders) so per-faction `FogLayer` isolation, `CommitReveal` plan lock-in, and 60 Hz `OverrideCommand` lockstep sync run cleanly in execution.
- CREATE: `tests/mp_lobby_harness.gd` (and add to `.github/workflows/headless-ci.yml`):
  1. Verify `CommitReveal` blind-plan hash match succeeds and tampered plan hash fails.
  2. Verify 2-peer simulated `LockstepSession` tick sync produces identical `SimWorld.state_hash()` across Faction 0 and Faction 1 with active Tap-In `OverrideCommand`s and per-faction `FogLayer` filtering.
  3. Verify `mp_lobby.tscn` instantiates cleanly with zero `ERROR|SCRIPT ERROR|Parse`.

## VERIFICATION GATES (Before Commit & Push)
1. `HYGIENE_COMMENTS=0` across all new/modified `.gd` files.
2. `parse_all.tscn`, `scene_smoke.tscn`, `determinism_harness.gd`, `mp_lobby_harness.gd`, and all existing harnesses pass locally with 0 errors.
3. Push to `origin/main` and verify all GitHub Actions Headless CI gates (`13/13` with `mp_lobby_harness`) pass green.
4. Build & verify Route A debug APK (`builds\TacPlan-debug.apk`, untracked) and test on **BLU `B160V`**: Campaign -> Mission Prep (`Briefing`..`Team`) -> `OP-01` -> AAR RP persistence, plus `Title -> 2-PLAYER -> Host/Join Lobby` screen layout.
