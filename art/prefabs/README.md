# Art 预制体工作区

这里是美术直接维护的 Godot 预制体目录。表现脚本统一放在 `res://core_ui/scripts/`。

## 目录

```text
art/prefabs/
├── shared/   两个以上 Art 场景实际共用的表现预制体
├── route/    路线、商店、背包、队伍和结算流程使用的预制体
└── battle/   战斗场景使用的棋盘、单位、HUD 和特效预制体
```

## 放置规则

- 每个预制体使用英文 ASCII `snake_case` 命名。
- `.tscn` 按 scope 和组件分类；专用 `.gd` 在 `core_ui/scripts/` 使用相同 scope 对应：

```text
art/prefabs/battle/damage_number/
└── damage_number.tscn

core_ui/scripts/battle/prefabs/effects/
└── damage_number.gd
```

- 图片引用 `art/images/<scope>/` 下的唯一资源，不在预制体目录复制素材。
- 脚本只负责布局、动画、输入、信号和公开显示接口，不创建 `GameSession`、`YsbzsState`、正式 Snapshot 或第二套玩法状态。
- 运行时才显示的特效可以作为真实预制体被 Art 场景引用，但在场景目录或 `PrefabInventory` 中必须默认隐藏。
- 禁止恢复 `features/**/prefabs` 或 `shared/prefabs` 兼容副本；正式预制体只以这里的版本为准。
