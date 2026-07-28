# 三选一正式 Scene

正式入口：`three_choice_scene.tscn`

## 脚本边界

- `ThreeChoiceScene` 根节点挂 `game_controller.gd`，只负责 Session、Feature 路由和两个正式 Scene 的装配。
- 直接次级职责节点 `MainBG` 挂 `three_choice_surface.gd`，作为三选一、商店、背包、队伍和顶部区域的表现入口。
- `MainBG` 下的普通图片、容器、槽位和按钮不逐个挂脚本。
- `Middle` 保留 `artist_flow_controller.gd`，因为它独立持有路线 / 商店 / 背包流程状态、信号和稳定公开接口，属于特殊行为子节点。
- 根下 `AnimationPlayer`、`BazaarInfoPanel`、`ArtistPetDetailPanel`、`FeatureHost` 分别是动画、独立信息面板、复用详情 prefab 与战斗运行时挂载点，属于特殊节点，不与普通视觉子节点混同。

禁止为了脚本图标给普通图片或按钮增加空脚本；新增行为先归到 `MainBG` 分组脚本，只有具备独立状态、动画、复用或公开接口时才下放到特殊子节点。
