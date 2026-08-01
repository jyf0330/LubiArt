extends RefCounted

## Shared client presentation policy. It keeps developer-only surfaces and the
## small runtime translation catalog out of gameplay state and authored layout.

const DEFAULT_LOCALE := "zh_CN"
const SUPPORTED_LOCALES := ["zh_CN", "en"]

const ZH_CN := {
	"UI_DAY_NODE_GOLD": "第%d天 · 节点%d · 金币%d",
	"UI_TEAM_BENCH": "队伍%d/4 · 候补%d",
	"UI_ROUTE_TITLE": "路线选择",
	"UI_ROUTE_PROMPT": "选择下一站：",
	"UI_ROUTE_ENTRY": "%s · %s\n  收益：%s\n  风险：%s",
	"UI_ROUTE_KIND_BATTLE": "战斗",
	"UI_ROUTE_KIND_SHOP": "商店",
	"UI_ROUTE_KIND_REWARD": "奖励",
	"UI_ROUTE_KIND_EVENT": "事件",
	"UI_ROUTE_KIND_REST": "休整",
	"UI_ROUTE_BENEFIT_BATTLE": "胜利后获得结算与路线推进",
	"UI_ROUTE_BENEFIT_SHOP": "用金币换取宠物、技能或强化",
	"UI_ROUTE_BENEFIT_REWARD": "获得新宠物或成长资源",
	"UI_ROUTE_BENEFIT_EVENT": "触发当前节点效果",
	"UI_ROUTE_BENEFIT_REST": "恢复并整备队伍",
	"UI_ROUTE_RISK_BATTLE": "敌方意图与生命损耗",
	"UI_ROUTE_RISK_SHOP": "消耗金币，商品库存有限",
	"UI_ROUTE_RISK_REWARD": "需要在候选奖励中取舍",
	"UI_ROUTE_RISK_EVENT": "结果取决于事件规则",
	"UI_ROUTE_RISK_REST": "通常没有战斗收益",
	"UI_SHOP_TITLE": "商店",
	"UI_STALL": "摊位：%s",
	"UI_TAGS": "倾向：%s",
	"UI_REFRESH_FREE": "刷新：免费（剩余%d次）",
	"UI_REFRESH_COST": "刷新：%d金币",
	"UI_OFFER_AVAILABLE": "%s · %s · %d金币 · 可购买",
	"UI_OFFER_UNAFFORDABLE": "%s · %s · %d金币 · 金币不足（差%d）",
	"UI_OFFER_SOLD": "%s · 已售出",
	"UI_OFFER_EFFECT": "  效果：%s",
	"UI_BAG_TITLE": "候补背包",
	"UI_BAG_NEXT": "下一页",
	"UI_BAG_NEXT_PAGE": "下一页（%d/%d）",
	"UI_BAG_SUMMARY": "候补宠物共%d只，当前展示第%d/%d页。\n点击宠物查看详情，拖拽可上阵、换位或出售。",
	"UI_REWARD_TITLE": "奖励选择",
	"UI_REWARD_PROMPT": "点击奖励卡查看属性，再确认选择：",
	"UI_RESULT_SUCCESS": "✓ %s",
	"UI_RESULT_FAILURE": "未完成：%s",
	"UI_RESULT_NO_COINS": "金币不足，无法购买；当前%d，价格%d。",
	"UI_RESULT_PURCHASED": "已购买%s，剩余金币%d。",
	"UI_RESULT_REFRESHED": "商店已刷新，当前金币%d。",
	"UI_RESULT_COMMAND_ACCEPTED": "操作完成：%s",
	"UI_RESULT_COMMAND_REJECTED": "操作未生效：%s",
	"UI_REFRESH_SHOP": "刷新商店",
	"UI_CONTINUE": "继续",
	"UI_LOCAL_SAVE": "本地存档",
	"UI_SAVE_SLOT": "保存%d",
	"UI_LOAD_SLOT": "读档%d",
	"UI_EXPORT_REPLAY": "导出回放",
	"UI_EXPORT_TRACE": "导出战报",
	"UI_ACTION_TITLE": "行动控制 · 回合%d",
	"UI_ACTION_NO_SELECTION": "未选中宠物",
	"UI_ACTION_SELECT_PET": "先在棋盘选择我方宠物",
	"UI_ACTION_PREVIEW": "预览：红色作用格 %d 个 · %d 个技能从左到右触发",
	"UI_ACTION_RESET_READY": "重置宠物（可用%d次）",
	"UI_ACTION_RESET_THRESHOLD": "重置宠物（需存活≤%d，次数%d）",
	"UI_ACTION_RESET_WAIT": "重置宠物（第%d回合+1次，等%d回合）",
	"UI_ACTION_ALL_OUT": "按顺序触发全部技能",
	"UI_ACTION_END_TURN": "结束玩家回合",
	"UI_ACTION_MONSTER_TURN": "执行敌方行动",
	"UI_ACTION_SKILL_TOOLTIP": "拖拽到其他槽位，或按确认键选中后再确认目标槽位",
	"UI_ACTION_EXECUTING": "正在执行 · 等待权威 Trace 结算",
	"UI_ACTION_PICKED": "已选第%d格 · 再点目标格移动",
	"UI_ACTION_QUEUE_HINT": "技能行动条 · 拖拽或确认键排序",
	"UI_ACTION_FLOW_EXECUTING": "1  已选择   →   2  已确认   →   3  执行中…",
	"UI_ACTION_FLOW_RESULT": "✓  执行完成   ·   查看结果后继续行动",
	"UI_ACTION_FLOW_PREVIEW": "1  已选择   →   2  红色范围   →   3  可执行",
	"UI_ACTION_FLOW_SELECT": "1  选择宠物   ·   2  查看范围   ·   3  执行",
	"UI_ACTION_SKILL_COUNT": "%d 个技能",
	"UI_ACTION_COMBO_COUNT": "%d 个组合",
	"UI_ACTION_DAMAGE": "伤害 %d（生命 %d / 护盾 %d）",
	"UI_ACTION_RESULT": "结果：%s",
	"UI_DEBUG_COLLAPSE": "收起调试",
	"UI_DEBUG_DATA": "数据调试",
	"UI_SELL": "出售",
	"UI_DIFFICULTY_LABEL": "摆位难度：%s",
	"UI_DIFFICULTY_EASY": "简单",
	"UI_DIFFICULTY_NORMAL": "普通",
	"UI_DIFFICULTY_TOOLTIP": "普通难度保持宠物原攻击方向；简单难度允许自动布置同时择优调整方向。",
	"UI_POSITION_CALCULATING": "摆位计算中…",
	"UI_POSITION_FAILED": "%s摆位：失败",
	"UI_POSITION_MOVED": "%s摆位：已移动%d只",
	"UI_POSITION_OPTIMAL": "%s摆位：当前已最优",
	"UI_TERMINAL_BATTLE": "战斗结算",
	"UI_TERMINAL_DAY": "当日结算",
	"UI_TERMINAL_GAME": "本局结束",
	"UI_CURRENT_GOLD": "当前金币 %d。",
	"UI_BATTLE_RESULT": "%s · 评级%s\n金币 %d → %d\n回合 %d · %s",
	"UI_OUTCOME_DRAW": "平局",
	"UI_OUTCOME_WIN": "胜利",
	"UI_OUTCOME_LOSS": "失败",
	"UI_CONTINUE_SETTLEMENT": "继续结算",
	"UI_NEXT_DAY": "下一天",
	"UI_NEW_RUN": "重新开局",
}

const EN := {
	"UI_DAY_NODE_GOLD": "Day %d · Node %d · Gold %d",
	"UI_TEAM_BENCH": "Party %d/4 · Bench %d",
	"UI_ROUTE_TITLE": "Choose Route",
	"UI_ROUTE_PROMPT": "Choose the next stop:",
	"UI_ROUTE_ENTRY": "%s · %s\n  Reward: %s\n  Risk: %s",
	"UI_ROUTE_KIND_BATTLE": "Battle",
	"UI_ROUTE_KIND_SHOP": "Shop",
	"UI_ROUTE_KIND_REWARD": "Reward",
	"UI_ROUTE_KIND_EVENT": "Event",
	"UI_ROUTE_KIND_REST": "Rest",
	"UI_ROUTE_BENEFIT_BATTLE": "Win rewards and advance the route",
	"UI_ROUTE_BENEFIT_SHOP": "Trade gold for pets, skills, or upgrades",
	"UI_ROUTE_BENEFIT_REWARD": "Gain a pet or growth resource",
	"UI_ROUTE_BENEFIT_EVENT": "Resolve the current node effect",
	"UI_ROUTE_BENEFIT_REST": "Recover and prepare the party",
	"UI_ROUTE_RISK_BATTLE": "Enemy intents and health loss",
	"UI_ROUTE_RISK_SHOP": "Costs gold and stock is limited",
	"UI_ROUTE_RISK_REWARD": "You must choose between rewards",
	"UI_ROUTE_RISK_EVENT": "Outcome depends on event rules",
	"UI_ROUTE_RISK_REST": "Usually offers no battle reward",
	"UI_SHOP_TITLE": "Shop",
	"UI_STALL": "Stall: %s",
	"UI_TAGS": "Focus: %s",
	"UI_REFRESH_FREE": "Refresh: Free (%d left)",
	"UI_REFRESH_COST": "Refresh: %d gold",
	"UI_OFFER_AVAILABLE": "%s · %s · %d gold · Available",
	"UI_OFFER_UNAFFORDABLE": "%s · %s · %d gold · Need %d more",
	"UI_OFFER_SOLD": "%s · Sold",
	"UI_OFFER_EFFECT": "  Effect: %s",
	"UI_BAG_TITLE": "Bench",
	"UI_BAG_NEXT": "Next Page",
	"UI_BAG_NEXT_PAGE": "Next Page (%d/%d)",
	"UI_BAG_SUMMARY": "%d pets on the bench, page %d/%d.\nSelect a pet for details; drag to deploy, swap, or sell.",
	"UI_REWARD_TITLE": "Choose Reward",
	"UI_REWARD_PROMPT": "Inspect a reward, then confirm your choice:",
	"UI_RESULT_SUCCESS": "✓ %s",
	"UI_RESULT_FAILURE": "Not completed: %s",
	"UI_RESULT_NO_COINS": "Not enough gold; you have %d and need %d.",
	"UI_RESULT_PURCHASED": "Purchased %s. %d gold remains.",
	"UI_RESULT_REFRESHED": "Shop refreshed. %d gold remains.",
	"UI_RESULT_COMMAND_ACCEPTED": "Completed: %s",
	"UI_RESULT_COMMAND_REJECTED": "No effect: %s",
	"UI_REFRESH_SHOP": "Refresh Shop",
	"UI_CONTINUE": "Continue",
	"UI_LOCAL_SAVE": "Local Saves",
	"UI_SAVE_SLOT": "Save %d",
	"UI_LOAD_SLOT": "Load %d",
	"UI_EXPORT_REPLAY": "Export Replay",
	"UI_EXPORT_TRACE": "Export Trace",
	"UI_ACTION_TITLE": "Actions · Round %d",
	"UI_ACTION_NO_SELECTION": "No pet selected",
	"UI_ACTION_SELECT_PET": "Select one of your pets on the board",
	"UI_ACTION_PREVIEW": "Preview: %d red target cells · %d skills resolve left to right",
	"UI_ACTION_RESET_READY": "Reset Pets (%d available)",
	"UI_ACTION_RESET_THRESHOLD": "Reset Pets (alive ≤ %d, %d available)",
	"UI_ACTION_RESET_WAIT": "Reset Pets (+1 on round %d, wait %d)",
	"UI_ACTION_ALL_OUT": "Trigger All Skills in Order",
	"UI_ACTION_END_TURN": "End Player Turn",
	"UI_ACTION_MONSTER_TURN": "Run Enemy Turn",
	"UI_ACTION_SKILL_TOOLTIP": "Drag to another slot, or confirm this slot and then confirm its destination",
	"UI_ACTION_EXECUTING": "Executing · Waiting for authoritative Trace",
	"UI_ACTION_PICKED": "Slot %d selected · Choose its destination",
	"UI_ACTION_QUEUE_HINT": "Skill Queue · Drag or confirm to reorder",
	"UI_ACTION_FLOW_EXECUTING": "1  Selected   →   2  Confirmed   →   3  Executing…",
	"UI_ACTION_FLOW_RESULT": "✓  Complete   ·   Review the result and continue",
	"UI_ACTION_FLOW_PREVIEW": "1  Selected   →   2  Red Preview   →   3  Ready",
	"UI_ACTION_FLOW_SELECT": "1  Select Pet   ·   2  Preview   ·   3  Execute",
	"UI_ACTION_SKILL_COUNT": "%d skills",
	"UI_ACTION_COMBO_COUNT": "%d combos",
	"UI_ACTION_DAMAGE": "%d damage (HP %d / Shield %d)",
	"UI_ACTION_RESULT": "Result: %s",
	"UI_DEBUG_COLLAPSE": "Hide Debug",
	"UI_DEBUG_DATA": "Data Debug",
	"UI_SELL": "Sell",
	"UI_DIFFICULTY_LABEL": "Positioning: %s",
	"UI_DIFFICULTY_EASY": "Easy",
	"UI_DIFFICULTY_NORMAL": "Normal",
	"UI_DIFFICULTY_TOOLTIP": "Normal keeps each pet's attack direction; Easy may optimize direction while positioning.",
	"UI_POSITION_CALCULATING": "Calculating position…",
	"UI_POSITION_FAILED": "%s positioning: Failed",
	"UI_POSITION_MOVED": "%s positioning: Moved %d pets",
	"UI_POSITION_OPTIMAL": "%s positioning: Already optimal",
	"UI_TERMINAL_BATTLE": "Battle Result",
	"UI_TERMINAL_DAY": "Day Result",
	"UI_TERMINAL_GAME": "Run Complete",
	"UI_CURRENT_GOLD": "Current gold: %d.",
	"UI_BATTLE_RESULT": "%s · Grade %s\nGold %d → %d\nRound %d · %s",
	"UI_OUTCOME_DRAW": "Draw",
	"UI_OUTCOME_WIN": "Victory",
	"UI_OUTCOME_LOSS": "Defeat",
	"UI_CONTINUE_SETTLEMENT": "Continue",
	"UI_NEXT_DAY": "Next Day",
	"UI_NEW_RUN": "New Run",
}

static var _registered := false
static var _developer_tools := false
static var _locale := DEFAULT_LOCALE
static var _translation_resources: Array[Translation] = []


static func install(args: PackedStringArray = PackedStringArray()) -> void:
	var resolved_args := args if not args.is_empty() else OS.get_cmdline_user_args()
	_register_translations()
	_developer_tools = parse_developer_tools(resolved_args)
	_locale = parse_locale(resolved_args)
	TranslationServer.set_locale(_locale)


static func developer_tools_enabled() -> bool:
	return _developer_tools


static func current_locale() -> String:
	return _locale


static func parse_developer_tools(args: PackedStringArray) -> bool:
	for raw_value in args:
		var value := String(raw_value).strip_edges().to_lower()
		if value == "--developer-tools" or value == "--ui-mode=developer" or value == "--ui-mode=debug":
			return true
	return false


static func parse_locale(args: PackedStringArray) -> String:
	for raw_value in args:
		var value := String(raw_value).strip_edges()
		if not value.begins_with("--locale="):
			continue
		var requested := value.trim_prefix("--locale=").replace("-", "_")
		if requested.to_lower().begins_with("en"):
			return "en"
		if requested.to_lower().begins_with("zh"):
			return "zh_CN"
	return DEFAULT_LOCALE


static func text(key: String, values: Array = []) -> String:
	var translated := String(TranslationServer.translate(StringName(key)))
	return translated if values.is_empty() else translated % values


static func _register_translations() -> void:
	if _registered:
		return
	_registered = true
	_add_translation("zh_CN", ZH_CN)
	_add_translation("en", EN)


static func _add_translation(locale: String, messages: Dictionary) -> void:
	var translation := Translation.new()
	translation.locale = locale
	for key in messages.keys():
		translation.add_message(StringName(String(key)), StringName(String(messages[key])))
	TranslationServer.add_translation(translation)
	_translation_resources.append(translation)
