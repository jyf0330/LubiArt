# 四个公开预制体与两个内部 UI 组件

本目录包含四个跨流程公开 prefab，以及两个可独立编辑的内部 UI 组件：

```text
art/prefabs/
 ├── battle/
 │   └── hud/
 │       └── attack_direction_drawer.tscn
 ├── pet/
 │   ├── pet.tscn
│   ├── pet_detail.tscn
│   └── sprite_info_card.tscn
└── terrain/
    ├── terrain.tscn
    └── terrain_detail.tscn
```

- `pet.tscn`：三选一、队伍、背包和战斗共同使用的宠物视觉与交互根。
- `pet_detail.tscn`：三选一和战斗共同使用的正式宠物详情、遮罩、确认操作和卡面；不包含调试节点，也不创建 Session。
- `sprite_info_card.tscn`：由宠物详情实例化的内部卡片组件，可在独立美术调试 Scene 中直接检查。
- `attack_direction_drawer.tscn`：由正式战斗 Scene 实例化的内部 HUD 组件，保留四行方向、收起按钮和固定显示尺寸。
- `terrain.tscn`：战斗棋盘重复实例化的地形格。
- `terrain_detail.tscn`：战斗中查看地形元素、威胁和预览的详情面板。

战斗单位四角数值按美术参考固定为：左上生命、右上“单次受到伤害上限”、左下攻击、右下当前护盾。例如上限为 8 时，10 点攻击最终最多造成 8 点伤害，6 点攻击仍造成 6 点；正式战斗事件会先扣护盾，再扣生命。四枚图标随棋盘透视统一缩放，后排较小、前排较大；所有纵深的角标都收在本格内部并保留边缘间距，避免遮挡相邻单位的角标。数值文字同步缩放并始终在各自图标内水平、垂直居中。Mock 只读取公开 Snapshot 中的上限、护盾及 `shieldDamage` / `hpDamage` 结果，不在表现层重新计算规则；Snapshot 没有提供伤害上限时，右上灰锁不显示。

宠物攻击、受击、移动、死亡、跨格投射物和伤害数字属于 `pet.tscn`；地面元素标记与命中特效属于 `terrain.tscn`。攻击方向抽屉属于独立内部 HUD prefab；`SpriteInfoCard` 数据调试只存在于独立的 `sprite_info_card_debug_scene.tscn`，不混入正式宠物详情 prefab。

对应脚本统一放在 `res://core_ui/scripts/`，图片统一放在 `res://art/images/`。额外 prefab 必须是有独立编辑或调试价值的 UI 组件，不能复制正式运行实现。

## PSD 功能层与资源层

- PSD 中对运行时有职责的分组要进入 prefab 节点树。例如宠物详情的底板、攻击格式盘子、数值格子、数值 UI、特性格子、属性、外框、攻击格式标题和宠物名字。
- `same` 只表示同一槽位可替换的一组图片资源，不是运行时功能层。它下面的青铜、白银、黄金、水晶等图片直接放入对应功能组，不创建 `Same` 节点，也不挂脚本。
- 有切图的功能分层根必须自己是 `TextureRect` / `Sprite2D` 等图片节点并直接持有当前图片，节点位置与尺寸等于图片的 authored 边界；不得用空 `Control`、0×0 容器或整屏透明矩形冒充分层根。品质、元素等 `same` 变体由表现脚本替换根纹理和对应图片矩形。
- 一个功能层包含多张同时可见图片时，选择其中第一张正式图片作为根节点图片，其余图片按 PSD 相对坐标作为子图片；动态文本层直接使用匹配 PSD 边界的 `Label`，不额外包空节点。
- 动态名称、数值、元素和攻击形状继续由表现脚本写入；图片资源分组不得持有 Session、Snapshot 或玩法状态。
