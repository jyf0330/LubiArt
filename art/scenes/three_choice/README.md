# 三选一正式 Scene

正式三选一展示 Scene：`three_choice_scene.tscn`。项目启动入口是 `res://art/scenes/app/game.tscn`。

## 脚本边界

- `ThreeChoiceScene` 直接只挂一个根展示脚本 `three_choice_scene.gd`，负责绑定现有节点、渲染 Snapshot、切换显隐、播放动效并发出操作请求。
- `ThreeChoiceScene` 不创建、不保存也不执行 GameSession；Session、Command、持久化和战斗路由统一由 `app/game.tscn` 的 `game_controller.gd` 负责。
- 跨 Scene 时只发送语义 Command；它不发送“创建/释放战斗 Scene”的路由请求。Game 先根据返回 Snapshot 挂载所需 Feature，三选一完成画面过渡后只报告 `presentation_settled`。
- `MainBG` 与 `Middle` 都是可视布局分组，不再挂脚本。
- `MainBG` 下的普通图片、容器、槽位和按钮不逐个挂脚本。
- 三张 `ThreeChoiceCard` 的静态位置、尺寸和各自高亮纹理都直接保存在 `.tscn`；卡片脚本只负责换图和显隐表现。
- 三张路线卡、八个商店槽、八个背包槽和四个队伍槽都是数量固定、构图需要在编辑器中完整可见的实例，因此显式保存在 `.tscn`。纯布局槽位与 `HitArea` 不单独包装成 prefab；背包与队伍槽中的 `PetVisual` 继续实例化同时具备图片和表现代码的正式 `pet.tscn`。
- 每个槽内 `HitArea` 的静态位置和尺寸直接保存在 Scene 中，根脚本只连接输入与写入展示数据。
- 是否把固定槽位中的完整宠物改为按需挂载或池化，只能依据目标平台要求和 Profiler 结果决定。把相同数量的实例从 `.tscn` 改为启动时创建不算内存优化，也不得以此牺牲美术直接编辑最终构图的能力。
- `ItemSlotHoverHighlight` 是可在编辑器中选中的正式节点，根脚本只移动和显示它，不在运行时临时创建。
- `DragPreview` 是根下预先创作的隐藏节点；拖拽期间根脚本只换图、调整到来源槽尺寸、移动和显隐，不再向运行时 SceneTree 临时拼装预览节点。
- 根下 `AnimationPlayer`、`BazaarInfoPanel` 与 `ArtistPetDetailPanel` 分别是动画和复用 UI prefab；`FeatureHost` 与 `GameCursor` 已归到 Game 装配 Scene。

禁止为了脚本图标给普通图片或按钮增加空脚本；三选一展示行为先归到根展示脚本，只有具备独立状态、动画、复用或公开接口时才做成独立 prefab。
