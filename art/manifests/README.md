# Art Manifests

本目录只放运行图片的 JSON 映射和 manifest；真实图片放在相同 scope 的 `art/images/`。

```text
art/manifests/
├── battle/                 战斗资源表与敌方图片映射
├── route/rewards/          奖励节点映射
├── route/shop/characters/  商店角色映射
└── shared/pets/sheets/     共享宠物 ID 与切片映射
```

规则：

- JSON 路径和图片 scope 保持对应，但不把 JSON 混进 `art/images/`。
- manifest 只描述资源路径、ID 和映射，不保存玩法权威状态或策划数值。
- 场景放 `art/scenes`，预制体放 `art/prefabs`，脚本放 `core_ui/scripts`。
