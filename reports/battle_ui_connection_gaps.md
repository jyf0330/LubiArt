# 战斗界面接入缺口

来源压缩包：`/Users/ywh/Downloads/棋盘-战斗界面_Godot完整可打开包_20260710_224332.zip`

## 已接入

- 压缩包本体保持只读；未导入 `.godot/`、zip 内 `project.godot` 或编辑器缓存。
- 运行时图片已复制到 `assets/battle_ui/**`，中文背景文件在项目副本中改为 ASCII 路径 `assets/battle_ui/images/battle_background.png`。
- 2026-07-11 复核 zip 运行时资源：`HeroImages` / `images` / `Prefabs` / `SpriteImages` 的非 `.import` 文件已 168/168 对齐；补入 `Prefabs/Monster_Bite` 下 4 张总图 / 预览图到 `assets/battle_ui/prefabs/monster_bite/`，`.import` 由 Godot 项目重新生成。
- 新增 `assets/battle_ui/battle_asset_manifest.json` 作为战斗图片资源入口；registry 只读取项目副本路径，不把 zip 缓存或 demo 规则当真相源。
- 新增 `assets/battle_ui/enemy_image_map.json` 作为敌方单位显式贴图表；首波 `enemy_r01_001 / pal_001 / 棉悠悠` 映射到 `Sprite_WoolLlama.png`，`enemy_r01_002 / pal_042 / 炽焰牛` 映射到 `Sprite_BrownBull.png`。
- 新增 `scenes/ui/battle_flow/battle_ui.tscn`，复用原包全屏背景、棋盘位置、自动站位按钮和开始行动按钮。
- 新增 `scenes/ui/battle_flow/prefabs/battle_cell.tscn` 和 `scenes/ui/battle_flow/prefabs/battle_unit.tscn`；棋盘格和单位显示由 prefab 承载坐标 / 单位数据 / 贴图 / 血量。
- 新增 `scripts/game/battle_asset_registry.gd`、`scripts/game/battle_cell.gd`、`scripts/game/battle_unit.gd`；`scripts/game/battle_ui_controller.gd` 只装配 8x8 prefab、转发按钮命令、收集缺映射。
- 新增 `scenes/ui/battle_flow/prefabs/battle_projectile.tscn`、`battle_damage_number.tscn`、`battle_round_banner.tscn` 和 `scripts/game/battle_vfx_player.gd`；VFX 预制体已可被统一播放器实例化，后续只需要接核心 battle trace。
- `battle_cell.gd` 已暴露 `set_highlight()`、`show_attack_order_marker()`、`show_effect_marker()`、`get_unit_node()` 等复用 API；`battle_unit.gd` 已暴露 `update_hp()`、`set_selected()`、`set_dead_mark()`、`play_shake()`、`move_to_position()` 等复用 API。
- 新增 `scenes/ui/battle_flow/prefabs/battle_bite_vfx.tscn` 和 `scripts/game/battle_bite_vfx.gd`，复用 zip 的 5 帧怪物咬击序列和帧时长。
- `BattleVfxPlayer` 已支持核心 trace：`MOVE_HERO` / movement、`DAMAGE_APPLIED`、`death`、`spawn_trap`、`round_start`、`shoot_projectile`、`melee_bite`。trace 进入统一队列顺序播放；玩家伤害按原包 `0.32s` 元素弹道后再显示伤害数字、受击抖动、HP 更新和死亡标记，并保留 `0.16s` 动作间隔，不再把一批伤害特效同帧叠放。最终 snapshot 已移除死亡单位时，播放器临时复用 `battle_unit` prefab 承载命中和死亡表现，播放后清理，不写回核心状态。
- `BattleFlow` 已接 hover 高亮和战斗内拖拽部署：hover / selected 使用 zip 原 `tile_hover_frame_ai_512.png`，按下我方单位后复用 `battle_unit` prefab 创建同尺寸跟手预览，释放到空格时发送核心 `MOVE_HERO`，由核心决定是否移动并记录 battle trace。
- `BattleFlow` 拖拽过程中会先通过核心 `SELECT_CELL` 选中拖动单位，再把核心 `selected_action_cells` / `action_preview` 按当前拖拽目标格做相对投影，使用现有 attack 红色格显示攻击范围；不导入 zip demo 的本地攻击 / 伤害规则。
- 真实鼠标连续拖拽后，`BattleFlow` 会在拖拽开始隐藏旧宠物详情，移动拖拽结束后不再弹出旧格详情，并清理拖拽 hover / deploy 高亮；只有按下又在原格松开才作为点击打开详情。
- `BattleFlow` 已接宠物点击详情面板：点击有单位的格子会走核心只读 `GET_CELL_DETAIL`，并实例化共享 `pet_detail_panel.tscn -> SpriteInfoCard`。`SpriteInfoCard` 继承迁移自 `/Users/ywh/Downloads/per-west-travel-v-0.01/FloatingUI/Prefabs/SpriteInfoPanel.gd` 的完整组件，并沿用其 `SpriteInfoData` / `SpriteRankStats` 数据契约；当前项目只通过公开 `set_info()` 适配 Dictionary 数据和 ASCII 资源路径，不操纵组件子节点。组件自身保持原项目 1920x1080 下的 `348x531.048` 尺寸和 `1:1.526` 比例，并按用户要求固定在右上角 `right=24 / top=64`；共享外层按钮宿主保持不变。原组件原生承载名称、元素、品质、7x3 攻击形状、生命、AP、攻击、防御、护盾和再生。点击我方宠物原地松手不再误发 `MOVE_HERO`。
- `BattleFlow` 进入真实战斗 snapshot 后会主动调用 `BattleVfxPlayer.play_round_banner()` 播放当前回合横幅；首回合入口显示“第1回合 / 我方回合”，不再依赖 prefab smoke 的调试生成。
- `scripts/game/battle_ui_controller.gd` 从 `YsbzsState.snapshot().board.cells` 逐格直映 8x8 战斗状态，不再存在 8x7 可见层或第 8 行投影。
- `scenes/ui/battle_flow/battle_ui.tscn` 使用用户确认的新生成 8x8 背景，并在场景文件中直接摆放 64 个 `BattleCell` prefab 实例；每格位置在 Godot 编辑器中可见，不再只由控制器运行时临时生成。
- 每个 `BattleCell` 固定保留全尺寸透明 `CellImage` 和同尺寸 `PrefabAnchor`。`CellImage` 引用共享透明锚点纹理，`PrefabAnchor` 是单位、陷阱、元素标记、行动标记、hover 框等预制体的统一相对坐标入口。
- 2026-07-16 已修复 8x8 场景格子存在、但宠物图片不可见的回归：`BoardGrid.custom_maximum_size.y = 1` 把每个 `BattleUnit` 压成 `0.125` 像素高；移除该遗留高度夹断后，保留原棋盘位置、美术资源和显式图片映射，玩家与敌方宠物恢复显示。
- `scripts/game/battle_cell.gd` 已按原包 `BoardGrid.gd::_make_cell_style()` 对齐运行时格子样式：默认格、deploy 蓝色、attack 红色、圆角、边框和阴影均用 demo 运行时参数；`BattleFlow` 渲染后会把空格按原 demo 显示为 deploy 蓝色，核心 action preview 显示为 attack 红色。
- `BattleCell` 的 selected / hover 图片框继续复用 `tile_hover_frame_ai_512.png`，但现在通过 `HOVER_FRAME_SCALE = 0.82` 缩小并居中显示，保留 `HOVER_FRAME_OFFSET` 作为后续微调偏移入口。
- 三选一核心 `node_choice` 会混入 1 个正式 encounter 战斗候选；`artist_ui_middle_controller.gd` 通过三选战斗按钮进入 `phase=battle` 后显示 `BattleFlow`，隐藏三选 / 商店 / 背包面板，并转发战斗按钮命令。
- 为对齐原 zip 可见效果，战斗阶段默认隐藏临时代码层 `RunTools` 和 `BattleCommandTools`；保存 / 读档 / 导出工具仍保留在非战斗 UI，战斗 smoke 通过 `debug_emit_command()` 验证核心命令，不让额外按钮覆盖美术画面。
- `AutoArrangeButton` 发送 `AUTO_POSITION_HEROES`；当当前移动范围内没有立即可攻击位置时，核心会按攻击形状到敌人的剩余距离选择合法接近站位。`BeginTurnButton` 发送 `RUN_PLAYER_ALL_OUT`，只执行当前玩家回合的全部出击，不跨敌方回合、后续波次或直接进入结算；两个美术按钮进入战斗时保持 enabled，棋盘格点击发送 `SELECT_CELL`。

## 未接好 / 待确认

- 完整源 `SpriteInfoPanel` 当前没有以下独立美术承载层：技能名称 / 技能说明、移动力、即将受伤、当前状态、棋盘位置、品质效果说明、机制说明、单位元素层、脚下元素层、行动槽、当前预览。核心 / `GET_CELL_DETAIL` 已有其中多项数据，但程序按用户要求不新增节点、不叠字、不缩放或重排预制体；需美术补明确图层 / 槽位和状态规范后再接线。
- 敌方普通怪物已建立首波显式映射；后续波次 / 机制召唤怪仍需要继续补 `enemy_id / source_pet_id / source_monster_template_id / name -> image` 表。
- 适配层对未列入显式表的敌人仍用元素占位图做运行时降级，不把文件名 / 文本 / hash 猜测当正式贴图绑定。
- 原包 demo 的本地 STARTING_UNITS、拖拽 / 子弹 / 咬击动画没有作为游戏规则接入；项目当前可见棋盘与核心 board 已统一为 8x8。
- 原包 demo 一进场会按 demo 本地单位刷红色攻击锁定区；项目当前只显示核心 snapshot 已给出的 action preview，不用 demo STARTING_UNITS / 攻击规则伪造核心状态。
- 原包只提供两个主按钮；按用户授权新增独立 `battle_action_panel.tscn` 作为正式运行时操作层，承载行动槽、方向、AP、施放、我方全部出击、结束回合和敌方行动。所有按钮只发送既有核心命令，不接 zip demo 本地规则。
- 子弹飞行、伤害数字、回合横幅、死亡标记、行动顺序骰子、怪物咬击等已经有 prefab/API 底座并接入 `BattleVfxPlayer`，普通 trace 已顺序播放；后续剩余主要是把核心 trace 字段继续细化到更精确的攻击类型 / 治疗类型 / 同方向齐射与 barrage 分组。

## 有歧义的接入点

- `BoardGrid.gd` demo 使用 8 列 x 7 行，但项目核心战斗快照是 8x8；2026-07-15 用户已确认以项目 8x8 为统一口径，并使用新生成的 8x8 背景替代旧 demo 的 8x7 显示边界。
- zip demo 内置 `STARTING_UNITS`、本地 HP / 攻击 / 移动 / trap / boss barrage 规则；项目侧不能直接复用这些业务规则，只能把动效表现映射到核心 battle trace / snapshot。
- 25 张 `HeroImages/*.png` 和 80+ 张 `SpriteImages/*.png` 尚未全部建立明确 `unit_id / pet_id / enemy_id -> image` 表；当前只接了首波敌人显式映射，后续需要继续按数据 key 补表，不能按视觉相似度或 hash 自动猜。
- 英雄图语义有歧义：zip 同时有 `01_hero_monkey_king.png` 到 `25_hero_monkey_king_alt.png`，也有 `sun_wukong_ai_220x210.png` / `spider_spirit_ai_220x210.png`；当前只显式使用后两张作为双方 leader。
- `button_auto_deploy` 与核心 `AUTO_POSITION_HEROES` 已接；继续由项目核心决定伤害优先与无即时目标时的接近站位，不复用 demo `_find_best_auto_arrangement()` 的本地规则。
- `BeginTurnButton` 当前发送核心 `RUN_PLAYER_ALL_OUT`，只结算当前玩家回合；表现层消费正式 damage trace 顺序播放动画，不在 UI 层复刻 zip demo 的本地伤害、deploy 或 enemy AI 规则。
- `round_banner_blank.png` / `round_banner_transparent.png` 是视觉横幅，但 zip demo 用运行时 Label 写“第 N 回合 / 我方回合”。当前美术压缩包没有明确动态文字层规范，是否允许叠字需要确认。
- `DamagePreviewLabel`、伤害数字、HP 数字、死亡预览均是 zip 脚本运行时新增文字/节点；项目规则要求没有明确文字层时不擅自叠加可见文字，所以这些要么等美术确认动态文字层，要么只在已有 prefab 数据面内显示。
- `tile_hover_frame_ai*.png` 与 `selection-white-blue-shadow-64.png` 都能表达 hover / drag / selected，哪个用于 hover、哪个用于选中、哪个用于拖拽，需要统一状态表。
- `Element_Buff` 资源在 demo 中实际是 trap / 元素机关显示，命名像 buff；核心里要区分元素增益、陷阱、地块效果后再接。
- `Attack_Order/dice_marker_1..3.png` demo 用于攻击方向 / 顺序提示，但核心 trace 里是否有行动序号、攻击方向预览或骰子语义，需要确认字段。
- `Death_Marks` 有 player/enemy 两套，但核心死亡事件、预死亡预览、已死亡残留格表现分别怎么显示，需要拆清楚。
- 敌方近战咬击 `Monster_Bite` demo 绑定敌方攻击命中；核心里不同敌人是否都用咬击、远程敌人是否改用子弹/法术，需要按 enemy action 类型映射。
- 玩家攻击在 demo 是三个方向、距离 2/3，并会在空格放 trap；核心当前战斗规则如果不是这个模型，相关 attack preview、trap preview、子弹目标都不能直接照搬。
- boss / enemy hero barrage demo 规则是“敌方普通怪全死后，敌方英雄连发弹幕”；核心是否存在同名机制，需要用 battle trace 事件确认。
- `Sprite_AttackSword_PaperCut.png`、`Sprite_HealthHeart_PaperCut.png` 已导入但 zip demo 没有明确接入路径；是否作为伤害/治疗 UI 图标待确认。

## zip 已实现但当前未接的动效 / 交互

- hover 框：`tile_hover_frame_ai_512.png`，demo 里 `_create_hover_frame()` / `_update_hover_frame()` 跟随鼠标显示部署格 hover；当前 `battle_cell.set_highlight()` 已使用该导入图片渲染 hover / selected 视觉。
- 拖拽部署：demo 里 `_start_drag()`、`_update_dragged_unit_position()`、`_finish_drag()` 让玩家单位跟手移动；当前已接战斗内拖拽部署输入，拖动时隐藏源单位、显示同 prefab 跟手预览并投影核心攻击范围，释放后发核心 `MOVE_HERO`，不在 UI 层改业务状态。
- 可部署格高亮：demo 里 `_refresh_deploy_highlights()`、`_show_placeable_cells()`、`_set_cell_highlight()` 用蓝色半透明格提示可放位置；当前 `battle_cell.set_highlight("deploy")` 已可复用。
- 攻击范围预览：demo 里 `_show_attack_cells_for_position()` 用红色格显示攻击预览 / 锁定范围；当前 `battle_cell.set_highlight("attack")` 已可复用。
- 行动顺序骰子：`Prefabs/Attack_Order/dice_marker_1.png`、`dice_marker_2.png`、`dice_marker_3.png`；当前 `battle_cell.show_attack_order_marker()` 已可复用。
- 回合横幅：`round_banner_blank.png`；当前 `battle_round_banner.tscn` / `battle_vfx_player.play_round_banner()` 已可复用。
- 子弹飞行：四元素 bullet；当前 `battle_projectile.tscn` / `battle_vfx_player.play_projectile()` 已可复用，使用 0.32 秒抛物线弹道。
- 多发弹幕：demo 里 `HERO_BARRAGE_BULLETS_PER_ATTACKER = 4`、`HERO_BARRAGE_SHOT_INTERVAL = 0.055`、`HERO_BARRAGE_VOLLEY_DELAY = 0.12`；当前可通过 trace 中多条 `shoot_projectile` / `DAMAGE_APPLIED` 事件播放，尚未有独立 barrage 分组事件。
- 敌方移动滑行：demo 里 `_slide_unit_to()` 以 0.22 秒移动敌方单位；当前 `battle_unit.move_to_position()` 已可复用。
- 敌方攻击跳跃：demo 里 `_hop_unit_visual_to()`，入场 0.18 秒、回退 0.16 秒、高度 42；当前伤害 trace 已用 bite / projectile 表现攻击，跳跃尚未单独接。
- 怪物咬击：`Monster_Bite/frames/monster_teeth_bite_01..05.png` 和 `monster_teeth_bite_sheet_5x512.png`；当前 `battle_bite_vfx.tscn` 已按 `[0.083, 0.067, 0.033, 0.1, 0.067]` 播放，总约 0.35 秒。
- 受击抖动：demo 里 `_shake_unit_visual()` 在受伤时抖动单位；当前 `battle_unit.play_shake()` 已可复用。
- 伤害数字：demo 里 `_show_damage_number()` 动态创建伤害数字；当前 `battle_damage_number.tscn` / `battle_vfx_player.play_damage_number()` 已可复用。
- 伤害预览：demo 里 `DamagePreviewLabel`、`_refresh_damage_previews()` 预览本回合造成 / 承受伤害。
- 死亡预览和死亡标记：`Death_Marks/death_mark_player.png`、`death_mark_enemy.png`；当前 `battle_unit.set_dead_mark()` 已可复用。
- 元素机关 / trap 显示：`Element_Buff/simple-buff-ring-*.png`；当前 `battle_cell.show_effect_marker()` 已可复用。
- 自动站位评分：demo 里 `_find_best_auto_arrangement()`、`_score_auto_arrangement()`、`_search_auto_arrangements()` 有本地算法；项目继续只转发核心 `AUTO_POSITION_HEROES`，不接 demo 评分规则。
- 敌方 AI 移动 / 攻击：demo 里 `_run_enemy_action()`、`_find_enemy_attack_target()`、`_best_enemy_move_grid()`、`_move_enemy_toward_player()` 是完整本地演示逻辑；项目不接 demo AI，改由核心 `battle_trace` 驱动视觉 replay。

## 验证

- RED/GREEN: 新增 `scripts/test/smoke_battle_vfx_sequence.gd`；实现前因 `BattleVfxPlayer` 没有顺序播放信号失败，实现后输出 `SMOKE_BATTLE_VFX_SEQUENCE_OK ["seq_1","seq_2"]`，并断言第二个伤害事件不会在首个 `0.32s` 弹道完成前启动。
- RED/GREEN: 可见中间帧先发现 625px 元素弹体保留 `scale=(1,1)`、覆盖约 4x4 格；`battle_projectile.gd` 改为复用 zip `_shoot_bullet_to_position()` 的 `0.45` 缩放后，回归断言和真实 Godot 中间帧均通过。
- VISIBLE PASS: 真实 Godot 4.7 `battle_ui.tscn` 调试入口用鼠标点击 `BeginTurnButton`，正式 `RUN_PLAYER_ALL_OUT` 产生 core damage trace；`output/battle_begin_turn_artist_vfx.png` 在 trace 启动后 `0.16s` 捕获到火元素弹道飞向敌方目标，棋盘、单位和美术按钮完整可见。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/test/smoke_battle_ui.gd`
- PASS: `scripts/test/smoke_battle_ui.gd` / `smoke_battle_debug.gd` 断言 `BattleFlow` 加载 `battle_asset_manifest.json`、64 个场景内格子均为 `battle_cell` prefab，且每格保留 `CellImage` / `PrefabAnchor`。
- PASS: `scripts/test/smoke_battle_ui.gd` 断言 `BattleCell` 默认格样式匹配原 `BoardGrid.gd::_make_cell_style()` 运行时参数。
- PASS: `scripts/test/smoke_battle_ui.gd` 断言 `BattleCell` / `BattleUnit` 暴露复用 API，并通过 `BattleVfxPlayer` 实例化 projectile、damage number、round banner prefab。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/test/smoke_battle_debug.gd`
- PASS: `open -n /Users/ywh/Downloads/Godot.app --args --path /Users/ywh/Documents/godot --script scripts/test/smoke_battle_ui.gd --keep-open`，生成 `output/battle_ui_main.png`，Godot 窗口保持打开。
- SUPERSEDED: 旧 `output/battle_ui_main.png` 曾按原美术包显示 8 列 x 7 行；2026-07-15 已由用户确认的新 8x8 图和 64 个场景格子替代。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/test/smoke_playable_flow.gd`
- PASS: 当前 `BoardGrid` rect `465,84,1461,933` 与新 1920x1080 背景中的完整 8x8 网格对齐；64 个格子按行列顺序直接写入 `battle_ui.tscn`。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --quit --scene scenes/ui/battle_flow/battle_ui.tscn`
- PASS: `scripts/test/smoke_battle_ui.gd` 断言战斗内拖拽部署会发送 `MOVE_HERO` 并增长核心 battle trace；可见截图中我方单位已移动到新格。
- PASS: `scripts/test/smoke_battle_ui.gd` 断言 `enemy_r01_001 / 棉悠悠` 和 `enemy_r01_002 / 炽焰牛` 已命中显式敌方图片映射，不再进入 missing mapping report。
- PASS: `scripts/test/smoke_battle_ui.gd` 断言临时 `RunTools` / `BattleCommandTools` 不覆盖导入战斗 UI，且 `debug_emit_command()` 可发出 `END_PLAYER_TURN`。
- PASS: `scripts/test/smoke_playable_flow.gd` 断言真实三选战斗入口、战斗自动结算、结算继续、奖励 / 返回路线、保存 / 读档形成最小可玩闭环。
- PASS: `ZIP_RUNTIME_ASSET_PARITY expected=168 present=168 missing=0`。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/game/artist_ui_middle_controller.gd`
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/game/battle_ui_controller.gd`
- PASS: `open -n /Users/ywh/Downloads/Godot.app --args --path /Users/ywh/Documents/godot --script scripts/test/smoke_battle_ui.gd --keep-open`，刷新 `output/battle_ui_main.png`；截图确认战斗阶段不再显示顶部 `RunTools` 或 `BattleCommandTools` 覆盖层，Godot 窗口保持打开。
- PASS: `output/battle_ui_art_compare_runtime.png` / `output/battle_ui_art_diff_runtime.png` 已重新生成；截图对比中按钮区差异 `0.00%`，棋盘区 `changed_pct_gt12` 从本轮修前约 `91.52%` 降到 `34.16%`，空格顶行从约 `81.66%` 降到 `17.62%`。
- PASS: `output/battle_hover_frame_main.png` 专门验证 hover 框缩小后位于格子内，不再撑满整格。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/test/smoke_battle_ui.gd` 断言真实战斗入口请求首回合横幅、两个美术主按钮 enabled、拖拽创建同 prefab 预览并发送 `MOVE_HERO`，核心 `battleTrace` 增长。
- PASS: `open -n /Users/ywh/Downloads/Godot.app --args --path /Users/ywh/Documents/godot --script scripts/test/smoke_battle_ui.gd --keep-open`，刷新 `output/battle_ui_entry.png` 和 `output/battle_ui_main.png`，Godot 窗口保持打开。
- PASS: `output/battle_ui_entry.png` 可见“第1回合 / 我方回合”横幅，且自动布置 / 开始行动两个美术按钮仍在原位置可用。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/test/smoke_battle_ui.gd` 断言拖拽过程中 `attack_highlight_count > 0`，并在松手后继续发出 `MOVE_HERO`。
- PASS: `output/battle_ui_drag_preview.png` 可见源格保留选中框、宠物跟手预览移动到目标格、攻击范围红色格随目标格投影。
- PASS: `/tmp/godot_manual_drag_actual_01.png` 到 `/tmp/godot_manual_drag_actual_06.png` 记录真实鼠标拖拽复现；修复前问题为拖拽后旧详情面板和黄色目标框残留。
- PASS: `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/test/smoke_battle_ui.gd` 断言拖拽开始隐藏旧详情，拖拽移动后不重新打开旧详情。
- PASS: `output/battle_ui_main.png` 刷新后确认战斗主界面不残留宠物详情面板或拖拽目标高亮。
- PASS: `scripts/test/smoke_battle_ui.gd` 断言点击战斗宠物后 `BattlePetDetailPanel` 可见，且详情文本包含生命和元素层信息。
- PASS: `output/battle_ui_pet_detail.png` 可见右侧宠物详细信息面板。
- RED/GREEN: `scripts/test/smoke_battle_visible_unit_layout.gd` 修复前报 `BattleUnit enemy_boss has collapsed size (124.5, 0.125)`；修复后输出 `SMOKE_BATTLE_VISIBLE_UNIT_LAYOUT_OK units=5`，同时断言每个单位的 prefab、边框和宠物图片具有非零尺寸。
- PASS: `output/battle_ui_pets_restored_20260716.png` 来自真实 Godot 4.7 主窗口，并由真实鼠标点击 `读档2` 进入；画面显示 4 只我方上阵宠物（英雄另算）、2 只敌方宠物和双方英雄，符合 `MAX_ACTIVE_UNITS = 4` 及该存档的 active roster，最后一个成功实例保持打开。
- RED/GREEN: 上阵数量断言在旧单宠验收 fixture 上报 `expected 4, got 1`；改为四宠确定性 fixture 后输出 `SMOKE_BATTLE_VISIBLE_UNIT_LAYOUT_OK units=8`，防止以后把初始单宠画面误当作完整上阵验收。
