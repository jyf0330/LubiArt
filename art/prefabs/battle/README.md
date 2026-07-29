# Battle Art Prefabs

本目录只保留战斗 prefab 的职责说明，不放额外 `.tscn`。正式战斗 prefab 仍只有 `pet/pet.tscn`、`pet/pet_detail.tscn`、`terrain/terrain.tscn` 和 `terrain/terrain_detail.tscn`。

- 保留 authored 坐标、尺寸、层级和动画时机。
- 宠物攻击、受击、移动、死亡、跨格投射物与伤害数字由 `pet.tscn` 的表现脚本创建。
- 地面元素标记与命中特效由 `terrain.tscn` 的表现脚本创建。
- 回合横幅留在正式战斗 Scene 的事件编排层。
- 不在预制体脚本里复制伤害、血量、护盾或回合权威状态。
