# 2026-08-03 切片 C3 — 队伍域下沉 `RosterService`

author: Claude（架构师）
status: SPEC_READY
前置: C1（QualityPolicy）+ C2（BoardQueryService）执行完 → 总纲 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`
切片: C3 / 提交数: 1

## 0. 本切片目标

把 facade 队伍域 4 个 P 层方法（写 authority 字段 ≤1）下沉到新服务 `core/party/roster_service.gd`。`_add_pet_to_roster`/`_move_roster_index_to_active_slot`/`_move_roster_index_to_bag_slot` 因测试引用 / `_log` 副作用保留 facade 壳；`_clone_units`/`_acquisition_record` 无外部引用整体删除（改调用点）。跨域共享的 `_pet_key` 补入 C2 的 BoardQueryService（修正案）。搬移后冻结哈希逐字节不变（唯一行为外变更 = `_move_roster_index_to_*` 的 `_log` 改结构化日志，见 §4）。

## 1. 冻结基线

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| facade 方法计数 | 482 → **480**（`_clone_units`、`_acquisition_record` 各 −1；其余保持壳） |
| 反向依赖 | `0 methods / 0 calls` |

## 2. 方法处置表（4 搬 + 1 共享辅助补入 + 2 删除）

### 2.1 搬入服务

| 方法（HEAD 行） | 服务签名 | 壳必需原因 | facade 处置 |
|---|---|---|---|
| `_add_pet_to_roster` (1127-1219, 写1) | `add_pet_to_roster(roster: Array, source: Dictionary, acquired_from: String, acquisition_ctx: Dictionary, target_kind: String = "", target_index: int = -1) -> Dictionary` | tests 引用（smoke_bazaar_shop_rules:209/217/222、quarantine×5） | **1 行转发壳** |
| `_clone_units` (558-595, 写0) | `clone_units(source_units: Array, side: String) -> Array` | 无外部引用；内部调用点 1 处（L5343 `_restore_runtime_state`） | **删除** + 改 L5343 |
| `_move_roster_index_to_active_slot` (6311-6339, 写1) | `move_roster_index_to_active_slot(roster: Array, index: int, target_index: int) -> Dictionary`（`{"ok":bool,"_logs":Array}`） | 含 `_log`（×2）副作用 + 内部调用点 1 处（L6308 set_roster_drop_target 需返回 bool） | **adapter 壳**（flush 日志 → 返回 bool） |
| `_move_roster_index_to_bag_slot` (6341-6369, 写1) | `move_roster_index_to_bag_slot(roster: Array, index: int, target_index: int) -> Dictionary` | 同左（L6306、`_log`×2） | **adapter 壳** |

### 2.2 共享辅助补入 BoardQueryService（C2 修正案）

`_pet_key`（L597，5 行，纯只读）被 12 处内部调用 + roster/shop/quality 三域使用，归属 C2 已定案的跨域只读服务。**追加** `pet_key(row: Dictionary) -> String` 到 `core/battle/board_query_service.gd`（在 `cell_key` 后）；facade `_pet_key` 改 1 行转发壳。方法体：

```gdscript
func pet_key(row: Dictionary) -> String:
	var pet_id := String(row.get("pet_id", "")).strip_edges()
	if pet_id != "":
		return pet_id
	return String(row.get("id", "")).strip_edges()
```

facade `_pet_key` 壳：

```gdscript
func _pet_key(row: Dictionary) -> String:
	return _core_composition.board_query_service.pet_key(row)
```

> 不动 BoardQueryService 的 composition/smoke（C2 已注册）；仅新增 1 个方法。C4 的 ShopService 复用同一 `_board_query.pet_key`。

### 2.3 随移删除的 facade 辅助

`_acquisition_record`（L1022-1030）：唯一调用点 L1132 在 `_add_pet_to_roster` 内 → 逻辑作为服务私有 `_acquisition_record(acquired_from, acquisition_ctx)`（见 §3），facade 方法**删除**（无其他调用者，已验证）。

## 3. 新建服务 `core/party/roster_service.gd`（逐字复制）

`extends RefCounted`。configure 注入 `board_query_service`（C2）、`quality_policy`（C1）。**私有辅助不另建方法**——原 facade 薄委托辅助（`_active_roster_count`/`_target_active_slot`/`_normalize_roster_slots`/`_roster_index_for_pet_quality` 等）一律**内联为对既有脚本的直接调用**（见 §3.1 重写表），避免与 facade 同名方法在 `reference_counts` 报告产生噪声。`roster` 一律经参数传入（写者 = 可变 Array 引用）。

```gdscript
extends RefCounted

const PLAYER := "player"
const MAX_ACTIVE_UNITS := 4
const MAX_BENCH_UNITS := 24
const RosterCollectionServiceScript := preload("res://core/party/roster_collection_service.gd")
const RosterSlotRulesScript := preload("res://core/party/roster_slot_rules.gd")
const PartyRulesScript := preload("res://core/party/party_rules.gd")
const InventoryRulesScript := preload("res://core/inventory/inventory_rules.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")

var _board_query: RefCounted = null
var _quality_policy: RefCounted = null


func configure(board_query_service, quality_policy) -> void:
	_board_query = board_query_service
	_quality_policy = quality_policy


func add_pet_to_roster(
	roster: Array,
	source: Dictionary,
	acquired_from: String,
	acquisition_ctx: Dictionary,
	target_kind: String = "",
	target_index: int = -1
) -> Dictionary:
	var pet_id: String = _board_query.pet_key(source)
	if pet_id == "":
		pet_id = "pet_%03d" % roster.size()
	var incoming_quality := _quality_policy.normalize_quality(String(source.get("quality", "青铜")))
	var acquisition := _acquisition_record(acquired_from, acquisition_ctx)
	var index: int = RosterCollectionServiceScript.index_for_pet_quality(
		roster, pet_id, incoming_quality,
		Callable(_board_query, "pet_key"),
		Callable(_quality_policy, "normalize_quality")
	)
	if index >= 0:
		var existing: Dictionary = Dictionary(roster[index]).duplicate(true)
		var quality_from: String = _quality_policy.normalize_quality(String(existing.get("quality", incoming_quality)))
		var quality_to := ""
		var count: int = max(1, int(existing.get("count", 1))) + 1
		while count >= 2:
			var next_quality: String = _quality_policy.next_quality(quality_from)
			if next_quality == "":
				break
			count -= 2
			quality_to = next_quality
			quality_from = next_quality
			count += 1
		existing["pet_id"] = pet_id
		existing["quality"] = quality_from
		existing["count"] = count
		existing["side"] = PLAYER
		existing["acquired_from"] = acquired_from
		existing["acquired_at"] = acquisition.duplicate(true)
		var acquisition_history := Array(existing.get("acquisition_history", [])).duplicate(true)
		acquisition_history.append(acquisition.duplicate(true))
		existing["acquisition_history"] = acquisition_history
		var requested_kind := RosterSlotRulesScript.normalize_drop_type(target_kind)
		if requested_kind == "party":
			if bool(existing.get("active", true)) or PartyRulesScript.active_count(roster, index) < MAX_ACTIVE_UNITS:
				existing["active"] = true
				existing["slot"] = RosterSlotRulesScript.target_active_slot(roster, target_index, MAX_ACTIVE_UNITS, index)
				existing["bag_slot"] = 0
		elif requested_kind == "bag":
			if not bool(existing.get("active", true)) or InventoryRulesScript.bench_count(roster, index) < MAX_BENCH_UNITS:
				existing["active"] = false
				existing["slot"] = 0
				existing["bag_slot"] = RosterSlotRulesScript.target_bag_slot(roster, target_index, MAX_BENCH_UNITS, index)
		else:
			existing["active"] = bool(existing.get("active", true))
			existing["slot"] = int(existing.get("slot", RosterSlotRulesScript.next_active_slot(roster, MAX_ACTIVE_UNITS))) if bool(existing["active"]) else 0
			existing["bag_slot"] = 0 if bool(existing["active"]) else int(existing.get("bag_slot", existing.get("bagSlot", RosterSlotRulesScript.target_bag_slot(roster, -1, MAX_BENCH_UNITS, index))))
		_quality_policy.apply_quality_progression(existing, true)
		roster[index] = existing
		return {
			"merged": true,
			"pet_id": pet_id,
			"name": String(existing.get("name", source.get("name", pet_id))),
			"quality": quality_from,
			"quality_to": quality_to,
			"count": count,
			"acquired_from": acquired_from,
			"acquired_at": acquisition.duplicate(true),
			"active": bool(existing.get("active", true)),
			"placement": "active" if bool(existing.get("active", true)) else "bench"
		}
	var slot: int = roster.size()
	var pet: Dictionary = source.duplicate(true)
	var requested_kind := RosterSlotRulesScript.normalize_drop_type(target_kind)
	var active := PartyRulesScript.active_count(roster) < MAX_ACTIVE_UNITS
	if requested_kind == "party":
		active = PartyRulesScript.active_count(roster) < MAX_ACTIVE_UNITS
	elif requested_kind == "bag":
		active = false
	pet["id"] = RosterCollectionServiceScript.next_instance_id(
		roster, pet_id, _quality_policy.quality_key(incoming_quality), String(pet.get("id", ""))
	)
	pet["pet_id"] = pet_id
	pet["x"] = clamp(slot, 0, MAX_ACTIVE_UNITS - 1)
	pet["y"] = 6
	pet["hp"] = int(pet.get("max_hp", 1))
	pet["side"] = PLAYER
	pet["count"] = max(1, int(pet.get("count", 1)))
	pet["quality"] = incoming_quality
	pet["acquired_from"] = acquired_from
	pet["acquired_at"] = acquisition.duplicate(true)
	pet["acquisition_history"] = [acquisition.duplicate(true)]
	pet["active"] = active
	pet["slot"] = RosterSlotRulesScript.target_active_slot(roster, target_index, MAX_ACTIVE_UNITS) if active else 0
	pet["bag_slot"] = 0 if active else RosterSlotRulesScript.target_bag_slot(roster, target_index, MAX_BENCH_UNITS)
	_quality_policy.apply_quality_progression(pet, true)
	roster.append(pet)
	return {
		"merged": false,
		"pet_id": pet_id,
		"name": String(pet.get("name", pet_id)),
		"quality": String(pet.get("quality", "青铜")),
		"count": int(pet.get("count", 1)),
		"acquired_from": acquired_from,
		"acquired_at": acquisition.duplicate(true),
		"active": active,
		"placement": "active" if active else "bench"
	}


func clone_units(source_units: Array, side: String) -> Array:
	var cloned: Array = []
	for source in source_units:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(source).duplicate(true)
		var pet_id := _board_query.pet_key(unit)
		if pet_id != "":
			unit["pet_id"] = pet_id
			unit["id"] = String(unit.get("id", pet_id))
		unit["hp"] = int(unit.get("hp", unit.get("max_hp", 1)))
		unit["max_hp"] = int(unit.get("max_hp", unit.get("hp", 1)))
		unit["atk"] = int(unit.get("atk", 0))
		unit["def"] = int(unit.get("def", 0))
		unit["shield"] = int(unit.get("shield", 0))
		unit["count"] = max(1, int(unit.get("count", 1)))
		unit["quality"] = _quality_policy.normalize_quality(String(unit.get("quality", "青铜")))
		unit["slot_count"] = max(1, int(unit.get("slot_count", 3)))
		unit["base_layers"] = max(1, int(unit.get("base_layers", 1)))
		unit["hit_cells"] = max(1, int(unit.get("hit_cells", 1)))
		unit["slot_elements"] = SkillShapeRulesScript.slot_elements(unit)
		unit["elements"] = ElementRulesScript.normalize_layers(Dictionary(unit.get("elements", {})))
		if typeof(unit.get("action_slots_used", {})) != TYPE_DICTIONARY:
			unit["action_slots_used"] = {}
		unit["action_ap_spent"] = int(unit.get("action_ap_spent", 0))
		unit["has_attacked"] = bool(unit.get("has_attacked", unit.get("hasAttacked", false)))
		unit["guard_reduction"] = int(unit.get("guard_reduction", 0))
		unit["skill_bonus_atk"] = int(unit.get("skill_bonus_atk", 0))
		_quality_policy.apply_quality_progression(unit, true)
		unit["x"] = int(unit.get("x", 0))
		unit["y"] = int(unit.get("y", 0))
		unit["side"] = side
		if side == PLAYER:
			unit["active"] = bool(unit.get("active", cloned.size() < MAX_ACTIVE_UNITS))
			unit["slot"] = int(unit.get("slot", cloned.size() + 1)) if bool(unit.get("active", true)) else 0
			unit["bag_slot"] = 0 if bool(unit.get("active", true)) else int(unit.get("bag_slot", unit.get("bagSlot", 0)))
		cloned.append(unit)
	return cloned


func move_roster_index_to_active_slot(roster: Array, index: int, target_index: int) -> Dictionary:
	var logs: Array = []
	RosterCollectionServiceScript.normalize_active_slots(roster, MAX_ACTIVE_UNITS)
	RosterCollectionServiceScript.normalize_bag_slots(roster, MAX_BENCH_UNITS)
	var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
	var was_active := bool(pet.get("active", false))
	var source_slot := int(pet.get("slot", 0))
	var source_bag_slot := int(pet.get("bag_slot", 0))
	var target_slot := RosterSlotRulesScript.requested_active_slot(roster, target_index, MAX_ACTIVE_UNITS)
	var occupant_index := RosterSlotRulesScript.index_for_active_slot(roster, target_slot, MAX_ACTIVE_UNITS, index)
	if occupant_index >= 0:
		var occupant: Dictionary = Dictionary(roster[occupant_index]).duplicate(true)
		if was_active:
			occupant["active"] = true
			occupant["slot"] = source_slot
			occupant["bag_slot"] = 0
		else:
			occupant["active"] = false
			occupant["slot"] = 0
			occupant["bag_slot"] = source_bag_slot if source_bag_slot > 0 else RosterSlotRulesScript.next_bag_slot(roster, MAX_BENCH_UNITS, occupant_index)
		roster[occupant_index] = occupant
	elif not was_active and PartyRulesScript.active_count(roster, index) >= MAX_ACTIVE_UNITS:
		logs.append({"kind": "log", "text": "上阵失败：上场位已满 %d/%d。" % [MAX_ACTIVE_UNITS, MAX_ACTIVE_UNITS]})
		return {"ok": false, "_logs": logs}
	pet["active"] = true
	pet["slot"] = target_slot
	pet["bag_slot"] = 0
	roster[index] = pet
	RosterCollectionServiceScript.normalize_active_slots(roster, MAX_ACTIVE_UNITS)
	RosterCollectionServiceScript.normalize_bag_slots(roster, MAX_BENCH_UNITS)
	logs.append({"kind": "log", "text": "拖拽上阵：%s 到队伍槽%d。" % [String(pet.get("name", pet.get("pet_id", ""))), int(pet.get("slot", target_slot))]})
	return {"ok": true, "_logs": logs}


func move_roster_index_to_bag_slot(roster: Array, index: int, target_index: int) -> Dictionary:
	var logs: Array = []
	RosterCollectionServiceScript.normalize_active_slots(roster, MAX_ACTIVE_UNITS)
	RosterCollectionServiceScript.normalize_bag_slots(roster, MAX_BENCH_UNITS)
	var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
	var was_active := bool(pet.get("active", false))
	var source_slot := int(pet.get("slot", 0))
	var source_bag_slot := int(pet.get("bag_slot", 0))
	var target_slot := RosterSlotRulesScript.requested_bag_slot(roster, target_index, MAX_BENCH_UNITS)
	var occupant_index := RosterSlotRulesScript.index_for_bag_slot(roster, target_slot, MAX_BENCH_UNITS, index)
	if occupant_index >= 0:
		var occupant: Dictionary = Dictionary(roster[occupant_index]).duplicate(true)
		if was_active:
			occupant["active"] = true
			occupant["slot"] = source_slot
			occupant["bag_slot"] = 0
		else:
			occupant["active"] = false
			occupant["slot"] = 0
			occupant["bag_slot"] = source_bag_slot if source_bag_slot > 0 else RosterSlotRulesScript.next_bag_slot(roster, MAX_BENCH_UNITS, occupant_index)
		roster[occupant_index] = occupant
	elif was_active and InventoryRulesScript.bench_count(roster, index) >= MAX_BENCH_UNITS:
		logs.append({"kind": "log", "text": "下阵失败：背包已满 %d/%d。" % [MAX_BENCH_UNITS, MAX_BENCH_UNITS]})
		return {"ok": false, "_logs": logs}
	pet["active"] = false
	pet["slot"] = 0
	pet["bag_slot"] = target_slot
	roster[index] = pet
	RosterCollectionServiceScript.normalize_active_slots(roster, MAX_ACTIVE_UNITS)
	RosterCollectionServiceScript.normalize_bag_slots(roster, MAX_BENCH_UNITS)
	logs.append({"kind": "log", "text": "拖拽下阵：%s 到背包槽%d。" % [String(pet.get("name", pet.get("pet_id", ""))), int(pet.get("bag_slot", target_slot))]})
	return {"ok": true, "_logs": logs}


func _acquisition_record(acquired_from: String, ctx: Dictionary) -> Dictionary:
	return {
		"source": acquired_from,
		"day": ctx["day"],
		"node_index": ctx["node_index"],
		"phase": ctx["phase"],
		"state_version": ctx["state_version"],
		"at": "day:%d/node:%d/state:%d" % [ctx["day"], ctx["node_index"], ctx["state_version"]]
	}
```

### 3.1 重写表（facade 薄委托 → 内联脚本调用，实现方必须逐项替换）

| facade 调用 | 服务内替换 |
|---|---|
| `_pet_key(x)` | `_board_query.pet_key(x)` |
| `_normalize_quality(x)`（C1 后已是 `quality_policy.normalize_quality`） | `_quality_policy.normalize_quality(x)` |
| `_next_quality(x)` | `_quality_policy.next_quality(x)` |
| `_quality_key(x)` | `_quality_policy.quality_key(x)` |
| `_apply_quality_progression(u, b)` | `_quality_policy.apply_quality_progression(u, b)` |
| `_normalize_drop_type(v)` | `RosterSlotRulesScript.normalize_drop_type(v)` |
| `_active_roster_count(skip)` | `PartyRulesScript.active_count(roster, skip)` |
| `_bench_roster_count(skip)` | `InventoryRulesScript.bench_count(roster, skip)` |
| `_next_active_slot()` | `RosterSlotRulesScript.next_active_slot(roster, MAX_ACTIVE_UNITS)` |
| `_target_active_slot(ti, skip)` | `RosterSlotRulesScript.target_active_slot(roster, ti, MAX_ACTIVE_UNITS, skip)` |
| `_target_bag_slot(ti, skip)` | `RosterSlotRulesScript.target_bag_slot(roster, ti, MAX_BENCH_UNITS, skip)` |
| `_requested_active_slot(ti)` | `RosterSlotRulesScript.requested_active_slot(roster, ti, MAX_ACTIVE_UNITS)` |
| `_requested_bag_slot(ti)` | `RosterSlotRulesScript.requested_bag_slot(roster, ti, MAX_BENCH_UNITS)` |
| `_roster_index_for_active_slot(slot, skip)` | `RosterSlotRulesScript.index_for_active_slot(roster, slot, MAX_ACTIVE_UNITS, skip)` |
| `_roster_index_for_bag_slot(slot, skip)` | `RosterSlotRulesScript.index_for_bag_slot(roster, slot, MAX_BENCH_UNITS, skip)` |
| `_next_bag_slot_excluding(skip)` | `RosterSlotRulesScript.next_bag_slot(roster, MAX_BENCH_UNITS, skip)` |
| `_roster_index_for_pet_quality(pid, q)` | `RosterCollectionServiceScript.index_for_pet_quality(roster, pid, q, Callable(_board_query, "pet_key"), Callable(_quality_policy, "normalize_quality"))` |
| `_next_roster_instance_id(pid, q, pref)` | `RosterCollectionServiceScript.next_instance_id(roster, pid, _quality_policy.quality_key(q), pref)` |
| `_normalize_roster_slots()` | `RosterCollectionServiceScript.normalize_active_slots(roster, MAX_ACTIVE_UNITS)` + `RosterCollectionServiceScript.normalize_bag_slots(roster, MAX_BENCH_UNITS)` |

## 4. facade 编辑

### 4.1 `_add_pet_to_roster` 1 行转发壳（签名不变）

```gdscript
func _add_pet_to_roster(source: Dictionary, acquired_from: String, target_kind: String = "", target_index: int = -1) -> Dictionary:
	return _core_composition.roster_service.add_pet_to_roster(
		roster, source, acquired_from,
		{"day": day, "node_index": node_index, "phase": phase, "state_version": state_version},
		target_kind, target_index
	)
```

### 4.2 `_move_roster_index_to_active_slot` / `_move_roster_index_to_bag_slot` adapter 壳（签名不变，返回 bool）

`_log` 副作用：服务返回 `{"ok":bool,"_logs":[...]}`；壳 flush 日志后返回 bool，**日志顺序 = 服务内 append 顺序 = 原方法体 `_log` 调用顺序**。

```gdscript
func _move_roster_index_to_active_slot(index: int, target_index: int) -> bool:
	var result := _core_composition.roster_service.move_roster_index_to_active_slot(roster, index, target_index)
	for entry in result["_logs"]:
		_log(entry["text"])
	return result["ok"]

func _move_roster_index_to_bag_slot(index: int, target_index: int) -> bool:
	var result := _core_composition.roster_service.move_roster_index_to_bag_slot(roster, index, target_index)
	for entry in result["_logs"]:
		_log(entry["text"])
	return result["ok"]
```

### 4.3 删除 `_clone_units` + 改调用点

删除方法体 L558-595。调用点 L5343（`_restore_runtime_state` 内）改为：

```gdscript
	roster = _core_composition.roster_service.clone_units(Array(game_data.get("roster", [])), PLAYER)
```

### 4.4 删除 `_acquisition_record`

删除方法体 L1022-1030。无其他调用者（已 grep 验证）。

### 4.5 `_pet_key` 壳（见 §2.2）

## 5. 组合根注册（`core/composition/core_composition.gd`）

`_init` 末尾（board_query_service configure 之后）追加：

```gdscript
const RosterServiceScript := preload("res://core/party/roster_service.gd")
var roster_service: RefCounted = null
# _init 末尾：
	roster_service = _resolve(overrides, &"roster_service", RosterServiceScript)
	roster_service.call(&"configure", board_query_service, quality_policy)
# services() 追加：
		"roster_service": roster_service,
```

> `board_query_service`（C2）、`quality_policy`（C1）已在 `_init` 前段 resolve，末尾 configure 安全。

## 6. smoke 门禁同步

`DIRECT_CONSUMERS` 追加：

```gdscript
	"roster_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.roster_service.add_pet_to_roster"},
```

## 7. `_log` 处理

- `_add_pet_to_roster`：无 `_log`（实测 0）。无日志收集。
- `_clone_units`：无 `_log`。
- `_move_roster_index_to_*`：`_log` ×2 各 → 结构化日志 `{"kind":"log","text":...}`，key `_logs`，由 facade adapter 壳收集。**这是本切片唯一允许的行为外变更**。

## 8. 验证

| 序 | 命令 | 期望 |
|---|---|---|
| V1 | `inventory_core_methods.py --output` 后 `--check` | `METHOD_INVENTORY_OK`；计数 480；反向依赖 `0/0`；无重复实现 |
| V2 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V3 | P0 探针 | 三哈希与 §1 一致 |
| V4 | `git diff --check` | 无输出 |
| V5 | 日志顺序快照 | 拖拽上阵/下阵日志序列与搬移前一致（log_lines 顺序不变） |
| V6 | smoke_composition_service_ownership | `SMOKE_COMPOSITION_SERVICE_OWNERSHIP_OK services=48` |

## 9. 提交边界

单提交，精确暂存：`core/party/roster_service.gd`（新）、`core/battle/board_query_service.gd`（+pet_key）、`core/state/game_state.gd`、`core/composition/core_composition.gd`、`tests/core/smoke_composition_service_ownership.gd`、`reports/architecture/METHOD_INVENTORY.md`。禁止 `git add .`，不推送。建议提交信息：`refactor(core): extract roster domain into RosterService (C3)`。

## 10. 后续切片影响（记录，不在本切片处理）

- C4 ShopService 复用 `_board_query.pet_key`（C3 修正案生效）。
- `_add_pet_to_roster` 的 3 个内部调用点（L6104 pick_reward、L6190 apply_shop_event、L6398 buy_offer）在 C4/C5 仍走 facade 壳，无需改动。
- `_active_roster_count`/`_bench_roster_count`/`_normalize_roster_slots` 等 facade 薄委托**保留**（sell_unit/buy_offer/set_roster_drop_target 等未搬方法仍用），不在本切片下沉。
- `acquisition_ctx`（day/node_index/phase/state_version）由 facade 壳组装——C9 若将 `_capture_runtime_state` 字段清单抽出时不再重复此键。
