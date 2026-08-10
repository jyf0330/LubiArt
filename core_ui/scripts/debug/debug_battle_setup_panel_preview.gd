extends Control

const PREVIEW_SEED := "ysbzs-debug-first-battle-v1"
const PREVIEW_PETS := [
	{"petId": "pal_001", "name": "棉角羊", "quality": "青铜", "role": "治疗", "maxHp": 28, "atk": 8, "ap": 3},
	{"petId": "pal_002", "name": "灰尾狸", "quality": "黄金", "role": "治疗", "maxHp": 58, "atk": 18, "ap": 3},
	{"petId": "pal_003", "name": "芦花鸡", "quality": "白银", "role": "机动", "maxHp": 40, "atk": 12, "ap": 5},
	{"petId": "pal_006", "name": "碧水鸭", "quality": "青铜", "role": "坦克", "maxHp": 42, "atk": 6, "ap": 3},
	{"petId": "pal_011", "name": "冰背獭", "quality": "黄金", "role": "控制", "maxHp": 50, "atk": 22, "ap": 4},
	{"petId": "pal_028", "name": "药草兔", "quality": "青铜", "role": "治疗", "maxHp": 28, "atk": 8, "ap": 3},
	{"petId": "pal_030", "name": "花刺蛛", "quality": "青铜", "role": "坦克", "maxHp": 48, "atk": 4, "ap": 2},
	{"petId": "pal_042", "name": "赤焰蛮牛", "quality": "青铜", "role": "输出", "maxHp": 28, "atk": 12, "ap": 3},
]


func _ready() -> void:
	$DebugBattleSetupPanel.set_catalog({
		"pets": PREVIEW_PETS,
		"defaults": {
			"playerPetIds": ["pal_002", "pal_011", "pal_028", "pal_030"],
			"enemyPetIds": ["pal_001", "pal_042", "pal_006", "pal_003"],
		},
	}, PREVIEW_SEED)
