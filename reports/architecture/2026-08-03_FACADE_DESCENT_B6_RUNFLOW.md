# 2026-08-03 切片 C5 — 跑图流程域下沉 `RunFlowService`

author: Claude（架构师）
status: SPEC_READY
前置: C1+C2+C3+C4 执行完 → 总纲 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`
切片: C5 / 提交数: 1

## 0. 本切片目标

把跑图流程域 P 层方法下沉到 `core/run/run_flow_service.gd`。**与 MASTER §3 计数（4P+6O 子块）的差异以本规格实测为准**：MASTER 初版把 `_apply_route_event` 计为 P、把部分 P 辅助计入 O 子块；实测写字段数后，**5 个方法整体搬**（其中 `_stall_for_node` 被端口外部调用 → 转发壳；4 个含 `_log`/写回 → adapter 壳），**2 个删除改调用点**，**`_apply_route_event` 归 O 层留 facade**（依赖 `_apply_event_effect`/`_advance_route_step`/`_return_to_route_or_day_end` 三个 O 权威辅助，搬移需 3 Callable 注入，收益低于成本）。O 层 4 个方法（`start_next_day`/`choose_route`/`start_battle`/`_apply_route_event`）留 facade，仅提取 `match_route_option` 纯子块。`_fallback_game_data` **本切片不搬**（依赖 `_pet`/`_enemy` 构造器；`2026-08-03_CODEX_GAME_STATE_RESPONSIBILITY_DESCENT_SPEC.md` §7 已声明从生产删除，属独立任务，记录待办不处理）。搬移后冻结哈希逐字节不变。

## 1. 冻结基线

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| facade 方法计数 | 473 → **470**（删除 3：`_post_battle_events_for_result` `_enemy_battle_roster_templates` `_shop_store_definition`[C4 遗留]；其余保留壳） |
| 反向依赖 | `0 methods / 0 calls` |

## 2. 方法处置表（7 P + 1 O 子块 + 3 O 留 facade + 1 排除）

### 2.1 P 层整体搬（7 个）

| 方法（HEAD 行） | 服务签名 | 壳必需原因 | facade 处置 |
|---|---|---|---|
| `_stall_for_node` (5384-5413, 写0) | `stall_for_node(node: Dictionary, ctx: Dictionary) -> Dictionary` | **端口外部调用**（shop_inventory_command_port.gd:22 `.call("_stall_for_node", {...})`，传构造好的 node dict） | **转发壳**（组 ctx） |
| `_apply_battle_prep_effects` (5729-5764, 写2: units[]/battle_prep_effects[]) | `apply_battle_prep_effects(ctx: Dictionary) -> Dictionary`（返回 `{"applied":Array,"_logs":Array}`） | 含 `_log`（×2）副作用；调用点 L6472 在 start_battle（O 层留 facade） | **adapter 壳**（flush 日志 → 返回 applied） |
| `_battle_prep_effect_from_event` (5663-5689, 写1: battle_prep_effects[]) | `battle_prep_effect_from_event(event: Dictionary, source: String, node_id: String = "", ctx: Dictionary = {}) -> Dictionary`（返回 `{"ok":bool,"effect":Dictionary,"_logs":Array}`） | 含 `_log`（×1）副作用；调用点 L6056 在 `_apply_route_event`（O 层留 facade） | **adapter 壳**（flush 日志 → 返回 effect） |
| `_outer_run_effect_from_event` (5694-5727, 写2: coins/outer_run_effects) | `outer_run_effect_from_event(event: Dictionary, source: String, node_id: String = "", ctx: Dictionary = {}) -> Dictionary`（返回 `{"ok":bool,"effect":Dictionary,"coins":int,"_logs":Array}`） | 含 `_log`（×1）副作用 + coins 标量写回；调用点 L6057 在 `_apply_route_event` | **adapter 壳**（flush 日志 → 写回 coins → 返回 effect） |
| `pick_reward` (6086-6114, 写1: reward_options) | `pick_reward(action: Dictionary, ctx: Dictionary) -> Dictionary`（返回 `{"ok":bool,"reward_options":Array,"_logs":Array}`） | **A 类公共命令**（route_reward_command_port/battle_session_port/handler 引用）| **adapter 转发壳**（写回 reward_options + flush 日志 → 返回 bool） |
| `_post_battle_events_for_result` (5795-5824, 写0) | `post_battle_events_for_result(code: String, base_reward_pool_id: String, encounter_id: String, ctx: Dictionary) -> Dictionary` | 无外部引用；内部调用点 L6719（`_finish_battle_result` 内，C6 目标） | **删除** + 改调用点 |
| `_enemy_battle_roster_templates` (6492-6499, 写0) | `enemy_battle_roster_templates(game_data: Dictionary, day: int, period: String) -> Array` | 无外部引用；内部调用点 L6450（start_battle 内） | **删除** + 改调用点 |

> 实测写字段修正：`_apply_battle_prep_effects`=2（MASTER 记 2，一致）；`_outer_run_effect_from_event`=2（coins + outer_run_effects.append，一致）。`_apply_route_event` 归 O 层依据：其调用的 `_apply_event_effect`（写 shop_free_rolls/shop_next_discount/shop_event_effects）、`_advance_route_step`（写5）、`_return_to_route_or_day_end`（间接写多字段）均留在 facade，整体搬需 3 Callable 注入；判定为 O 层编排，仅其两个 P 子块（`_battle_prep_effect_from_event`/`_outer_run_effect_from_event`）下沉。

### 2.2 O 层子块提取（1 个服务方法）

| 方法（HEAD 行） | 服务签名 | 用途 |
|---|---|---|
| `choose_route` 的 option 匹配逻辑（5992-5994 首 3 行） | `match_route_option(options: Array, option_id: String) -> Dictionary` | choose_route 用它替换首 3 行内联匹配（纯只读，行为逐字不变） |

### 2.3 O 层留 facade（3 个方法 + 1 个归 O）

`start_next_day`(写25)、`choose_route`(写14)、`start_battle`(写23)、`_apply_route_event`(写1，归 O 见 §2.1 注)。**方法体逐字保留不动**（仅 choose_route 首 3 行换 `match_route_option` 调用、内部对已搬方法改走壳）。无其他可分离纯子块（start_next_day/start_battle 主体为批量权威重置 + 组合服务调用，无纯计算段）。

### 2.4 排除（1 个）

`_fallback_game_data` (447-477, 写0)：依赖 `_pet`/`_enemy`/`_build_shop`（C4 后 = `_core_composition.shop_service.build_shop()`）。**不搬**。v2 规格已声明从生产删除（`CODEX_GAME_STATE_RESPONSIBILITY_DESCENT_SPEC.md` §7：内容包与 fallback 竞争真相源）。删除属独立任务，本切片只记录。C4 对 L459 调用点的改造已就位（改 shop_service.build_shop()），删除时继承。

## 3. 新建服务 `core/run/run_flow_service.gd`（逐字复制）

`extends RefCounted`。configure 注入 4 个服务：`roster_service`（C3）、`shop_service`（C4）、`board_query_service`（C2）、`battle_startup_service`（现有）。**不注入 quality_policy**（实测 RunFlow 服务方法无直接使用；MASTER §5 注入清单据此修正）。`_shop_stall_catalog` 自行实例化（与 facade 现模式一致，非 authority）。

### 3.0 `ctx` 键契约（本切片的 authority 传递协议）

| 键 | 使用处 | 角色 |
|---|---|---|
| `game_data` | stall_for_node / post_battle_events_for_result | 读输入（Dictionary，内含 `economy`） |
| `day` `active_shop_seed_context` | stall_for_node | 读输入 |
| `coins` | outer_run_effect_from_event | **标量写回**（服务返回新值，facade 壳写回） |
| `units` | apply_battle_prep_effects | **原地可变**（数组引用，同引用回读） |
| `battle_prep_effects` | apply_battle_prep_effects / battle_prep_effect_from_event | **原地可变** |
| `day` `period` `round` | apply_battle_prep_effects | 读输入 |
| `day` `node_index` | battle_prep_effect_from_event / outer_run_effect_from_event | 读输入 |
| `outer_run_effects` | outer_run_effect_from_event | **原地可变** |
| `reward_options` | pick_reward | **写回**（服务清空后返回，facade 壳写回） |
| `roster` `acquisition_ctx` | pick_reward | 读输入（acquisition_ctx 含 day/node_index/phase/state_version，与 C3 契约一致） |

### 3.1 服务源码

```gdscript
extends RefCounted

const PLAYER := "player"
const ENEMY := "enemy"
const BATTLE_TEAM_SIZE := 4
const MAX_SHOP_OFFERS := 10
const EconomyRulesScript := preload("res://core/economy/economy_rules.gd")
const RouteRulesScript := preload("res://core/route/route_rules.gd")
const ShopStallCatalogScript := preload("res://core/shop/shop_stall_catalog.gd")

var _roster_service: RefCounted = null
var _shop_service: RefCounted = null
var _board_query: RefCounted = null
var _battle_startup_service: RefCounted = null
var _shop_stall_catalog := ShopStallCatalogScript.new()


func configure(roster_service, shop_service, board_query_service, battle_startup_service) -> void:
	_roster_service = roster_service
	_shop_service = shop_service
	_board_query = board_query_service
	_battle_startup_service = battle_startup_service


func _economy_data(ctx: Dictionary) -> Dictionary:
	return Dictionary(Dictionary(ctx.get("game_data", {})).get("economy", {}))


func _is_formal(row: Dictionary) -> bool:
	return String(row.get("status", "")).strip_edges() == "正式"


func _day_expr_allows(day_expr: String, day: int) -> bool:
	return RouteRulesScript.day_expression_allows(day_expr, day)


func _event_by_id(game_data: Dictionary, event_id: String, layer: String, day: int) -> Dictionary:
	for item in Array(_economy_data({"game_data": game_data}).get("events", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event := Dictionary(item)
		if String(event.get("id", "")) != event_id:
			continue
		if layer != "" and String(event.get("layer", "")) != layer:
			continue
		if not _is_formal(event):
			continue
		if not _day_expr_allows(String(event.get("day_expr", "")), day):
			continue
		return event
	return {}


func match_route_option(options: Array, option_id: String) -> Dictionary:
	for option in options:
		var row := Dictionary(option)
		if String(row.get("id", "")) == option_id or String(row.get("optionId", "")) == option_id or String(row.get("nodeId", "")) == option_id or String(row.get("encounterId", "")) == option_id:
			return row
	return {}


func stall_for_node(node: Dictionary, ctx: Dictionary) -> Dictionary:
	var pool_id := String(node.get("shopPoolId", "night_base"))
	var store := _shop_service.shop_store_definition(ctx["game_data"], pool_id)
	if not store.is_empty():
		var resolved := _shop_stall_catalog.resolve(
			store,
			Array(_economy_data(ctx).get("shop_mapping", [])),
			ctx["day"],
			"%s|%s" % [ctx["active_shop_seed_context"], pool_id],
			String(node.get("stallId", node.get("stall_id", "")))
		)
		if not resolved.is_empty():
			resolved["slots"] = _shop_service.shop_slot_count(int(resolved.get("slots", store.get("default_slots", MAX_SHOP_OFFERS))))
			resolved["node_id"] = String(node.get("nodeId", ""))
			return resolved
		var stall := store.duplicate(true)
		stall["pool_id"] = pool_id
		stall["slots"] = _shop_service.shop_slot_count(int(node.get("slots", store.get("default_slots", MAX_SHOP_OFFERS))))
		stall["node_id"] = String(node.get("nodeId", ""))
		stall["available"] = true
		return stall
	return {
		"id": pool_id,
		"pool_id": pool_id,
		"name": String(node.get("name", "宠物商店")),
		"tags": [],
		"slots": _shop_service.shop_slot_count(int(node.get("slots", MAX_SHOP_OFFERS))),
		"status": "正式",
		"available": true,
	}


func post_battle_events_for_result(code: String, base_reward_pool_id: String, encounter_id: String, ctx: Dictionary) -> Dictionary:
	var event_id := ""
	var condition := ""
	if code == "LOSE":
		event_id = "evt_battle_fail"
		condition = "battle_loss"
	elif code == "WIN_FAST":
		event_id = "evt_battle_bonus"
		condition = "fast_clear_win"
	if event_id == "":
		return {"reward_pool_id": base_reward_pool_id, "events": []}
	var event := _event_by_id(ctx["game_data"], event_id, "post_battle", ctx["day"])
	if event.is_empty():
		return {"reward_pool_id": base_reward_pool_id, "events": []}
	var reward_pool_id := String(event.get("reward_pool_id", base_reward_pool_id))
	if reward_pool_id == "":
		reward_pool_id = base_reward_pool_id
	return {
		"reward_pool_id": reward_pool_id,
		"events": [{
			"event_id": event_id,
			"name": String(event.get("name", event_id)),
			"condition": condition,
			"encounter_id": encounter_id,
			"reward_pool_from": base_reward_pool_id,
			"reward_pool_to": reward_pool_id,
			"gain": String(event.get("gain", "")),
			"value": int(event.get("value", 0))
		}]
	}


func apply_battle_prep_effects(ctx: Dictionary) -> Dictionary:
	var applied: Array = []
	var logs: Array = []
	var battle_prep_effects: Array = ctx["battle_prep_effects"]
	var units: Array = ctx["units"]
	for index in range(battle_prep_effects.size()):
		var effect := Dictionary(battle_prep_effects[index]).duplicate(true)
		if String(effect.get("status", "")) != "pending" or int(effect.get("uses_remaining", 0)) <= 0:
			continue
		if String(effect.get("type", "")) == "shield":
			var shield: int = max(0, int(effect.get("shield", 0)))
			var targets: Array = []
			for unit_index in range(units.size()):
				var unit: Dictionary = Dictionary(units[unit_index]).duplicate(true)
				if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
					continue
				var from_shield: int = int(unit.get("shield", 0))
				unit["shield"] = from_shield + shield
				units[unit_index] = unit
				targets.append({
					"unit_id": _board_query.pet_key(unit),
					"name": String(unit.get("name", _board_query.pet_key(unit))),
					"shield_from": from_shield,
					"shield_to": int(unit.get("shield", 0))
				})
			effect["status"] = "applied"
			effect["uses_remaining"] = 0
			effect["targets"] = targets
			logs.append({"kind": "log", "text": "战前护盾：%s，使%d个我方单位护盾+%d。" % [String(effect.get("name", "护盾祝福")), targets.size(), shield]})
		elif String(effect.get("type", "")) == "trap_damage_bonus":
			effect["status"] = "active"
			effect["applied_at"] = {"day": ctx["day"], "period": ctx["period"], "round": ctx["round"]}
			logs.append({"kind": "log", "text": "陷阱增伤：%s 已激活，下一次火陷阱伤害+%d。" % [String(effect.get("name", "陷阱商人")), int(effect.get("bonus_damage", 0))]})
		battle_prep_effects[index] = effect
		applied.append(effect.duplicate(true))
	return {"applied": applied, "_logs": logs}


func battle_prep_effect_from_event(event: Dictionary, source: String, node_id: String = "", ctx: Dictionary = {}) -> Dictionary:
	if String(event.get("layer", "")) != "pre_battle":
		return {"ok": false, "effect": {}, "_logs": []}
	var text := EconomyRulesScript.event_text(event)
	var value: int = max(0, int(event.get("value", 0)))
	if text.find("护盾") < 0 and text.find("陷阱伤害") < 0:
		return {"ok": false, "effect": {}, "_logs": []}
	var effect := {
		"effect_id": "prep_%d_%d_%s" % [ctx["day"], ctx["node_index"], String(event.get("id", ""))],
		"event_id": String(event.get("id", "")),
		"name": String(event.get("name", "")),
		"source": source,
		"node_id": node_id,
		"type": "shield" if text.find("护盾") >= 0 else "trap_damage_bonus",
		"shield": value if text.find("护盾") >= 0 else 0,
		"bonus_damage": value if text.find("陷阱伤害") >= 0 else 0,
		"status": "pending",
		"day_queued": ctx["day"],
		"step_queued": ctx["node_index"],
		"uses_remaining": 1
	}
	Array(ctx["battle_prep_effects"]).append(effect.duplicate(true))
	return {
		"ok": true,
		"effect": effect,
		"_logs": [{"kind": "log", "text": "战前效果入队：%s，%s。" % [String(event.get("name", "事件")), "下一场护盾+%d" % value if String(effect["type"]) == "shield" else "下一次火陷阱伤害+%d" % value]}]
	}


func outer_run_effect_from_event(event: Dictionary, source: String, node_id: String = "", ctx: Dictionary = {}) -> Dictionary:
	var coins := int(ctx.get("coins", 0))
	if String(event.get("layer", "")) != "event":
		return {"ok": false, "effect": {}, "coins": coins, "_logs": []}
	var text := EconomyRulesScript.event_text(event)
	if text.find("金币") < 0:
		return {"ok": false, "effect": {}, "coins": coins, "_logs": []}
	var immediate_gold: int = max(0, int(event.get("value", 0)))
	var multiplier := EconomyRulesScript.reward_multiplier_from_event(event)
	if immediate_gold <= 0 or multiplier >= 100:
		return {"ok": false, "effect": {}, "coins": coins, "_logs": []}
	var before := coins
	coins += immediate_gold
	var effect := {
		"effect_id": "run_%d_%d_%s" % [ctx["day"], ctx["node_index"], String(event.get("id", ""))],
		"event_id": String(event.get("id", "")),
		"name": String(event.get("name", "")),
		"source": source,
		"node_id": node_id,
		"type": "reward_gold_multiplier",
		"multiplier": multiplier,
		"immediate_gold": immediate_gold,
		"status": "pending",
		"day_queued": ctx["day"],
		"step_queued": ctx["node_index"],
		"uses_remaining": 1
	}
	Array(ctx["outer_run_effects"]).append(effect.duplicate(true))
	return {
		"ok": true,
		"effect": effect,
		"coins": coins,
		"_logs": [{"kind": "log", "text": "外层风险：%s，金币%d→%d，下一场战斗奖励按%d%%结算。" % [String(event.get("name", "事件")), before, coins, multiplier]}]
	}


func pick_reward(action: Dictionary, ctx: Dictionary) -> Dictionary:
	var logs: Array = []
	var reward_options: Array = ctx["reward_options"]
	if reward_options.is_empty():
		return {"ok": false, "reward_options": reward_options, "_logs": [{"kind": "log", "text": "当前没有可领取的奖励。"}]}
	var ref := String(action.get("rewardId", action.get("reward_id", action.get("id", ""))))
	var index := int(action.get("index", 0))
	var picked: Dictionary = {}
	if ref != "":
		for option in reward_options:
			var row := Dictionary(option)
			if String(row.get("id", "")) == ref or String(row.get("pet_id", "")) == ref:
				picked = row
				break
	elif index >= 0 and index < reward_options.size():
		picked = Dictionary(reward_options[index])
	if picked.is_empty():
		return {"ok": false, "reward_options": reward_options, "_logs": [{"kind": "log", "text": "奖励选择失败：候选不存在。"}]}
	var result := _roster_service.add_pet_to_roster(
		ctx["roster"],
		Dictionary(picked.get("source", picked)).duplicate(true),
		"reward",
		ctx["acquisition_ctx"]
	)
	if bool(result.get("merged", false)) and String(result.get("quality_to", "")) != "":
		logs.append({"kind": "log", "text": "选择奖励：%s 同名合成到%s。" % [String(result.get("name", "宠物")), String(result.get("quality", "青铜"))]})
	else:
		logs.append({"kind": "log", "text": "选择奖励：%s %s。" % [String(result.get("name", picked.get("name", "宠物"))), "加入上阵队伍" if bool(result.get("active", true)) else "加入背包"]})
	reward_options = []
	return {"ok": true, "reward_options": reward_options, "_logs": logs}


func enemy_battle_roster_templates(game_data: Dictionary, day: int, period: String) -> Array:
	var battle := Dictionary(game_data.get("battle", {}))
	return _battle_startup_service.select_enemy_templates(
		battle,
		day,
		period,
		BATTLE_TEAM_SIZE
	)
```

> 行为差异说明：`pick_reward` 原调用 `_add_pet_to_roster(...)`（C3 后为 facade 转发壳，内部组装 acquisition_ctx）；服务版直接调 `_roster_service.add_pet_to_roster(roster, source, "reward", ctx["acquisition_ctx"])`，`acquisition_ctx` 由 facade 壳提供（键与 C3 契约一致）。`add_pet_to_roster` 无 `_log`（C3 核实），故无日志需经 pick_reward 转发。其余方法体与 facade 逐字一致；`_pet_key` → `_board_query.pet_key`、`_economy_data()` → `_economy_data(ctx)`、`_event_text`/`_reward_multiplier_from_event` → `EconomyRulesScript` 直接调用、`_shop_store_definition`/`_shop_slot_count` → `_shop_service.*`（C4 服务公开方法）。

## 4. facade 编辑

### 4.1 `_stall_for_node` 转发壳（签名不变，端口引用）

```gdscript
func _stall_for_node(node: Dictionary) -> Dictionary:
	return _core_composition.run_flow_service.stall_for_node(node, {
		"day": day,
		"active_shop_seed_context": active_shop_seed_context,
		"game_data": game_data,
	})
```

### 4.2 `_apply_battle_prep_effects` adapter 壳（签名不变）

```gdscript
func _apply_battle_prep_effects() -> Array:
	var result := _core_composition.run_flow_service.apply_battle_prep_effects({
		"units": units,
		"battle_prep_effects": battle_prep_effects,
		"day": day,
		"period": battle_period,
		"round": battle_round,
	})
	for line in Array(result["_logs"]):
		_log(line["text"])
	return result["applied"]
```

### 4.3 `_battle_prep_effect_from_event` adapter 壳（签名不变）

```gdscript
func _battle_prep_effect_from_event(event: Dictionary, source: String, node_id: String = "") -> Dictionary:
	var result := _core_composition.run_flow_service.battle_prep_effect_from_event(event, source, node_id, {
		"battle_prep_effects": battle_prep_effects,
		"day": day,
		"node_index": node_index,
	})
	for line in Array(result["_logs"]):
		_log(line["text"])
	return result["effect"]
```

### 4.4 `_outer_run_effect_from_event` adapter 壳（签名不变）

```gdscript
func _outer_run_effect_from_event(event: Dictionary, source: String, node_id: String = "") -> Dictionary:
	var result := _core_composition.run_flow_service.outer_run_effect_from_event(event, source, node_id, {
		"coins": coins,
		"outer_run_effects": outer_run_effects,
		"day": day,
		"node_index": node_index,
	})
	coins = result["coins"]
	for line in Array(result["_logs"]):
		_log(line["text"])
	return result["effect"]
```

### 4.5 `pick_reward` adapter 转发壳（签名不变，A 类命令）

```gdscript
func pick_reward(action: Dictionary) -> bool:
	var result := _core_composition.run_flow_service.pick_reward(action, {
		"reward_options": reward_options,
		"roster": roster,
		"acquisition_ctx": {"day": day, "node_index": node_index, "phase": phase, "state_version": state_version},
	})
	reward_options = result["reward_options"]
	for line in Array(result["_logs"]):
		_log(line["text"])
	return bool(result["ok"])
```

### 4.6 `_post_battle_events_for_result` 删除 + 改调用点（L6719，在 `_finish_battle_result` 内）

删除方法体 L5795-5824。L6719：

```gdscript
	var post_battle := _post_battle_events_for_result(code, base_reward_pool_id, encounter_id)
```
→
```gdscript
	var post_battle := _core_composition.run_flow_service.post_battle_events_for_result(code, base_reward_pool_id, encounter_id, {
		"game_data": game_data,
		"day": day,
	})
```

### 4.7 `_enemy_battle_roster_templates` 删除 + 改调用点（L6450，start_battle 内）

删除方法体 L6492-6499。L6450：

```gdscript
		ENEMY: _enemy_battle_roster_templates()
```
→
```gdscript
		ENEMY: _core_composition.run_flow_service.enemy_battle_roster_templates(game_data, day, battle_period)
```

### 4.8 `choose_route` 首 3 行换 `match_route_option` 调用

L5992-5994（for 循环 + `var row` + 匹配 if）替换为：

```gdscript
	for option in route_options:
		var row := _core_composition.run_flow_service.match_route_option([option], option_id)
		if not row.is_empty():
```

> **L5995 原 `var kind := String(row["kind"])` 逐字保留**（新替换块不含该行，避免重复声明）。替换后 `choose_route` 首段为：
> ```gdscript
> 	for option in route_options:
> 		var row := _core_composition.run_flow_service.match_route_option([option], option_id)
> 		if not row.is_empty():
> 			var kind := String(row["kind"])
> 			active_schedule = ...
> ```
> 等价性：原逻辑遍历 `route_options`，逐行匹配 `id`/`optionId`/`nodeId`/`encounterId` 任一命中即用该行。`match_route_option([option], option_id)` 对单元素数组做相同匹配，命中返回该行、未命中返回 `{}`，`if not row.is_empty()` ≡ 原匹配条件。行为逐字等价。其余 choose_route 体（shop/battle/reward/event/rest 分支）逐字保留。

### 4.9 C4 遗留清理：删除 `_shop_store_definition` facade 壳

C4 因 `_stall_for_node`（L5386）调用而保留的 `_shop_store_definition` 转发壳，本切片 `_stall_for_node` 搬走后 facade 内**无调用点**（C4 已删 `_shop_pool_has_candidates`/`_shop_stall_has_candidates`/`_shop_offers_for_pool` 体）。**删除该方法**。`_shop_slot_count` 壳**保留**（apply_shop_event L6247 仍调用）。删除前 grep 确认无残留调用点。

## 5. 组合根注册（`core/composition/core_composition.gd`）

`_init` 末尾（shop_service configure 之后）追加：

```gdscript
const RunFlowServiceScript := preload("res://core/run/run_flow_service.gd")
var run_flow_service: RefCounted = null
# _init 末尾：
	run_flow_service = _resolve(overrides, &"run_flow_service", RunFlowServiceScript)
	run_flow_service.call(&"configure", roster_service, shop_service, board_query_service, battle_startup_service)
# services() 追加：
		"run_flow_service": run_flow_service,
```

> 依赖就绪性：roster_service(C3)、shop_service(C4)、board_query_service(C2)、battle_startup_service(现有) 均在本切片前 resolve，末尾 configure 安全。

## 6. smoke 门禁同步

`DIRECT_CONSUMERS` 追加：

```gdscript
	"run_flow_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.run_flow_service.stall_for_node"},
```

## 7. `_log` 处理

4 个 P 方法含 `_log`：`_apply_battle_prep_effects`（×2）、`_battle_prep_effect_from_event`（×1）、`_outer_run_effect_from_event`（×1）、`pick_reward`（×4）。全部改为结构化 `{"kind":"log","text":"<原文案>"}` 项 key `_logs`，由 facade adapter 壳收集后 `_log(line["text"])` 写 `log_lines`。**日志顺序 = 服务内 append 顺序 = 原方法体 `_log` 调用顺序**。`_stall_for_node`/`_post_battle_events_for_result`/`_enemy_battle_roster_templates`/`match_route_option` 无 `_log`。

## 8. 验证

| 序 | 命令 | 期望 |
|---|---|---|
| V1 | `inventory_core_methods.py --output` 后 `--check` | `METHOD_INVENTORY_OK`；计数 470；反向依赖 `0/0`；无重复实现 |
| V2 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V3 | P0 探针 | 三哈希与 §1 一致 |
| V4 | `git diff --check` | 无输出 |
| V5 | 日志快照 | log_lines 序列与搬移前一致（重点核对 pick_reward 4 条顺序） |
| V6 | smoke_composition_service_ownership | `SMOKE_COMPOSITION_SERVICE_OWNERSHIP_OK services=50` |

> V5 附加核对：`_apply_route_event` 留在 facade，其内 `_battle_prep_effect_from_event`/`_outer_run_effect_from_event` 调用点改走 adapter 壳后，节点事件日志序列（3 条）不变；`start_battle` 内 `_apply_battle_prep_effects` 改走壳后，战前效果日志 + 开场日志序列不变。

## 9. 提交边界

单提交，精确暂存：`core/run/run_flow_service.gd`（新）、`core/state/game_state.gd`、`core/composition/core_composition.gd`、`tests/core/smoke_composition_service_ownership.gd`、`reports/architecture/METHOD_INVENTORY.md`。禁止 `git add .`，不推送。建议提交信息：`refactor(core): extract run-flow domain into RunFlowService (C5)`。

## 10. 后续切片影响（记录，不在本切片处理）

- `_finish_battle_result`（L6698）内 `post_battle_events_for_result` 调用点已改组合；C6 下沉 `_finish_battle_result` 时继承此调用（RunFlowService 依赖注入进 ActionService 或经 facade 编排）。
- `_fallback_game_data` 排除；C4 已把其内 `_build_shop` 改 shop_service.build_shop()。v2 删除任务独立执行。
- `_build_route_options`/`_build_run_plan`/`_advance_route_step` 等 O 层权威辅助留 facade（测试直接引用 `_build_route_options`）；如后续下沉需处理 9 个测试调用点，本切片不触碰。
- `apply_route_event`（公开包装）留 facade，其 `_apply_route_event` 调用的两个 P 子块现走服务；C 后如需把 `_apply_route_event` 主体也下沉，需注入 `_apply_event_effect`/`_advance_route_step`/`_return_to_route_or_day_end` 三个 Callable（本切片判定收益低于成本，记录此注入清单）。
