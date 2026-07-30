# 战斗界面美术专用 Mock

## 项目定位

这是交付给美术独立使用的 Godot UI 项目，用于制作和检查战斗界面、场景、预制体、资源、交互和动画。

- 使用者只需要本项目和兼容的 Godot，不需要拥有、访问或了解原项目。
- 本项目必须能够离线独立打开、运行、修改和验收，不得依赖原项目路径或原项目文件。
- 本项目不是正式玩法、战斗规则、存档或策划数值的真相源。
- Mock 中表现正常，只能证明展示和接口联调正常，不能代替正式项目的玩法验收。
- 公共 Snapshot 词汇来自交付时的正式接口契约；使用者不需要连接正式项目。

## 数据边界

- 运行时数据只能由 `session/mock_game_session.gd` 从 `data/mock_battle_snapshot.json` 提供。
- `data/mock_battle_snapshot.json` 必须由项目方在正式项目中通过公开 `LocalGameSession` 读取存档槽2，再真实运行“进入战斗 → 每回合自动布置一次 → 开始行动一次 → 战斗结算”后导出；禁止手写敌我站位、伤害、元素、回合或结算数据。
- Mock 只离线回放导出的公共 Snapshot 和命令结果；禁止导入正式存档、权威战斗服务、正式状态对象或表格导出的平衡数据，运行时也不得依赖正式项目路径。
- 数据回放和 Mock 适配只能修改 `session/`、`core/`、`data/`、`tests/` 和项目文档；如果正式项目契约发生变化，由项目方重新运行导出器刷新数据。
- 正式玩法或数值需求必须回到正式项目及其策划数据链处理，不能在这里先造一套规则。

## 目录职责

- `art/scenes/`：保留与正式项目同步的两个正式 Scene：`three_choice/three_choice_scene.tscn` 与 `battle/battle_art_scene.tscn`，以及独立美术调试 Scene `sprite_info_card_debug/sprite_info_card_debug_scene.tscn`；项目仍直接从三选一 Scene 启动。
- `art/prefabs/`：保留四个公开 prefab：`pet/pet.tscn`、`pet/pet_detail.tscn`、`terrain/terrain.tscn`、`terrain/terrain_detail.tscn`，以及宠物详情内部组件 `pet/sprite_info_card.tscn`。
- `art/images/`：只放图片与相邻的 Godot `.import` 文件。
- `art/manifests/`：只放图片资源映射和 manifest JSON。
- `core_ui/scripts/`：按 scope 分类的 Controller、Presenter、Adapter 和预制体表现脚本。
- `session/`：正式公共会话接口的 Mock 实现边界。

## 可修改范围

- 美术任务可以直接修改 `art/scenes/`、`art/prefabs/`、`art/images/`、`art/manifests/` 和 `core_ui/scripts/` 中的场景、展示脚本、预制体、节点结构、布局、动画、资源及资源引用。
- 可以为演示需要修改 `session/`、`core/`、`data/`、`tests/` 和项目文档，但不得在其中建立正式玩法、数值或存档实现。
- 不得引入指向原项目、本机其他目录或某位开发者电脑的绝对路径。
- 不得为了完成美术效果而接入正式存档、权威状态、战斗服务或策划数据链。

## 文件类型规则

- 三选一和战斗两个正式 `.tscn` 放 `art/scenes/<scope>/`；独立美术调试 Scene 也放在独立 scope 下，不接入正式路由。
- 宠物、宠物详情、地形、地形详情四个公开 `.tscn` 放 `art/prefabs/<scope>/`；允许把可独立编辑和调试的内部 UI 组件做成额外 prefab。
- `.png`、`.jpg`、`.webp`、`.svg` 等图片放 `art/images/<scope>/`。
- 图片映射和 manifest `.json` 放 `art/manifests/<scope>/`；Mock 回放数据仍放 `data/`。
- UI `.gd` 与 `.gd.uid` 放 `core_ui/scripts/<scope>/`。
- 不得恢复 `game/`、`features/`、`shared/prefabs/`、`assets/artist_ui/` 或 `assets/battle_ui/` 兼容副本。

## 交付与回集成

- 美术工作期间不要求本项目与原项目逐字节一致，也不要求美术人员同步原项目。
- 美术交付物就是修改后的完整独立项目；所有依赖资源必须包含在本项目中。
- 项目方收到交付后，另开 UI 集成任务审查差异并适配回正式项目。
- 回集成时只迁移确认过的 UI、预制体、展示脚本和资源，不得用本项目覆盖正式状态、规则、存档或数据文件。
- 原项目比较只属于项目方的可选集成检查，不是美术侧的开发或验收前置条件。
- 项目方主动同步正式 UI 时，以正式项目已提交的版本为基线；`session/`、`data/` 与 Mock 测试继续留在本项目，不从正式项目复制权威核心或存档实现。

## 命名与内容

- 文件名、目录名和节点名使用英文 ASCII。
- 中文只用于玩家可见文本和项目文档。
- 美术界面以真实 Godot 场景、节点、预制体和资源引用为准，不按截图重画近似版本。

## 预制体节点结构约束

- `.tscn` 中由美术明确制作的现有节点结构是界面与特效装配的唯一依据；展示脚本只能读取、配置、显示、隐藏或播放这些已有节点。
- Scene 与 prefab 的节点结构应尽量简单；同构、重复出现的视觉元素只保留一个可编辑的模板节点或一个独立 prefab，其余实例由展示脚本在运行时复制或实例化，禁止在 `.tscn` 中按数量手工堆叠重复节点。
- 元素子弹等仅在纹理、元素类型、颜色、数量或位置上不同的同类对象，必须共用一个通用节点或 prefab；脚本负责创建所需实例并配置差异，不得分别维护 `fire`、`water`、`earth`、`wind` 等重复节点树。
- 动态创建只用于上述同构重复实例；禁止展示脚本绕过已有模板、使用 `new()`、`add_child()` 等方式临时拼装未经美术定义的 UI、图片、飘字、弹道或特效节点结构。
- 未经使用者明确要求或确认，不得擅自新增、删除、改名、移动或重新挂载 Scene 与 prefab 中的节点。
- 如果实现需求确实缺少节点，必须先通知使用者，说明拟新增节点的名称、类型、父路径和用途；得到确认后才能修改节点结构。
- 测试和 Mock 适配必须服从已有预制体结构，不能为了让测试通过而反向添加预制体中不存在的节点。

## Godot 图片尺寸锁定

- Godot 运行时会按照图片的实际像素尺寸参与显示和控件最小尺寸计算；接入图片后必须在 `.tscn` 或展示脚本中显式锁定控件的显示宽高，不能只依赖纹理原始尺寸或编辑器预览。
- 需要缩放、裁切或使用透明留白图片时，必须同时固定 `TextureRect`、`TextureButton` 或承载节点的尺寸与位置；抽屉、按钮、点击区域和相邻图片不得因源图片画布大小改变而漂移。
- 涉及图片布局的交付必须在项目的 1920×1080 基准画布中运行检查，确认实际 Godot 窗口中的位置和大小后再验收。

## 完成与验收

- 每次改动后运行 `./tests/verify_ui_mirror.sh`，确认独立项目结构完整且文件类型没有串目录；默认检查不需要原项目。
- 运行 README 中的独立项目契约 smoke，确认 Mock Snapshot 和装配链仍可工作。
- 涉及布局、交互或动画时，必须在真实 Godot 窗口检查；headless smoke 不能代替可见结果。
- 美术侧只验收本项目中的可见结果和 Mock 交互，不负责正式玩法、战斗结算或存读档验收。
