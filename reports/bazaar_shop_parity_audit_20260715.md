# Bazaar Shop Parity Audit — 2026-07-15

## Scope and truth sources

- Project contract: `/Users/ywh/Documents/ysbzs/docs/BAZAAR_OUTER_LOOP_ACCEPTANCE.md`, especially merchant/stall/tag-pool, build growth, and player-comprehension requirements.
- Godot runtime truth: `scripts/game/ysbzs_state.gd`, `scripts/game/bazaar_info_panel.gd`, `scripts/game/artist_ui_middle_controller.gd`, and `data/ysbzs_singleplayer_data.json`.
- H5 reference only: `/Users/ywh/Documents/ysbzs/src/core/shop.cjs` and `src/core/inventoryRules.cjs`; user confirmed H5 is borrowed only when useful and is not a parity target.
- External mechanic references used only to identify exact-Bazaar follow-ups: The Bazaar Wiki item upgrade rules and Version 0.1.4 merchant reroll pricing notes.

## Fixed in this task

| Area | Before | Current result |
|---|---|---|
| Same-refresh duplicates | Fixed seed `ysbzs-test-play-20260715-v1`, context `route:1:2:node_shop_fire`, produced two `pal_009` Bronze offers in one shop. | Ordinary shop generation samples unique `pet_id` values without replacement. |
| Frozen reroll uniqueness | Frozen offers were kept, but their `pet_id` was still eligible for newly generated slots. | Frozen offers reserve their `pet_id`; the refreshed portion cannot repeat them. |
| Intentional duplication | Ordinary generation and explicit construction event duplication shared the same merge outcome but had no clear separation in acceptance. | Explicit `evt_duplicate` / construction duplication remains unchanged; only ordinary offer generation is deduplicated. |
| Refresh cost display | Core exposed `next_refresh_cost`, while the right panel read non-existent `cost` / `refreshCost` and fell back to `1`. | Existing `BazaarInfoPanel` now reads the core `next_refresh_cost`; initial paid refresh displays `2金币`. |
| Stall identity | Shop panel only said `商店`. | Existing right panel shows the current stall name and tag tendency. |
| Public quality | Shop summary showed name and price only. | Existing right panel shows `name · 青铜/白银/黄金/钻石 · price`. |

## Follow-up completed — 2026-07-16

| Area | Approved rule | Current result |
|---|---|---|
| Shop slots | Ordinary shops expose at most five items. | Core clamps route stores, manual entry, frozen rerolls and targeted restock to five; the artist five-slot layout is unchanged. |
| Quality merge | Only the same `pet_id` at the same public quality can merge. | Cross-quality copies coexist with deterministic instance ids; two same-quality copies upgrade one step. |
| Purchase provenance | Preserve each acquisition by its purchase moment. | Roster records store latest `acquired_from` / `acquired_at` plus append-only `acquisition_history`; the moment is deterministic run time (`day`, `node_index`, `phase`, `state_version`) and survives save/load. |
| Refresh price | Paid refresh follows 2/4/6/8. | Cost is 2, 4, 6, then 8 and remains capped at 8 for later paid refreshes. |
| Diamond ownership | Owned Diamond pets do not appear in ordinary shops. | Candidate generation removes any `pet_id` already present at Diamond quality. |
| H5 boundary | H5 is a useful reference, not a required synchronization target. | No H5 files were changed; Godot rules above are independently authoritative. |

## Remaining confirmed gaps

### Resolved — six runtime offers exceeded five artist slots

- The imported artist shop has five visible shop slots and the controller renders only the first five offers.
- Current route data has six ordinary shop nodes configured with `slots=6`: `node_shop_basic`, three Day8-Day10 tier-3 shops, `node_d10_output_shop`, and `node_d10_fire_shop`.
- User chose a formal five-item cap. Runtime now clamps these data values to five without changing the artist layout or source data.

### Resolved — same-name merge ignored source quality

- Godot `_add_pet_to_roster()` finds the first matching `pet_id` and upgrades it without checking whether the incoming copy has the same quality.
- H5 `mergeBenchEntry()` also selects by `petId` / level rather than matching public quality.
- Godot now matches by `pet_id + normalized quality`; different qualities receive separate deterministic runtime instance ids.

### Resolved — purchased restock provenance was not durable

- Godot returns `acquired_from` from `_add_pet_to_roster()`, but does not store it on the resulting roster record.
- H5 already preserves `acquiredFrom` through offer -> inventory -> state hash -> report/ViewModel.
- Roster/save now retain latest provenance and the full acquisition history with deterministic run moments.

### Resolved by user rule — paid refresh pricing

- Godot and H5 currently charge `2^(paid_refreshes+1)`: 2, 4, 8, ... inside one shop visit.
- The referenced Bazaar Version 0.1.4 rule prices merchant rerolls by merchant tier at 2/4/6/8.
- User selected the direct sequence `2/4/6/8`; Godot applies it by paid refresh count and caps later refreshes at 8.

### Resolved — owned Diamond items were not removed

- Godot filters shop candidates by day, pool, and weight only; H5 has the same omission.
- The referenced Bazaar item rules state that an owned Diamond item no longer appears as a buy option.
- Ordinary Godot candidate generation now performs the ownership-aware Diamond filter.

### Accepted boundary — H5 and Godot may differ

- Godot ordinary shops are deduplicated by this task.
- H5 `rollShop()` still samples from the same pool with replacement and can repeat an item in one refresh.
- User confirmed H5 is only borrowed where useful. No H5 synchronization task is required for these rules.

## Already aligned

- Exported shop data contains 32 merchant/store definitions with name, type, tags, slot count, unlock day, price rule, and note.
- Shop items use the public quality/price axis: Bronze 2, Silver 4, Gold 6; no pT label is shown to players.
- Element, role/build, and tier pools participate in candidate filtering and weighted generation.
- Free refresh, next discount, targeted restock, shop events, freeze, buy, sell, and seeded audit state exist in the Godot core.
- The explicit construction duplicate event remains available as a build-growth choice.

## Verification

- `smoke_bazaar_shop_rules.gd` covers all six approved boundaries, including save/load.
- Existing duplicate-offer and Bazaar information smokes remain green.
- Real Godot fixed-seed shop shows the unchanged five artist slots and `4金币` after one paid refresh: `output/bazaar_shop_rules_20260716.png`.
