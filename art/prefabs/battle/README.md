# Battle Art Prefabs

本目录收纳战斗专用的内部 UI prefab。四个跨流程公开 prefab 仍为 `pet/pet.tscn`、`pet/pet_detail.tscn`、`terrain/terrain.tscn` 和 `terrain/terrain_detail.tscn`。

- `hud/attack_direction_drawer.tscn`：已从正式战斗 HUD 移除的独立历史组件；文件暂时保留，不在玩家流程实例化。
- `hud/attack_timeline.tscn`：战斗精灵技能释放时间轴，由 `battle_hud.tscn` 实例化；读取公共 Snapshot 中的玩家精灵，支持本地拖动排序、重置与释放节奏预览，不提交玩法命令。
- `hud/attack_timeline_pet_frame.tscn`：时间轴内可独立交互的宠物头像卡，封装底图、宠物图、边框和拖动状态表现。

- 保留 authored 坐标、尺寸、层级和动画时机。
- 宠物攻击、受击、移动、死亡、跨格投射物与伤害数字由 `pet.tscn` 的表现脚本创建。
- 地面元素标记与命中特效由 `terrain.tscn` 的表现脚本创建。
- 保留的攻击方向抽屉 prefab 只用于历史素材与独立检查，不接入正式玩家流程。
- 回合横幅留在正式战斗 Scene 的事件编排层。
- 不在预制体脚本里复制伤害、血量、护盾或回合权威状态。
