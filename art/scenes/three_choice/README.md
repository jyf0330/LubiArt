# 三选一正式 Scene

正式三选一展示 Scene：`three_choice_scene.tscn`。项目启动入口是 `res://art/scenes/app/game.tscn`。

## 脚本边界

- `ThreeChoiceScene` 直接只挂一个根展示脚本 `three_choice_scene.gd`，负责绑定现有节点、渲染 Snapshot、切换显隐、播放动效并发出操作请求。
- `ThreeChoiceScene` 不创建、不保存也不执行 GameSession；Session、Command、持久化和战斗路由统一由 `app/game.tscn` 的 `game_controller.gd` 负责。
- 跨 Scene 时只发送语义 Command；它不发送“创建/释放战斗 Scene”的路由请求。Game 先根据返回 Snapshot 挂载所需 Feature，三选一完成画面过渡后只报告 `presentation_settled`。
- `MainBG` 与 `Middle` 都是可视布局分组，不再挂脚本。
- `MainBG` 下的普通图片、容器、槽位和按钮不逐个挂脚本。
- 三张 `ThreeChoiceCard` 的静态位置、尺寸和各自高亮纹理都直接保存在 `.tscn`；卡片脚本只负责换图和显隐表现。
- `ItemSlotHoverHighlight` 是可在编辑器中选中的正式节点，根脚本只移动和显示它，不在运行时临时创建。
- 根下 `AnimationPlayer`、`BazaarInfoPanel` 与 `ArtistPetDetailPanel` 分别是动画和复用 UI prefab；`FeatureHost` 与 `GameCursor` 已归到 Game 装配 Scene。

禁止为了脚本图标给普通图片或按钮增加空脚本；三选一展示行为先归到根展示脚本，只有具备独立状态、动画、复用或公开接口时才做成独立 prefab。
