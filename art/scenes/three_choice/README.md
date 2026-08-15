# 三选一正式 Scene

正式三选一展示 Scene：`three_choice_scene.tscn`。项目启动入口是 `res://art/scenes/app/game.tscn`。

本 Scene 后续再做节点或脚本优化前，必须先确认货架、路线卡、槽位、面板等散图已经整理为经确认的 Godot 专用 PSD，并在 `.tscn` 中完成真实装配与 1920×1080 可见验收。若仍是临时散图拼装，先提醒并补完美术装配，不得以“重复节点”为由继续删改结构。

当前前置状态：`art/manifests/route/three_choice/psd_layer_manifest.json` 只记录旧 PSD 的导出图层、包围盒和图片路径，仍包含项目外绝对源路径，也没有 Godot 专用 PSD 所需的渲染单元分类、动态字段、交互状态与九宫格信息，因此尚不能视为已确认的 Godot 专用 PSD。后续结构优化暂停在此门槛；先由美术侧或项目方整理并确认 Godot 专用 PSD 与新 manifest。

## 脚本边界

- `ThreeChoiceScene` 直接只挂一个根展示脚本 `three_choice_scene.gd`，负责绑定现有节点、渲染 Snapshot、切换显隐、播放动效并发出操作请求。
- `ThreeChoiceScene` 不创建、不保存也不执行 GameSession；Session、Command、持久化和战斗路由统一由 `app/game.tscn` 的 `game_controller.gd` 负责。
- 跨 Scene 时只发送语义 Command；它不发送“创建/释放战斗 Scene”的路由请求。Game 先根据返回 Snapshot 挂载所需 Feature，三选一完成画面过渡后只报告 `presentation_settled`。
- `MainBG` 与 `Middle` 都是可视布局分组，不再挂脚本。
- `.tscn` 只保留背景、路线卡容器、共享 `RouteSharedUi` 实例和路线辅助面板等真实构图节点；商店已迁入独立 `ShopScene`，普通图片和容器不挂脚本。
- `CardGrid` 在 `.tscn` 中直接保留三张正式 `three_choice_card.tscn` 实例；白小常、采药商、矮武士三个 `Portrait` 资源以及三套卡片矩形、图标和逐卡高亮都能在 Godot 编辑器中直接选中检查。根脚本只按 Snapshot 更新内容与交互状态，不再运行时创建路线卡。
- 背包八格由根脚本在共享 prefab 的已有容器中按 Snapshot 生成，队伍四格直接 authored 在共享 prefab；每格只有一个 `TextureButton`。独立 `ShopScene` 固定保留五个 `Button` 商品叶子，不再沿用旧八格 `Middle_Shop`。
- 背包和队伍缩略图只显示一张宠物贴图，因此不再实例化包含战斗状态、攻击动画和特效脚本的完整 `pet.tscn`；正式战斗 Scene 仍继续使用该公开 prefab。
- 槽位数量、尺寸、间距、集合缩略图裁切和路线卡差异集中在根脚本常量中；修改这些常量后必须完成 1920×1080 真实窗口和多操作逐像素回归。
- `RouteSharedUi/ItemSlotHoverHighlight` 是可在编辑器中选中的正式节点，页面根脚本只移动和显示它，不在运行时临时创建。
- `DragPreview` 只在拖拽期间作为单个临时 `TextureRect` 存在，释放拖拽状态后立即移除；Scene 不再常驻空预览节点。
- 原空 `AnimationPlayer`、旧 `Middle_Shop` 与从未进入可见状态的旧信息面板已删除；页面切换继续使用 Presenter 的 Tween 路径。`ArtistPetDetailPanel` 随 `RouteSharedUi` 共用，`FeatureHost` 与 `GameCursor` 在 Game 装配 Scene。

禁止为了脚本图标给普通图片或按钮增加空脚本；三选一展示行为先归到根展示脚本，只有具备独立状态、动画、复用或公开接口时才做成独立 prefab。
