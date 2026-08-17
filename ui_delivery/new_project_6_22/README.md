# new_project_6_22 PSD 转换包

源文件：`source/new_project_6_22.psd`

原始来源：`/Users/ywh/Downloads/新建项目6.22.psd`

## 产物

```text
preview/battle_main_ref.png
preview/battle_main_assets_contact_sheet.png
export/ui/battle_main/*.png
layout/battle_main_layers.json
layout/battle_main_name_mapping.csv
notes/battle_main_notes.md
```

## 当前导出结果

- 画布：`1080x1920`
- 叶子图层：`85`
- 可见叶子图层：`83`
- 已导出图片资产：`41`
- 需要在 Godot 重建的文本/数值层：`42`
- 隐藏未导出层：`2`

## Godot 使用方式

- `preview/battle_main_ref.png`：整屏对齐参考图，不作为运行时 UI。
- `preview/battle_main_assets_contact_sheet.png`：导出资产总览图，用于快速核对切图。
- `export/ui/battle_main/*.png`：可进入 Godot 的 Texture 资产。
- `layout/battle_main_layers.json`：图层坐标、尺寸、角色分类和 Godot 节点建议。
- `layout/battle_main_name_mapping.csv`：原 PSD 图层名到英文资源名的映射。
- `notes/battle_main_notes.md`：本次转换备注。

## 必须重建为 Godot 控件

`layout` 里 `role=godot_label` 的层不要直接使用图片，必须在 Godot 中创建 `Label` 或 `RichTextLabel`。这些包括 HP/AP/数值/技能说明/状态文案等动态内容。

按钮目前只按图层导出了视觉资产。真正点击区域、禁用状态、按下状态需要在 Godot 场景里用 `Button` 或 `TextureButton` 明确配置。

## 复跑命令

```bash
python3 -m venv /tmp/godot-psd-venv
/tmp/godot-psd-venv/bin/pip install -r tools/requirements-psd.txt
/tmp/godot-psd-venv/bin/python tools/psd_to_godot_export.py \
  /Users/ywh/Downloads/新建项目6.22.psd \
  --out ui_delivery/new_project_6_22 \
  --screen-name battle_main
```
