# Artist Studio Workbench Implementation Plan

> **For agentic workers:** Implement this plan task-by-task and use the checkbox (`- [ ]`) steps for tracking.

**Goal:** Add a self-contained Godot debug scene that lets artists switch real route/shop/battle visual states and replay existing battle VFX without entering the player flow.

**Architecture:** `ArtistPreviewCatalog` creates an isolated `YsbzsState` per preset and uses existing commands only to obtain an authentic snapshot. `ArtistStudio` instantiates the existing player scene, replaces its controller state with that isolated state, and adds a debug-only control strip outside the artist canvas. It calls the public battle UI smoke API for VFX samples rather than changing any artist or battle controller.

**Tech Stack:** Godot 4.7, GDScript, existing `ysbzs_singleplayer.tscn`, `artist_ui_middle_controller.gd`, `battle_ui_controller.gd`, SceneTree smoke tests.

---

### Task 1: Add isolated preview-state catalog

**Files:**
- Create: `debug/fixtures/artist_preview_presets.json`
- Create: `core_ui/scripts/debug/artist_preview_catalog.gd`
- Test: `tests/features/smoke_artist_studio.gd`

- [ ] **Step 1: Write the failing smoke assertion**

```gdscript
var catalog := ArtistPreviewCatalogScript.new()
for preset_name in [&"route_default", &"shop_stocked", &"battle_opening"]:
    var preview_state := catalog.create_state(preset_name)
    if preview_state == null or Dictionary(preview_state.snapshot()).is_empty():
        push_error("Artist Studio preset %s did not create a snapshot." % preset_name)
        quit(1)
        return
```

- [ ] **Step 2: Run the smoke to verify it fails**

Run: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/features/smoke_artist_studio.gd`
Expected: FAIL because `ArtistPreviewCatalogScript` and the preset file do not exist.

- [ ] **Step 3: Implement the catalog**

```gdscript
func create_state(preset_name: StringName) -> RefCounted:
    var state := YsbzsStateScript.new()
    state.set_run_seed(String(_preset(preset_name).get("seed", DEFAULT_SEED)))
    match preset_name:
        &"shop_stocked": _choose_first_kind(state, "shop")
        &"battle_opening": state.dispatch({"type": "START_BATTLE"})
    return state
```

`_choose_first_kind()` must select an existing matching route option from `state.snapshot()["route_options"]`; it must never hardcode an option id. JSON defines the display label, seed and requested phase for each preset.

- [ ] **Step 4: Re-run the smoke**

Run: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/features/smoke_artist_studio.gd`
Expected: catalog can create route, shop and battle snapshots.

### Task 2: Add the Artist Studio debug harness and controls

> 2026-07-27 structure update: this historical plan originally created a third debug `.tscn`. The current contract has exactly two Scenes and four prefabs, so Artist Studio is now a script-driven harness over the two formal Scenes, not another Scene or prefab.

**Files:**
- Create: `core_ui/scripts/debug/artist_studio.gd`
- Modify: `tests/features/smoke_artist_studio.gd`

- [ ] **Step 1: Extend the smoke with failing scene assertions**

The smoke directly instantiates the two formal Scenes and calls the debug harness script; it must not create another `.tscn`.

- [ ] **Step 2: Run the smoke to verify it fails**

Run: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/features/smoke_artist_studio.gd`
Expected: FAIL before the debug harness exists.

- [ ] **Step 3: Implement the scene and controller**

```gdscript
func debug_apply_preset(preset_name: StringName) -> Dictionary:
    var preview_state := _catalog.create_state(preset_name)
    _middle.set("state", preview_state)
    _middle.call("_render_from_state")
    return {"preset": preset_name, "phase": preview_state.snapshot().get("phase", "")}
```

The scene instances `res://art/scenes/three_choice/three_choice_scene.tscn` full-rect. The script adds a debug-only `HBoxContainer` with route, shop, battle and VFX buttons above/outside the artist canvas. It must not change any node in `artist_flow` or `battle_flow` and it must not add visible text onto the artist surfaces.

- [ ] **Step 4: Re-run the smoke**

Run: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/features/smoke_artist_studio.gd`
Expected: `route_default`, `shop_stocked`, and `battle_opening` switch the embedded real UI to the expected phases.

### Task 3: Connect reusable VFX sample preview and validate visibly

**Files:**
- Modify: `core_ui/scripts/debug/artist_studio.gd`
- Modify: `tests/features/smoke_artist_studio.gd`
- Create: `debug/fixtures/artist_motion_catalog.json`

- [ ] **Step 1: Add the failing VFX smoke assertion**

```gdscript
studio.debug_apply_preset(&"battle_opening")
var vfx_result := Dictionary(studio.call("debug_play_motion", &"prefab_samples"))
if not bool(vfx_result.get("started", false)):
    push_error("Artist Studio should trigger the existing battle VFX prefab sample API.")
    quit(1)
    return
```

- [ ] **Step 2: Run the smoke to verify it fails**

Run: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/features/smoke_artist_studio.gd`
Expected: FAIL because `debug_play_motion` is absent.

- [ ] **Step 3: Implement minimal motion dispatch**

```gdscript
func debug_play_motion(motion_name: StringName) -> Dictionary:
    if motion_name != &"prefab_samples" or _battle_view == null:
        return {"started": false}
    var summary := Dictionary(_battle_view.call("run_prefab_reuse_smoke"))
    return {"started": not summary.is_empty(), "summary": summary}
```

`artist_motion_catalog.json` exposes only `prefab_samples` in phase one. This deliberately reuses the existing public battle UI API and makes no controller or prefab modifications.

- [ ] **Step 4: Run all required verification**

Run:

```bash
/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/features/smoke_artist_studio.gd
open -n /Users/ywh/Downloads/Godot.app --args --path /Users/ywh/Documents/godot --editor
```

Expected: editor import passes, smoke prints `SMOKE_ARTIST_STUDIO_OK`, and the two formal Scenes remain the only `.tscn` entrypoints.

- [ ] **Step 5: Commit and close out**

```bash
git add art/scenes/debug/artist_studio.tscn core_ui/scripts/debug/artist_studio.gd \
  core_ui/scripts/debug/artist_preview_catalog.gd tests/features/smoke_artist_studio.gd \
  debug/fixtures/artist_preview_presets.json debug/fixtures/artist_motion_catalog.json \
  tasks/doing/2026-07-12_artist-studio-workbench.md
git commit -m "feat: add artist studio workbench"
```

Then record validation evidence, move the task card to `tasks/done/`, and refresh the task index only if its current unrelated changes have been committed by its owning task.

## Plan self-review

- Spec coverage: page switching, isolated state, VFX preview, no-art-change boundary, smoke and visible validation are covered by Tasks 1–3.
- Scope: phase one intentionally excludes timeline authoring, preview persistence, standalone export and controller refactors.
- Interfaces: `create_state()`, `debug_apply_preset()` and `debug_play_motion()` are defined before their callers.
