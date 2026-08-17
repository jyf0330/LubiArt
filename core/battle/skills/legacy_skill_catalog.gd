extends RefCounted

## Compatibility metadata for legacy skill ids that can still appear on units
## outside the content-pack skill catalog. New content belongs in
## data/content; this owner only prevents projection fallbacks from living on
## the authoritative state base.

const LABELS := {
	"buffAllSummons": "召唤强化",
	"castleReduce": "守护减伤",
	"spaceExplosionBonus": "爆点轰击",
	"healAmpBonus": "疗愈增幅",
	"advHitBonus": "牵制追击",
	"summonFromCell": "格位召唤"
}
const DESCRIPTIONS := {
	"buffAllSummons": "召唤行动：本次施放后鼓舞我方单位，攻击+1。",
	"castleReduce": "阻挡行动：施放后获得护盾，并让下一次受击减伤。",
	"spaceExplosionBonus": "输出行动：火系命中附加爆点伤害，空作用格追加火层。",
	"healAmpBonus": "场地行动：水系施放后治疗受伤我方。",
	"advHitBonus": "牵制行动：命中后削弱目标行动力。",
	"summonFromCell": "召唤行动：以作用格作为召唤落点。"
}


static func snapshot_entries() -> Dictionary:
	var result := {}
	for skill_id_value in LABELS.keys():
		var skill_id := String(skill_id_value)
		result[skill_id] = {
			"id": skill_id,
			"name": String(LABELS.get(skill_id, skill_id)),
			"description": String(DESCRIPTIONS.get(skill_id, ""))
		}
	return result
