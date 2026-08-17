# 2026-08-03 切片 C4 — 商店域下沉 `ShopService`

author: Claude（架构师）
status: SPEC_READY
前置: C1+C2+C3 执行完 → 总纲 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`
切片: C4 / 提交数: 1

## 0. 本切片目标

把商店域 3 个 P 层方法整体下沉 + 1 个 O 层方法（`apply_shop_event`）抽纯子块。实测写字段数修正：`_shop_offers_for_pool` = **4**（MASTER §1 记 3，`shop_next_discount`/`shop_context_roll_count`/`shop_roll_count`/`shop_seed_audit`），以本规格为准，按 P 层处理（4 写字段经单一可变 `shop_state` dict 传递）。`apply_shop_event` 写 4 字段且依赖留留在 facade 的 `_apply_event_effect` → **O 层**，编排留在 facade，仅抽 `construction_text_for_event` 纯子块。搬移后冻结哈希逐字节不变。

## 1. 冻结基线

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| facade 方法计数 | 480 → **473**（删除 7：`_build_shop` `_shop_catalog_context` `_shop_pool_has_candidates` `_shop_stall_has_candidates` `_shop_roll_seed` `_record_shop_seen_pet_ids` `_shop_seen_pet_lookup_for_day`；其余保持壳） |
| 反向依赖 | `0 methods / 0 calls` |

## 2. 方法处置表（4 方法 + 7 辅助删除 + 3 辅助壳）

### 2.1 搬入服务（3 P + 1 O 子块）

| 方法（HEAD 行） | 服务签名 | 壳必需原因 | facade 处置 |
|---|---|---|---|
| `_build_shop` (521-556, 写0) | `build_shop() -> Array` | 无外部引用；内部调用点 2 处（L459 `_fallback_game_data`、L5345 `_restore_runtime_state`） | **删除** + 改 2 调用点 |
| `_resolve_day1_shop_pool` (5461-5491, 写0) | `resolve_day1_shop_pool(requested_pool: String, seed_context: String, shop_state: Dictionary) -> String` | **tests 引用**（smoke_bazaar_day1_shop_categories:27-28 `state.call("_resolve_day1_shop_pool", ...)`） | **1 行转发壳** |
| `_shop_offers_for_pool` (5532-5578, 写4) | `offers_for_pool(pool_id: String, slots: int, kept_offers: Array, shop_state: Dictionary) -> Array` | 无外部引用但内部调用点 3 处（6010 choose_route、6149 roll_shop、6248 apply_shop_event）均留 facade，adapter 写回逻辑内联会 3× 重复 | **adapter 壳**（shop_state 组包 + 3 标量写回） |
| `apply_shop_event` (6229-6273, 写4) | 抽 `construction_text_for_event(effect: Dictionary) -> String` | **A 类公共命令**（shop_inventory_command_handler.gd:31 via port）；依赖留 facade 的 `_apply_event_effect` | **编排壳保留在 facade**，L6252-6265 子块替换为服务调用 |

### 2.2 随移删除的 facade 辅助（唯一调用点都在搬移方法内，已验证）

| 辅助 | HEAD 行 | 唯一调用点 |
|---|---|---|
| `_shop_catalog_context` | 5580-5603 | 5440（`_shop_pool_has_candidates`）、5458（`_shop_stall_has_candidates`）、5542（`_shop_offers_for_pool`）— 全搬移 |
| `_shop_pool_has_candidates` | 5426-5441 | 5479/5484（`_resolve_day1_shop_pool`） |
| `_shop_stall_has_candidates` | 5443-5459 | 5434（`_shop_pool_has_candidates`）、5474（`_resolve_day1_shop_pool`） |
| `_shop_roll_seed` | 5911-5916 | 5533（`_shop_offers_for_pool`） |
| `_record_shop_seen_pet_ids` | 5512-5530 | 5555（`_shop_offers_for_pool`） |
| `_shop_seen_pet_lookup_for_day` | 5506-5510 | 5591（`_shop_catalog_context`） |

### 2.3 保留 facade 壳的辅助（仍有 facade 未搬调用点）

| 辅助 | 壳 | 未搬调用点 |
|---|---|---|
| `_shop_store_definition(pool_id)` | `_core_composition.shop_service.shop_store_definition(game_data, pool_id)` | 5386（`_stall_for_node`） |
| `_shop_seen_pet_ids_for_day(target_day)` | `_core_composition.shop_service.shop_seen_pet_ids_for_day(day, shop_seen_pet_ids_by_day, target_day)` | 2071（snapshot）、2169/2170（metrics） |
| `_shop_slot_count(requested)` | `_core_composition.shop_service.shop_slot_count(requested)` | 5396/5401/5410（`_stall_for_node`）、6247（apply_shop_event） |

## 3. 新建服务 `core/run/shop_service.gd`（逐字复制）

`extends RefCounted`。configure 注入 `board_query_service`（C2）、`quality_policy`（C1）。`_shop_catalog_service`/`_shop_stall_catalog` 自行实例化（与 facade 现模式一致，非 authority）。`_economy_data()`/`_rng`/`_rng_next` 一律内联为 `Dictionary(shop_state["game_data"]...)` / `SeededSelectorScript.rng/next`。

### 3.0 `shop_state` 键契约（本切片的 authority 传递协议）

| 键 | 角色 |
|---|---|
| `day` `period` `run_seed` `active_stall` `active_shop_seed_context` `game_data` `roster` `seen_pet_ids_by_day` `seed_audit` `context_roll_count` `roll_count` `next_discount` | 读输入（facade 壳组包） |
| `seed_audit`（Array）、`seen_pet_ids_by_day`（Dictionary） | **原地可变**（同引用回读，无需写回） |
| `context_roll_count` `roll_count` `next_discount` | **标量写回**（facade 壳写回字段） |

### 3.1 服务源码

```gdscript
extends RefCounted

const MAX_SHOP_OFFERS := 10
const EconomyRulesScript := preload("res://core/economy/economy_rules.gd")
const RouteRulesScript := preload("res://core/route/route_rules.gd")
const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const ShopCatalogServiceScript := preload("res://core/shop/shop_catalog_service.gd")
const ShopStallCatalogScript := preload("res://core/shop/shop_stall_catalog.gd")
const RosterCollectionServiceScript := preload("res://core/party/roster_collection_service.gd")

var _board_query: RefCounted = null
var _quality_policy: RefCounted = null
var _shop_catalog_service := ShopCatalogServiceScript.new()
var _shop_stall_catalog := ShopStallCatalogScript.new()


func configure(board_query_service, quality_policy) -> void:
	_board_query = board_query_service
	_quality_policy = quality_policy


func _economy_data(shop_state: Dictionary) -> Dictionary:
	return Dictionary(Dictionary(shop_state["game_data"]).get("economy", {}))


func build_shop() -> Array:
	var names := [
		["pal_shop_001", "棉悠悠", "无", "发育", 21, 4, 2],
		["pal_shop_002", "火绒狐", "火", "爆发", 30, 3, 2],
		["pal_shop_003", "冲浪鸭", "水", "治疗", 18, 4, 0],
		["pal_shop_004", "翠叶鼠", "草", "召唤", 18, 5, 0],
		["pal_shop_005", "伏特喵", "雷", "控制", 24, 4, 0],
		["pal_shop_006", "毛掸儿", "冰", "控制", 18, 3, 0],
		["pal_shop_007", "遁地鼠", "地", "前排", 25, 1, 0],
		["pal_shop_008", "寐魔", "暗", "诅咒", 30, 3, 10],
		["pal_shop_009", "精灵龙", "龙", "召唤", 18, 5, 0],
		["pal_shop_010", "企丸丸", "水", "治疗", 18, 4, 0]
	]
	var offers: Array = []
	var index := 1
	for row in names:
		offers.append({
			"id": "shop_%03d" % index,
			"pet_id": row[0],
			"name": row[1],
			"element": row[2],
			"role": row[3],
			"quality": "青铜",
			"max_hp": row[4],
			"atk": row[5],
			"def": 0,
			"shield": 0,
			"ap": 3,
			"skill": "",
			"shape": "",
			"range": "",
			"price": row[6],
			"sold": false
		})
		index += 1
	return offers


func resolve_day1_shop_pool(requested_pool: String, seed_context: String, shop_state: Dictionary) -> String:
	var candidates: Array[String] = []
	var source_node_type := "merchant" if requested_pool == "day1_element_dynamic" else "trainer"
	if ["day1_element_dynamic", "day1_role_dynamic"].has(requested_pool):
		for value in Array(_economy_data(shop_state).get("shop_mapping", [])):
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var mapping := Dictionary(value)
			if String(mapping.get("source_node_type", "")) != source_node_type:
				continue
			var location_id := String(mapping.get("local_shop_id", ""))
			if location_id == "" or candidates.has(location_id):
				continue
			if _shop_stall_has_candidates(shop_state, location_id, String(mapping.get("id", ""))):
				candidates.append(location_id)
	if candidates.is_empty() and requested_pool == "day1_element_dynamic":
		for element in ElementRulesScript.ACTIVE_ELEMENTS:
			var element_pool := "elem_%s" % String(element)
			if _shop_pool_has_candidates(shop_state, element_pool):
				candidates.append(element_pool)
	elif candidates.is_empty() and requested_pool == "day1_role_dynamic":
		for role in ["坦克", "输出", "控制", "治疗", "召唤", "经济", "机动"]:
			var role_pool := "role_%s" % role
			if _shop_pool_has_candidates(shop_state, role_pool):
				candidates.append(role_pool)
	if candidates.is_empty():
		return requested_pool
	candidates.sort()
	var random := SeededSelectorScript.rng("%s|%s|day%d" % [seed_context, requested_pool, shop_state["day"]])
	var index: int = mini(candidates.size() - 1, int(floor(SeededSelectorScript.next(random) * candidates.size())))
	return candidates[index]


func offers_for_pool(pool_id: String, slots: int, kept_offers: Array, shop_state: Dictionary) -> Array:
	var roll_seed := _shop_roll_seed(shop_state, pool_id)
	var context_counter_before := shop_state["context_roll_count"]
	var general_counter_before := shop_state["roll_count"]
	var seen_count_before := _shop_seen_pet_ids_for_day(shop_state["day"], shop_state["seen_pet_ids_by_day"]).size()
	var store := shop_store_definition(shop_state["game_data"], pool_id)
	if store.is_empty():
		store = {"id": pool_id, "pool_id": pool_id}
	elif not Dictionary(shop_state["active_stall"]).is_empty() and String(Dictionary(shop_state["active_stall"]).get("pool_id", "")) == pool_id:
		store = Dictionary(shop_state["active_stall"]).duplicate(true)
	var context := _shop_catalog_context(shop_state, pool_id)
	context["random"] = SeededSelectorScript.rng(roll_seed)
	context["discount"] = shop_state["next_discount"]
	context["max_offers"] = MAX_SHOP_OFFERS
	var result := Dictionary(_shop_catalog_service.build_offers(
		Array(_economy_data(shop_state).get("shop_items", [])),
		store,
		_shop_slot_count(slots),
		kept_offers,
		context
	))
	var offers := Array(result.get("offers", []))
	var kept_count := int(result.get("kept_offer_count", 0))
	var newly_seen_pet_ids := _record_shop_seen_pet_ids(shop_state, offers)
	shop_state["next_discount"] = 0
	if String(shop_state["active_shop_seed_context"]) != "":
		shop_state["context_roll_count"] = int(shop_state["context_roll_count"]) + 1
	else:
		shop_state["roll_count"] = int(shop_state["roll_count"]) + 1
	Array(shop_state["seed_audit"]).append({
		"pool_id": pool_id,
		"mode": "route_context" if String(shop_state["active_shop_seed_context"]) != "" else "manual_or_period",
		"seed_context": shop_state["active_shop_seed_context"],
		"seed": roll_seed,
		"day": shop_state["day"],
		"period": shop_state["period"],
		"kept_offer_count": kept_count,
		"generated_offer_count": int(result.get("generated_offer_count", max(0, offers.size() - kept_count))),
		"newly_seen_pet_ids": newly_seen_pet_ids,
		"daily_seen_count_before": seen_count_before,
		"daily_seen_count_after": _shop_seen_pet_ids_for_day(shop_state["day"], shop_state["seen_pet_ids_by_day"]).size(),
		"shop_roll_count_before": general_counter_before,
		"shop_roll_count_after": shop_state["roll_count"],
		"shop_context_roll_count_before": context_counter_before,
		"shop_context_roll_count_after": shop_state["context_roll_count"]
	})
	return offers


func construction_text_for_event(effect: Dictionary) -> String:
	var construction := Dictionary(effect.get("construction", {}))
	var construction_text := ""
	if not construction.is_empty():
		if String(construction.get("type", "")) == "upgrade_pet":
			construction_text = "，%s %s→%s" % [
				String(construction.get("name", "宠物")),
				String(construction.get("quality_from", "")),
				String(construction.get("quality_to", ""))
			]
		elif String(construction.get("type", "")) == "duplicate_pet":
			construction_text = "，复制 %s%s" % [
				String(construction.get("name", "宠物")),
				"，同名合成到%s" % String(construction.get("quality", "")) if bool(construction.get("merged", false)) else ""
			]
	return construction_text


func shop_store_definition(game_data: Dictionary, pool_id: String) -> Dictionary:
	var economy := Dictionary(Dictionary(game_data).get("economy", {}))
	for item in Array(economy.get("shop_stores", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var store := Dictionary(item)
		if String(store.get("id", "")) == pool_id:
			var definition := store.duplicate(true)
			definition["pool_id"] = pool_id
			return definition
	return {}


func shop_seen_pet_ids_for_day(day: int, seen_pet_ids_by_day: Dictionary, target_day: int = -1) -> Array:
	var resolved_day := day if target_day < 1 else target_day
	var values := Array(seen_pet_ids_by_day.get(str(resolved_day), []))
	var seen := {}
	var pet_ids: Array = []
	for value in values:
		var pet_id := String(value).strip_edges()
		if pet_id == "" or seen.has(pet_id):
			continue
		seen[pet_id] = true
		pet_ids.append(pet_id)
	pet_ids.sort()
	return pet_ids


func shop_slot_count(requested: int) -> int:
	return RouteRulesScript.normalized_shop_slots(requested, MAX_SHOP_OFFERS)


func _shop_catalog_context(
	shop_state: Dictionary,
	pool_id: String,
	apply_owned_diamond_blocker: bool = true,
	source_stall_override: String = ""
) -> Dictionary:
	var active_stall := Dictionary(shop_state["active_stall"])
	var context := {
		"day": shop_state["day"],
		"weight_fn": func(row: Dictionary): return EconomyRulesScript.shop_weight(row, pool_id),
		"key_fn": func(row: Dictionary): return _board_query.pet_key(row),
		"source_objects": Array(_economy_data(shop_state).get("bazaar_objects", [])),
	}
	var daily_seen := _shop_seen_pet_lookup_for_day(shop_state)
	var source_stall_id := source_stall_override
	if source_stall_id == "" and String(active_stall.get("pool_id", "")) == pool_id:
		source_stall_id = String(active_stall.get("source_stall_id", active_stall.get("stall_id", "")))
	if source_stall_id != "":
		context["source_stall_id"] = source_stall_id
	var roster: Array = shop_state["roster"]
	context["blocked_fn"] = func(row: Dictionary) -> bool:
		var pet_id := _board_query.pet_key(row)
		if pet_id != "" and daily_seen.has(pet_id):
			return true
		return apply_owned_diamond_blocker and pet_id != "" and RosterCollectionServiceScript.index_for_pet_quality(
			roster, pet_id, "钻石",
			Callable(_board_query, "pet_key"),
			Callable(_quality_policy, "normalize_quality")
		) >= 0
	return context


func _shop_seen_pet_lookup_for_day(shop_state: Dictionary) -> Dictionary:
	var lookup := {}
	for pet_id in _shop_seen_pet_ids_for_day(shop_state["day"], shop_state["seen_pet_ids_by_day"]):
		lookup[String(pet_id)] = true
	return lookup


func _record_shop_seen_pet_ids(shop_state: Dictionary, offers: Array, target_day: int = -1) -> Array:
	var resolved_day := shop_state["day"] if target_day < 1 else target_day
	var pet_ids := _shop_seen_pet_ids_for_day(resolved_day, shop_state["seen_pet_ids_by_day"])
	var lookup := {}
	for pet_id in pet_ids:
		lookup[String(pet_id)] = true
	var newly_seen: Array = []
	for value in offers:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var pet_id := _board_query.pet_key(Dictionary(value))
		if pet_id == "" or lookup.has(pet_id):
			continue
		lookup[pet_id] = true
		pet_ids.append(pet_id)
		newly_seen.append(pet_id)
	pet_ids.sort()
	shop_state["seen_pet_ids_by_day"][str(resolved_day)] = pet_ids
	return newly_seen


func _shop_roll_seed(shop_state: Dictionary, pool_id: String) -> String:
	var active_stall := Dictionary(shop_state["active_stall"])
	var source_stall_id := String(active_stall.get("source_stall_id", active_stall.get("stall_id", "")))
	var source_suffix := "" if source_stall_id == "" else ":%s" % source_stall_id
	if String(shop_state["active_shop_seed_context"]) != "":
		return "shop:v2:%s:%s:%d:%s%s" % [shop_state["run_seed"], shop_state["active_shop_seed_context"], shop_state["context_roll_count"], pool_id, source_suffix]
	return "shop:v2:%s:%d:%s:%d:%s%s" % [shop_state["run_seed"], shop_state["day"], shop_state["period"], shop_state["roll_count"], pool_id, source_suffix]


func _shop_pool_has_candidates(shop_state: Dictionary, pool_id: String) -> bool:
	var store := shop_store_definition(shop_state["game_data"], pool_id)
	if store.is_empty():
		store = {"id": pool_id, "pool_id": pool_id}
	var mappings := Array(_economy_data(shop_state).get("shop_mapping", []))
	if _shop_stall_catalog.has_location(mappings, pool_id):
		for value in _shop_stall_catalog.open_stalls(mappings, pool_id, shop_state["day"]):
			var mapping := Dictionary(value)
			if _shop_stall_has_candidates(shop_state, pool_id, String(mapping.get("id", ""))):
				return true
		return false
	return _shop_catalog_service.has_candidates(
		Array(_economy_data(shop_state).get("shop_items", [])),
		store,
		_shop_catalog_context(shop_state, pool_id, false)
	)


func _shop_stall_has_candidates(shop_state: Dictionary, pool_id: String, stall_id: String) -> bool:
	var mappings := Array(_economy_data(shop_state).get("shop_mapping", []))
	var is_open := false
	for value in _shop_stall_catalog.open_stalls(mappings, pool_id, shop_state["day"]):
		if String(Dictionary(value).get("id", "")) == stall_id:
			is_open = true
			break
	if not is_open:
		return false
	var store := shop_store_definition(shop_state["game_data"], pool_id)
	if store.is_empty():
		store = {"id": pool_id, "pool_id": pool_id}
	return _shop_catalog_service.has_candidates(
		Array(_economy_data(shop_state).get("shop_items", [])),
		store,
		_shop_catalog_context(shop_state, pool_id, false, stall_id)
	)
```

### 3.2 重写表（facade 辅助 → 服务内表达式）

| facade 调用 | 服务内替换 |
|---|---|
| `_economy_data()` | `_economy_data(shop_state)`（= `game_data.get("economy", {})` 提取） |
| `_pet_key(x)` | `_board_query.pet_key(x)` |
| `_rng(seed)` | `SeededSelectorScript.rng(seed)` |
| `_rng_next(r)` | `SeededSelectorScript.next(r)` |
| `_shop_weight(i, pid)` | `EconomyRulesScript.shop_weight(i, pid)` |
| `_shop_slot_count(r)` | `_shop_slot_count(r)`（服务方法） |
| `_shop_store_definition(pid)` | `shop_store_definition(shop_state["game_data"], pid)` |
| `_roster_index_for_pet_quality(pid, "钻石")` | `RosterCollectionServiceScript.index_for_pet_quality(roster, pid, "钻石", Callable(_board_query, "pet_key"), Callable(_quality_policy, "normalize_quality"))` |

## 4. facade 编辑

### 4.1 `_build_shop` 删除 + 改调用点

删除方法体 L521-556。

- L459（`_fallback_game_data`，**非 snapshot**）：`"shop_offers": _build_shop(),` → `"shop_offers": _core_composition.shop_service.build_shop(),`
- L5345（`_restore_runtime_state`）：`shop_offers = Array(game_data.get("shop_offers", _build_shop())).duplicate(true)` → `shop_offers = Array(game_data.get("shop_offers", _core_composition.shop_service.build_shop())).duplicate(true)`

### 4.2 `_resolve_day1_shop_pool` 1 行转发壳（签名不变，tests 引用）

```gdscript
func _resolve_day1_shop_pool(requested_pool: String, seed_context: String) -> String:
	return _core_composition.shop_service.resolve_day1_shop_pool(requested_pool, seed_context, {
		"day": day,
		"game_data": game_data,
		"roster": roster,
		"active_stall": active_stall,
		"seen_pet_ids_by_day": shop_seen_pet_ids_by_day,
	})
```

### 4.3 `_shop_offers_for_pool` adapter 壳（签名不变）

```gdscript
func _shop_offers_for_pool(pool_id: String, slots: int, kept_offers: Array = []) -> Array:
	var shop_state := {
		"day": day,
		"period": battle_period,
		"run_seed": run_seed,
		"active_stall": active_stall,
		"active_shop_seed_context": active_shop_seed_context,
		"context_roll_count": shop_context_roll_count,
		"roll_count": shop_roll_count,
		"next_discount": shop_next_discount,
		"seed_audit": shop_seed_audit,
		"seen_pet_ids_by_day": shop_seen_pet_ids_by_day,
		"game_data": game_data,
		"roster": roster,
	}
	var result := _core_composition.shop_service.offers_for_pool(pool_id, slots, kept_offers, shop_state)
	shop_context_roll_count = shop_state["context_roll_count"]
	shop_roll_count = shop_state["roll_count"]
	shop_next_discount = shop_state["next_discount"]
	return result
```

### 4.4 `apply_shop_event`（O 层，编排保留）— 仅替换子块

原 L6252-6265（construction_text 构建块）替换为一行：

```gdscript
	var construction_text := _core_composition.shop_service.construction_text_for_event(effect)
```

其余行（L6229-6251、L6266-6273）**逐字保留不动**。`_shop_event_by_id`/`_parse_gold_cost`/`_apply_event_effect`/`_frozen_shop_offers`/`_shop_offers_for_pool`（现在走壳）均在 facade 内保持可用。

### 4.5 辅助壳（3 个）

```gdscript
func _shop_store_definition(pool_id: String) -> Dictionary:
	return _core_composition.shop_service.shop_store_definition(game_data, pool_id)

func _shop_seen_pet_ids_for_day(target_day: int = -1) -> Array:
	return _core_composition.shop_service.shop_seen_pet_ids_for_day(day, shop_seen_pet_ids_by_day, target_day)

func _shop_slot_count(requested: int) -> int:
	return _core_composition.shop_service.shop_slot_count(requested)
```

### 4.6 删除 6 个辅助方法体

`_shop_catalog_context`（L5580-5603）、`_shop_pool_has_candidates`（L5426-5441）、`_shop_stall_has_candidates`（L5443-5459）、`_shop_roll_seed`（L5911-5916）、`_record_shop_seen_pet_ids`（L5512-5530）、`_shop_seen_pet_lookup_for_day`（L5506-5510）— 全部删除。**必须确认删除后 facade 内无残留调用点**（除 §2.3 已保留壳的辅助外；若 grep 发现遗漏调用点，回退并核实）。

## 5. 组合根注册（`core/composition/core_composition.gd`）

`_init` 末尾（roster_service configure 之后）追加：

```gdscript
const ShopServiceScript := preload("res://core/run/shop_service.gd")
var shop_service: RefCounted = null
# _init 末尾：
	shop_service = _resolve(overrides, &"shop_service", ShopServiceScript)
	shop_service.call(&"configure", board_query_service, quality_policy)
# services() 追加：
		"shop_service": shop_service,
```

## 6. smoke 门禁同步

`DIRECT_CONSUMERS` 追加：

```gdscript
	"shop_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.shop_service.offers_for_pool"},
```

## 7. `_log` 处理

4 个搬移方法全部无 `_log`（实测）。`apply_shop_event` 的 `_log` 在 facade 编排壳内直接调用，不受影响。本切片无结构化日志变更。

## 8. 验证

| 序 | 命令 | 期望 |
|---|---|---|
| V1 | `inventory_core_methods.py --output` 后 `--check` | `METHOD_INVENTORY_OK`；计数 473；反向依赖 `0/0`；无重复实现 |
| V2 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V3 | P0 探针 | 三哈希与 §1 一致 |
| V4 | `git diff --check` | 无输出 |
| V5 | 日志快照 | 无 `_log` 顺序变更，跳过 |
| V6 | smoke_composition_service_ownership | `SMOKE_COMPOSITION_SERVICE_OWNERSHIP_OK services=49` |

## 9. 提交边界

单提交，精确暂存：`core/run/shop_service.gd`（新）、`core/state/game_state.gd`、`core/composition/core_composition.gd`、`tests/core/smoke_composition_service_ownership.gd`、`reports/architecture/METHOD_INVENTORY.md`。禁止 `git add .`，不推送。建议提交信息：`refactor(core): extract shop domain into ShopService (C4)`。

## 10. 后续切片影响（记录，不在本切片处理）

- C5 RunFlowService 的 `choose_route`（L5991）与 `roll_shop`（L6134）仍调 facade 壳 `_shop_offers_for_pool`（adapter），搬移时改为 `_shop.offers_for_pool(...)`（组装 shop_state）。
- `_apply_event_effect`（L6200）依赖留 facade，后续 C 若下沉需注入 `Callable(facade, "_apply_event_effect")`。
- `_build_shop` 为纯静态表，`_fallback_game_data`（L459）调用点改服务后，后续该处子块下沉时继承此调用。
- `shop_state` 组包逻辑（§4.3）是 authority 读写边界样板；C5 其他 O 层方法可复用同模式。
