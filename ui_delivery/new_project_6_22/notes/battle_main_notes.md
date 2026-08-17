# battle_main PSD 转换记录

- 源 PSD：`/Users/ywh/Documents/godot/ui_delivery/new_project_6_22/source/new_project_6_22.psd`
- 画布：`1080x1920`
- 图层：`85` 个叶子图层，`83` 个可见叶子图层
- 已导出图片资产：`41` 个
- 整屏参考图：`preview/battle_main_ref.png`
- 布局 JSON：`layout/battle_main_layers.json`
- 命名映射：`layout/battle_main_name_mapping.csv`

## Godot 重建提醒

- `godot_label` 角色不要直接使用导出的图片，应在 Godot 里创建 `Label` 或 `RichTextLabel`。
- `image_asset`、`panel_asset`、`background` 可以作为 `TextureRect` / `NinePatchRect` 的纹理。
- 按钮需要人工确认点击区域和状态图；当前脚本只根据命名和图层信息做初步分类。
- 当前 PSD 的中文图层名已经在映射表里转换成 ASCII 建议名，后续美术应直接按规则命名。
