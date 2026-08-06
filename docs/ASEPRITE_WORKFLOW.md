# Aseprite 导出流程

项目通过 `tools/export_aseprite.ps1` 使用本机 Aseprite 导出资源。Godot 只依赖导出的 PNG、GIF 和 JSON，不依赖 Aseprite 安装路径，也不会把本机绝对路径写进交付文件。

## 检查接入

在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_aseprite.ps1 -CheckOnly
```

工具按以下顺序寻找 Aseprite：命令参数 `-AsepritePath`、当前终端的 `ASEPRITE_PATH`、系统 PATH、Windows 安装信息、Steam 与常见安装目录。本机已验证的版本是 Aseprite 1.3.18.1。

## 导出动画

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_aseprite.ps1 `
  -Source "D:\art_source\wind_cat_idle_v1.aseprite" `
  -AssetPath "shared/pets/animations/wind_cat/idle_v1" `
  -Name "wind_cat_idle_v1"
```

如果只导出 Aseprite 中的一个动画标签，追加 `-Tag "idle"`。总览图默认每行最多 8 帧，可通过 `-Columns 6` 调整。

`AssetPath` 是 `art/images/` 与 `art/manifests/` 下共用的相对 scope，必须使用英文 ASCII 小写 `snake_case`。`Name` 同样必须使用小写 `snake_case`。工具不会覆盖同名成果；迭代时应使用新的版本目录或名称，例如把 `idle_v1` 改为 `idle_v2`。

一次成功导出会得到：

```text
art/images/<asset_path>/
├── frames/<name>_frame_001.png
├── frames/<name>_frame_002.png
├── <name>_overview.png
└── <name>_preview.gif

art/manifests/<asset_path>/
├── <name>_aseprite_sheet.json
└── <name>_aseprite_export.json
```

逐帧 PNG 保持 Aseprite 的统一画布和透明通道；GIF 直接由同一 `.aseprite` 文件和同一标签导出。导出后，工具会再次用 Aseprite 逐帧解码 GIF，并核对帧数、顺序、像素和时长；任一项不同都会停止交付。项目清单记录验证结果、每帧时长、相对资源路径和 SHA-256。打开或重新聚焦 Godot 编辑器后，新增 PNG 会按项目资源正常导入。

## 制作源边界

`.ase` 和 `.aseprite` 是外部制作源，不放进 `art/images/`。`art/images/` 只保存 Godot 使用或美术验收所需的图片；运行时资源映射 JSON 放在对应的 `art/manifests/` scope。正式 Scene、prefab、脚本和节点结构不会被导出工具修改。
