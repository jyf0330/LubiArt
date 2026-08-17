extends RefCounted

## Frozen compatibility catalog for persisted content snapshots that predate
## economy.runtime_schema_version. Current content must never read this table.

const EVENT_DEFINITIONS := [
	{
		"id": "evt_shop_fire",
		"event_operations": [
			{"id": "evt_shop_fire.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 1}},
			{"id": "evt_shop_fire.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "elem_火", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_shop_water",
		"event_operations": [
			{"id": "evt_shop_water.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 1}},
			{"id": "evt_shop_water.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "elem_水", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_shop_wind",
		"event_operations": [
			{"id": "evt_shop_wind.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 1}},
			{"id": "evt_shop_wind.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "elem_雷", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_shop_earth",
		"event_operations": [
			{"id": "evt_shop_earth.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 1}},
			{"id": "evt_shop_earth.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "elem_地", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_role_summon",
		"event_operations": [
			{"id": "evt_role_summon.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 2}},
			{"id": "evt_role_summon.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "role_召唤", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_role_tank",
		"event_operations": [
			{"id": "evt_role_tank.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 2}},
			{"id": "evt_role_tank.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "role_坦克", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_free_roll",
		"event_operations": [
			{"id": "evt_free_roll.free_refresh", "operation": "add_free_refreshes", "priority": 100, "params": {"amount": 1}},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_discount",
		"event_operations": [
			{"id": "evt_discount.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 1}},
			{"id": "evt_discount.discount", "operation": "set_next_discount", "priority": 100, "params": {"percent": 50}},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_duplicate",
		"event_operations": [
			{"id": "evt_duplicate.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 4}},
			{"id": "evt_duplicate.duplicate", "operation": "duplicate_first_pet", "priority": 100, "params": {}},
			{"id": "evt_duplicate.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "special_merchant", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_upgrade_offer",
		"event_operations": [
			{"id": "evt_upgrade_offer.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 6}},
			{"id": "evt_upgrade_offer.upgrade", "operation": "upgrade_first_eligible_pet", "priority": 100, "params": {}},
			{"id": "evt_upgrade_offer.refill", "operation": "refill_shop_pool", "priority": 100, "params": {"pool_id": "special_merchant", "minimum_slots": 3}, "contexts": ["shop_event"]},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_battle_bonus",
		"event_operations": [
			{"id": "evt_battle_bonus.reward_pool", "operation": "select_reward_pool", "priority": 100, "params": {"pool_id": "reward_fast_clear"}},
		],
		"event_triggers": [
			{"id": "evt_battle_bonus.fast_clear", "hook": "post_battle", "priority": 100, "conditions": {"result_codes": ["WIN_FAST"]}, "condition_label": "fast_clear_win"},
		],
	},
	{
		"id": "evt_battle_fail",
		"event_operations": [
			{"id": "evt_battle_fail.reward_pool", "operation": "select_reward_pool", "priority": 100, "params": {"pool_id": "reward_none"}},
		],
		"event_triggers": [
			{"id": "evt_battle_fail.lose", "hook": "post_battle", "priority": 100, "conditions": {"result_codes": ["LOSE"]}, "condition_label": "battle_loss"},
		],
	},
	{
		"id": "evt_trap_bonus",
		"event_operations": [
			{"id": "evt_trap_bonus.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 2}},
			{"id": "evt_trap_bonus.trap_bonus", "operation": "queue_trap_damage_bonus", "priority": 100, "params": {"amount": 1}},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_shield_bless",
		"event_operations": [
			{"id": "evt_shield_bless.cost", "operation": "spend_coins", "priority": 0, "params": {"amount": 2}},
			{"id": "evt_shield_bless.shield", "operation": "queue_battle_prep_shield", "priority": 100, "params": {"amount": 2}},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_curse_gold",
		"event_operations": [
			{"id": "evt_curse_gold.add_coins", "operation": "add_coins", "priority": 100, "params": {"amount": 4}},
			{"id": "evt_curse_gold.reward_multiplier", "operation": "queue_reward_gold_multiplier", "priority": 100, "params": {"percent": 90}},
		],
		"event_triggers": [],
	},
	{
		"id": "evt_elite_reward",
		"event_operations": [
			{"id": "evt_elite_reward.noop", "operation": "noop", "priority": 100, "params": {}},
		],
		"event_triggers": [],
	},
]

const REST_NODE_IDS := [
	"node_rest_gold",
	"node_d02_rest_gold",
	"node_d03_rest_gold",
	"node_d04_rest_gold",
	"node_d05_rest_gold",
	"node_d06_rest_gold",
	"node_d07_rest_gold",
	"node_d08_rest_gold",
	"node_d09_rest_gold",
	"node_d10_rest_gold",
]


static func events() -> Array:
	return EVENT_DEFINITIONS.duplicate(true)


static func rest_nodes() -> Array:
	var result: Array = []
	for node_id in REST_NODE_IDS:
		result.append({
			"nodeId": node_id,
			"event_operations": [
				{"id": "%s.heal" % node_id, "operation": "heal_hero", "priority": 100, "params": {"amount": 4}},
				{"id": "%s.add_coins" % node_id, "operation": "add_coins", "priority": 100, "params": {"amount": 2}},
			],
		})
	return result
