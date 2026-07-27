# Route Art Prefabs

供路线以及同一 authored 流程中的商店、背包、队伍和结算场景使用。

- 保留美术制作的节点层级、位置、尺寸、动画和槽位。
- `.tscn` 留在本目录；专用表现脚本放在 `res://core_ui/scripts/route/`、`shop/`、`inventory/`、`party/` 或 `settlement/`。
- 脚本通过公开方法和信号接收数据，不直接持有权威游戏状态。
