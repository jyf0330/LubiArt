# SpriteInfoCard 独立调试面板

本目录是独立调试 Scene，不属于战斗 Scene。

场景文件：`res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn`

既可以在 Godot 中直接打开并运行该 `.tscn`，也可以使用启动脚本：`res://tests/sprite_info_card_debug/run_sprite_info_card_debug.gd`

命令：

```text
godot --path . --script res://tests/sprite_info_card_debug/run_sprite_info_card_debug.gd
```

功能：

- 使用按钮循环切换六个 2 至 4 字的中文宠物名，并写入 `PetName`。
- 下拉选择九种 `ElementArt`。
- 下拉选择青铜、白银、黄金、水晶；只显示当前品质，并同步 `BaseArt`、`AttackFormatPlate`、`StatSlotArt`。
- 调整六项 Value。
- 显示或隐藏 `TraitLockSilver`；隐藏后可下拉选择八种 `TraitArt`。
