# Battle Scene Presentation Boundary Specification

status: IMPLEMENTED_VERIFIED
baseline_date: 2026-08-03
task: `2026-08-03_battle-scene-presentation-boundary`

## 1. Outcome and invariant

`BattleArtScene` is a presentation Feature, not a combat authority or a debug harness. Its only page-level responsibilities are:

1. Bind authored responsibility roots.
2. Receive immutable public Snapshot values.
3. Stage and play ordered Trace presentation without exposing half-applied final state.
4. Lock/unlock presentation input around Trace playback.
5. Forward semantic user Command requests to `Game`; never submit to a Session itself.

The fixed runtime trunk remains:

```text
BattleArtScene input
  -> command_requested
  -> GameController
  -> GameSession
  -> YsbzsState
  -> Result / Trace / Snapshot
  -> BattleArtScene presentation
```

No UI module may own writable combat state, run damage formulas, call `YsbzsState`, create a `GameSession`, write save/replay/history, or infer authoritative results by comparing HP.

## 2. Live-source ruling

### 2.1 STS2 comparison

- `GameAction.cs` establishes that player input is a thin action boundary; damage, block and monster moves are internal Commands, not UI actions. **MIGRATE** the invariant through semantic `command_requested`.
- `CombatState.cs` owns combat state independently of its Godot nodes. **MIGRATE** the unique-authority boundary; do not put combat state in Scene controllers.
- `NCombatRoom.cs` and `NCombatUi.cs` demonstrate responsibility-specific presentation nodes, but also depend on static `CombatManager.Instance`. **ADOPT** the responsibility grouping and explicit visual lifecycle; **REJECT** the static-instance access shape because this project uses Session/Snapshot.
- `NSceneContainer.cs` owns only node replacement. **ALREADY ADOPTED** by `Game + SceneRouter`; BattleScene must not become a router.

### 2.2 Current implementation disposition

| Baseline source | Current responsibility | Disposition | Target owner |
|---|---|---|---|
| `battle_scene.gd:99-395` | wiring, Snapshot staging, Trace lifecycle | KEEP / NARROW | `BattleScene` root |
| `battle_scene.gd:396-607` | test/debug operations | DELETE FROM PRODUCTION | `tests/helpers/battle_scene_probe.gd`; debug Scene where needed |
| `battle_scene.gd:608-896` | board cells, pooling, rendering, geometry | MIGRATE | `BattleBoard` responsibility root |
| `battle_scene.gd:897-1685` | selection, drag, highlights, visual previews | MIGRATE | `BattleBoard` + pure `BattlePreviewPresenter` |
| `battle_scene.gd:1686-1959` | preview selection plus HP/shield arithmetic | SPLIT | selector to `BattlePreviewPresenter`; arithmetic removed; Mock adaptation to `MockGameSession` |
| `battle_scene.gd:1960-2068` | HUD actions and feedback | MIGRATE | authored `BattleHud` root |
| `battle_scene.gd:2075-2179` | detail prefab lifecycle and rendering | MIGRATE | authored `OverlayHost` root |
| `battle_scene.gd:2180-2317` | runtime debug command panel and command helpers | DELETE / MIGRATE | delete panel; production HUD/Board own real input; tests use probe |

File length is evidence of mixed change reasons, not an independent split gate.

## 3. Source-of-truth and integration order

The committed `/Users/ywh/Documents/godot-battle-ui-mock` is the presentation truth source. Implementation order is mandatory:

1. Preserve a clean Mock baseline and capture before evidence.
2. Implement and validate the responsibility split in Mock.
3. Commit Mock.
4. Import that committed Scene/HUD/script baseline into formal.
5. Add only formal Session/Snapshot/Trace adaptation and formal tests.
6. Validate and commit formal.

Formal must not maintain an alternate old 64-cell Scene after the Mock Scene is accepted. Mock must not receive formal state, repositories, save files, content packs or battle services.

## 4. Exact target contracts

### 4.1 `BattleScene` root

Path: `core_ui/scripts/battle/scenes/battle_scene.gd`

Required public surface:

```gdscript
signal command_requested(command: Dictionary)
signal trace_sequence_finished

func render_snapshot(snapshot: Dictionary) -> void
func play_battle_trace(events: Array) -> void
func get_runtime_view() -> Control
func is_battle_input_locked() -> bool
```

Allowed mutable presentation state:

- latest immutable Snapshot copy used only for current projection;
- `rendered_trace_count`;
- pending final Snapshot while Trace is playing;
- pending enemy-move final cells;
- input-lock flag.

Forbidden:

- `debug_*`, `run_prefab_reuse_smoke`, runtime debug button creation;
- cell/unit pools, drag state, detail state or damage-preview caches;
- static geometry/style creation;
- Session/authority access or damage arithmetic.

Required order for `render_snapshot`:

1. Derive new Trace events from `BattleTraceProjection`.
2. If events exist and a previous frame exists, retain the previous visible frame and stage the final Snapshot.
3. Render Board, HUD and Overlay from the chosen visible frame.
4. Lock input before Trace playback.
5. Play ordered Trace.
6. On completion, atomically render the staged final Snapshot, apply deferred enemy cells, then unlock input and emit `trace_sequence_finished`.

If VFX is unavailable, log the presentation failure, apply the final Snapshot immediately, clear pending state and unlock input. Never leave a half-staged frame.

### 4.2 `BattleBoard` responsibility root

Path: `core_ui/scripts/battle/scenes/battle_board.gd`

Attach to the existing `BattleArtScene/Board`; do not add another structural node.

Required signals and methods:

```gdscript
signal command_requested(command: Dictionary)
signal cell_detail_requested(grid: Vector2i, unit_id: String)

func configure(assets: RefCounted) -> void
func render_snapshot(snapshot: Dictionary, cells: Array, pending_reset_ids: Dictionary = {}) -> void
func set_input_locked(locked: bool) -> void
func show_direction_preview(unit_id: String, direction: String) -> void
func apply_enemy_move_final_cell(unit_id: String, cell: Dictionary) -> void
func reveal_reset_units(units: Array) -> void
func clear_transient_state() -> void
func board_dimensions() -> Vector2i
func rendered_cell_count() -> int
func missing_mapping_report() -> Array
```

Owner capabilities:

- existing CellHost/UnitHost/VfxHost references;
- cell and unit pools;
- rendering, hit testing, cursor, selection visuals, drag/tween lifecycle;
- local optimistic visual projection that is discarded/reconciled on the next authoritative Snapshot;
- attack-cell coordinate translation and clipping through `BattlePreviewPresenter`.

It may emit only public semantic commands (`SELECT_CELL`, `GET_CELL_DETAIL`, `MOVE_HERO`). It may not decide AP, range legality, damage, death or command acceptance. Invalid/missing authoritative preview hides the preview instead of inventing a fallback.

### 4.3 `BattlePreviewPresenter`

Path: `core_ui/scripts/battle/controllers/battle_preview_presenter.gd`

Extends `RefCounted`; owns no Node and no mutable Snapshot.

```gdscript
func action_cells_for_drag(snapshot: Dictionary, unit_id: String, target: Vector2i, dimensions: Vector2i) -> Array[Vector2i]
func direction_cells(snapshot: Dictionary, unit_id: String, direction: String, dimensions: Vector2i) -> Array[Vector2i]
func incoming_preview(snapshot: Dictionary, unit_id: String) -> Dictionary
func target_preview(cell_data: Dictionary, actor_id: String) -> Dictionary
```

It may select, de-duplicate, translate, rotate and board-clip cells already exported in Snapshot. It may return an existing preview Dictionary. It must not calculate attack values, resistance, shield damage, HP damage, `hpTo`, `shieldTo` or any balance value. Missing input returns `[]` or `{}`.

Delete from shared UI:

- `_project_exported_incoming_drag_preview()`;
- `_project_exported_drag_preview()`;
- mock template key lookup;
- all `min(current_shield, predicted_damage)` / HP subtraction fallback logic.

Mock-only responsiveness belongs in `session/mock_game_session.gd`, which may project captured public results into a new public Mock Snapshot but must still not execute formal combat rules.

### 4.4 `BattleHud`

Paths:

- `core_ui/scripts/battle/prefabs/hud/battle_hud.gd`
- `art/prefabs/battle/hud/battle_hud.tscn`

Required public surface:

```gdscript
signal command_requested(command: Dictionary)
signal direction_preview_changed(preview: Dictionary)

func render_snapshot(snapshot: Dictionary) -> void
func set_input_locked(locked: bool) -> void
```

The HUD owns authored buttons, difficulty feedback, action panel and direction drawer. It uses `BattleCommandBuilder` and `BattleHudController` only for semantic command/data projection. Static font, color, StyleBox, size and position values move into the authored HUD Scene/Theme; no `_style_position_difficulty_button()` runtime override remains.

Input lock disables all HUD command emitters. Auto-position pending is cleared only when the incoming Snapshot/result identifies the matching completed command; stale Snapshot values do not clear a newer pending request.

### 4.5 `BattleOverlay`

Path: `core_ui/scripts/battle/scenes/battle_overlay.gd`

Attach to existing `BattleArtScene/OverlayHost`.

```gdscript
func configure(assets: RefCounted) -> void
func request_detail(grid: Vector2i, unit_id: String) -> void
func render_snapshot(snapshot: Dictionary) -> void
func clear() -> void
func has_visible_detail() -> bool
```

It may instantiate the existing pet/terrain detail prefabs into `OverlayHost`; this is prefab lifecycle, not static layout construction. Baseline geometry must come from the prefab/Scene. It may use `BattleDetailController` to map Snapshot values, but may not request Session data or synthesize combat fields.

### 4.6 Test-only probe

Path: `tests/helpers/battle_scene_probe.gd`

The probe replaces production root `debug_*` methods. It locates `Board`, `Hud`, `OverlayHost` and `VfxHost`, drives their real production APIs/input signals, and returns test summaries. It must not be preloaded by production `art/**`, `core_ui/**`, `core/**` or `session/**`.

Existing tests that call root debug methods must migrate to the probe in the same atom. No compatibility debug forwarding methods remain on `BattleScene`.

## 5. Scene wiring

Mock `battle_art_scene.tscn` remains the authored topology:

```text
BattleArtScene        -> battle_scene.gd
  Board               -> battle_board.gd
    Background
    CellHost
    UnitHost
    VfxHost            -> battle_vfx_controller.gd
  Hud                  -> battle_hud.tscn / battle_hud.gd
  OverlayHost          -> battle_overlay.gd
```

No new wrapper/Slot/Anchor/HitArea node is allowed. No existing node may be renamed, moved or have its authored rect changed. Complex prefab instances remain dynamic only where the current Mock Scene already declares Host ownership.

## 6. Caller closure

Production callers to preserve:

- `game_controller.gd` connects `command_requested`, calls `render_snapshot`, mounts/releases the Feature.
- `three_choice_scene.gd` and `SceneRouter` may call `get_runtime_view()`.
- VFX signals: reset reveal, sequence started/finished, enemy move projection.
- HUD/action panel/direction drawer signals.

Non-production callers to migrate:

- all battle feature/integration tests calling `debug_*`, `has_required_asset_manifest`, `has_enabled_primary_buttons` or `run_prefab_reuse_smoke`;
- `artist_studio.gd` must call the debug VFX host from its debug-only context, not use a production BattleScene smoke method.

Dynamic call checks must be included in the source scan. Completion requires zero production references to removed root methods.

## 7. State, atomicity and compatibility

- Snapshot inputs are deep-copied only for transient presentation staging and never mutated as authority.
- Board optimistic drag is visual-only; command acceptance and the next Snapshot reconcile it.
- Trace event order and VFX await order are unchanged.
- `stateVersion`, `stateHash`, command log, replay timeline, save schema and content hash must be byte-for-byte unaffected by this UI refactor.
- Formal preview data comes only from existing public Snapshot fields such as `action_preview_by_unit`, `action_block_ranges_by_unit`, `placement_damage_by_unit`, cell preview/threat fields and `lastCommandResult`.
- Unknown/malformed preview values fail closed to no preview; they do not block ordinary Snapshot rendering.

## 8. Implementation atoms and rollback

1. **E0 evidence**: isolated clean before captures in Mock and formal; no code change. Rollback: discard evidence directory only.
2. **M1 Mock preview boundary**: add presenter, move captured fallback into MockSession, preserve Mock visible results. Rollback: revert M1 commit.
3. **M2 Mock responsibility roots**: Board/HUD/Overlay owners, narrow root, migrate Mock tests. Rollback: revert M2 while keeping M1 only if its tests pass.
4. **M3 Mock validation/commit**: all Mock structural and visible evidence; commit truth source.
5. **F1 formal import**: import committed Mock Scene/HUD/scripts without formal core changes. Rollback: revert F1.
6. **F2 formal adaptation/tests**: public Snapshot/Trace logging and test probe; delete old root/debug/dead code. Rollback: revert F2 and F1 together.
7. **F3 formal validation/commit**: focused, fast, five-operation preserve evidence and full battle recording.
8. **C closeout**: task archive/index commit. Rollback is independent of implementation commits.

Every atom must keep both repos parseable. Do not leave temporary forwarding methods or a dual old/new BattleScene implementation between commits.

## 9. Verification contract

### Structural

- Production `battle_scene.gd` contains none of: `func debug_`, `run_prefab_reuse_smoke`, `_ensure_command_tools`, `_project_exported_drag_preview`, `_project_exported_incoming_drag_preview`, `PanelContainer.new`, `Button.new`.
- Production BattleScene has no preload of `YsbzsState`, `GameSession`, damage resolver/service or test helper.
- Test probe has no production caller.
- Scene topology is exactly the hierarchy in section 5.

### Behavioral focused tests

- initial Snapshot renders configured dimensions and only changed cells update;
- selected unit range and direction hover remain visible;
- legal drag emits one `MOVE_HERO`, illegal/cancel drag emits none and restores visuals;
- detail request/open/close remains stable;
- Trace locks input, stages final Snapshot, plays movement/attack/damage/reset in order, applies final Snapshot once, then unlocks;
- missing preview produces no damage overlay and no error;
- Mock and formal public command/result interfaces remain unchanged;
- feature routing mounts/releases battle with no Session in the Scene.

### Required commands

Mock and formal script check-only, Mock mirror/project/Scene smokes, formal focused tests listed in the task card, formal `--suite fast`, and `git diff --check`.

### Visible preservation

Capture matching stable states before/after:

1. initial battle frame;
2. selected player pet with range/detail;
3. legal drag preview before release;
4. auto-position completed feedback;
5. direction drawer/preview or post-round stable frame.

Each pair must use the same entry, Snapshot/seed, viewport, scaling and stable timing. This refactor declares `preserve`; unexplained changed pixels are failure. Record continuous drag/Trace behavior. Formal validation continues through final battle settlement because the refactor touches the whole battle presentation lifecycle.

## 10. Completion definition

`IMPLEMENTED / VERIFIED` requires:

- Mock implementation committed and clean;
- formal implementation committed and target files clean;
- root surface and source scans pass;
- all required focused and fast tests pass now;
- Mock five-operation pixel preservation passes;
- formal five-operation preservation and complete formal-entry battle recording pass;
- no unrelated worktree content staged;
- task card archived with both commit IDs and evidence paths.

## 11. Implementation record

- Mock implementation authority is `4a861a47a53de59fca22b818d73b70e225c33ea7` plus the VFX-preservation follow-up `b9bdea25074426d24b4b2de1bf3ed4fe56cca26f`.
- Formal implementation is `a16c16da0abeebaec4bed82c6d98f0851e531e09`.
- The formal root is 184 lines and exposes only `render_snapshot`, `play_battle_trace`, `get_runtime_view`, and `is_battle_input_locked`; Board, HUD, Overlay, preview selection and test driving now have separate owners defined above.
- Twelve shared production presentation files are byte-identical between formal and Mock at `b9bdea2`; the formal-only Artist Studio adapter calls the debug VFX owner directly.
- Final baseline-to-HEAD audit at `57a83997d9cb5ce3cc8d7f0b2f0ad560ab979900` found only the already-integrated `smoke_shield_damage_feedback.gd` overlap from `3dbb4e9`/`6bcff91`; concurrent projector context was preserved (`REBASE_REQUIRED_RESOLVED`).
- Verification: changed-script check-only `44/44`; clean fast QA `15/15`; Mock and formal deterministic five-operation comparison `5/5` each with zero differing pixels; formal real-entry battle ran through `battle_end` and settlement; Mock real-entry mouse drag and captured public Trace completed.
- The final 33-test focused run is `29/33` runner-clean. The other four all emitted their test-specific `OK` sentinel and were marked failed solely because the shared worktree simultaneously contained uncommitted `core/battle/quality/**` errors matched by strict output. This external noise is recorded, not repaired or staged by this task.
