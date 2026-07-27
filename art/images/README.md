# Art Images

本目录只放 Godot 运行时使用的图片及其 Godot `.import` sidecar。

```text
art/images/
├── battle/          战斗背景、英雄、宠物、按钮与特效
├── route/           路线、商店、奖励和主流程底图
├── shared/pets/     多个界面共用的宠物图、详情卡与切片映射
└── debug/           仅供美术预览工具使用的调试图片
```

规则：

- 图片按“实际使用界面”分类，不再按旧压缩包名称分成 `artist_ui` / `battle_ui` 根目录。
- 同一份运行图片只有一个正式路径；不同界面通过 resolver 或 manifest 引用，不复制一份。
- 图片的 `.import` 与原图放在一起；JSON 映射和 manifest 放在相同 scope 的 `art/manifests/`。
- `.tscn` 放 `art/scenes` 或 `art/prefabs`，`.gd` 放 `core_ui/scripts`，JSON 放 `art/manifests`，不要混进图片目录。
- PSD、Figma 导出工程和只读美术压缩包仍是外部制作来源，不直接放进运行图片目录。
