# Artist UI Connection Gaps

来源：`/Users/ywh/Downloads/三选-商店-背包界面_debug检查完整运行版_20260709-153257.zip`

## 本轮原则

- 不改美术界面来适配代码。
- 原始 `UI.tscn`、槽位数量、节点位置、布局比例、按钮位置和图片内容保持 zip 交付口径。
- 本轮只做路径 ASCII 化、Godot import、脚本绑定和运行时数据适配；主界面不在美术槽位上叠加可见文字。用户已明确授权新增独立宠物详情层承载动态信息。
- 宠物 / 商品必须使用明确图片映射；本轮按用户指令先采用顺序映射：`pal_001 -> pet_sheet_001`，`pal_002 -> pet_sheet_002`，依此类推到 `pal_100 -> pet_sheet_100`。

## 已接入

- 主入口 `scenes/game/ysbzs_singleplayer.tscn` 已切到 `scenes/ui/artist_flow/ui.tscn`。
- Godot 项目 feature 标记已更新为 4.7；本轮导入和 smoke 使用 `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot`，版本为 `4.7.stable.official.5b4e0cb0f`。
- 原始 `AnimationPlayer` 的 `show_Three_Option`、`hide_Three_Option`、`show_Shop`、`hide_Shop`、`show_Bag`、`hide_bag` 已接回；代码只调用原动画名，不改动画轨道、时长、位置 key 或场景布局。
- 项目窗口设置已对齐美术原项目：`1920x1080`、`window/stretch/mode="canvas_items"`、`window/stretch/aspect="expand"`。此前我们用 `1080x1920` 竖屏 viewport 运行 1920x1080 美术场景，导致左右内容被裁掉，只有全屏或宽屏时才看得全。
- 原始三选槽保持 3 个，接 `CHOOSE_ROUTE` / `PICK_REWARD`；路线阶段现在由核心 `route_options` 直接提供 `kind=battle` 的正式战斗候选，不再靠 UI 兜底开战。
- 新增独立 `pet_detail_panel.tscn`：队伍 / 背包宠物与奖励宠物保留原位详情 / 确认语义；商店宠物改为参照大巴扎录屏的右侧非模态信息卡，鼠标进入商品即显示，离开、按下开始拖拽、购买成功或离开商店即隐藏。有效拖拽到落点仍走原 `DROP_ITEM_ON_TARGET`。
- 单宠物详情现从核心 `battle.shape_catalog` 读取 `shape_id / offsets / note`，用固定 3 行 x 4 列格表示攻击形状；蓝色“我”表示宠物自身，红色“■”表示作用格，超过相邻距离时显示数字（例如 `■2`）。这是表现投影，不参与战斗结算。
- 新增独立 `bazaar_info_panel.tscn`：路线显示三项节点说明；商店显示当前摊位名称/标签倾向、商品名/公开品质/价格、核心真实的免费刷新次数或下次刷新成本，并提供 `ROLL_SHOP`；奖励显示候选宠物摘要；战斗结算显示胜负、评级、金币变化、回合和继续命令。信息层不改三选、商店、队伍或背包的原槽位。
- 背包保持原始五槽，但信息层会显示候补总数和页码；候补超过五只时“下一页”仅切换可见五槽，不改核心 roster、上阵/下阵或出售命令。商店存在可用事件时，信息层显示第一个正式事件并派发 `APPLY_SHOP_EVENT`。
- 原始商店槽保持 5 个，读取当前 `shop_offers` 的前 5 个作为商品图和拖拽来源；购买只在拖拽释放到有效落点后通过 `DROP_ITEM_ON_TARGET` 触发。
- 原始队伍槽保持 4 个，读取 `roster.active`。
- 原始背包槽保持 5 个，读取非 active roster 的前 5 个。
- 商品、队伍槽、背包槽按玩家常规拖拽：按下有效物品槽立即出现跟手图，释放到有效落点后才向核心派发命令；单击释放到原位 / 空白处不买卖。
- 拖拽实现方式按玩家常规拖拽修正：shop 拖拽和 storage 拖拽分开记录，但按下有效物品槽后立即进入 `_start_shop_item_drag()` / `_start_storage_item_drag()`，运行时临时创建 `DragPreview` `TextureRect`，使用被拖物品当前图片，随鼠标移动，释放 / 取消后销毁。
- 拖拽开始后源槽图片会临时清空，避免“手上拿着一张、原位置还留一张”；无效落点取消时恢复，成功落点由核心返回后的 UI 刷新决定最终显示。
- 商店商品拖到队伍 / 背包有效落点时派发 `DROP_ITEM_ON_TARGET`，UI 只传来源、商品 id、落点类型和落点索引；核心负责购买和放入队伍 / 背包。拖到空白处不买。
- 购买成功后该商店商品槽按空槽渲染：清掉图片、命令和拖拽记录，不能继续显示或二次拖拽。
- 队伍宠物拖到背包有效落点、背包宠物拖到队伍有效落点时派发 `DROP_ITEM_ON_TARGET`；核心负责上阵 / 下阵和目标队伍槽位。
- 队伍 / 背包宠物按下后立即显示原 `Top_Sell` 节点和原脚本“出售”占位，释放到该区域时派发 `DROP_ITEM_ON_TARGET`；核心负责出售和金币返还。
- 原始背包按钮保持原位置，代码已接显示 / 隐藏背包面板；外层 `Bags` 图也作为同一个点击热区处理，点开背包不会派发 `EXIT_SHOP` 或改变核心 `phase`，关闭后回到打开前的 UI。
- 原始商店返回按钮保持原位置，代码已接 `EXIT_SHOP`；同时把原始 `Top_Shop` 外层图作为返回热区处理，真实点击整块顶部商店区域也会离开商店。
- 原始三选路线按钮按核心 `kind` 显示：商店节点优先用商人图，奖励节点优先用奖励节点图，战斗候选使用 zip 自带 `three_fight_logo.png`。
- 用户提供的宠物整图 `/Users/ywh/20260709-174628.png` 已导入到 `assets/artist_ui/pet_sheet/pet_sheet.png`。
- 宠物整图已按 10x10 切成 100 张单图：`assets/artist_ui/pet_sheet/slices/pet_sheet_001.png` 到 `pet_sheet_100.png`。
- 切图 manifest：`assets/artist_ui/pet_sheet/pet_sheet_manifest.json`。
- 顺序映射表：`assets/artist_ui/pet_sheet/pet_id_map.json`。
- 编号对照图：`output/pet_sheet_indexed.png`。
- 用户提供的 25 个商店人物整图 `/Users/ywh/Downloads/ChatGPT Image 2026年7月10日 03_35_19.png` 已导入到 `assets/artist_ui/shop_characters/shop_characters.png`。
- 商店人物图已按 5x5 切成 25 张单图：`assets/artist_ui/shop_characters/slices/shop_character_001.png` 到 `shop_character_025.png`。
- 商店人物 manifest：`assets/artist_ui/shop_characters/shop_character_manifest.json`。
- 商店人物顺序映射表：`assets/artist_ui/shop_characters/shop_character_map.json`。
- 商店人物编号对照图：`output/shop_characters_indexed.png`。
- 商店人物已按核心 `route.node_pool` 的正式商店节点顺序接到 `nodeId`：`node_shop_basic -> shop_character_001`、`node_shop_fire -> shop_character_002`，依此类推到前 25 个正式商店节点。
- 用户提供的 25 个奖励节点整图已导入到 `assets/artist_ui/reward_nodes/reward_nodes.png`。
- 奖励节点图已按 5x5 切成 25 张单图：`assets/artist_ui/reward_nodes/slices/reward_node_001.png` 到 `reward_node_025.png`。
- 奖励节点 manifest：`assets/artist_ui/reward_nodes/reward_node_manifest.json`。
- 奖励节点映射表：`assets/artist_ui/reward_nodes/reward_node_map.json`。
- 奖励节点编号对照图：`output/reward_nodes_indexed.png`。
- 奖励节点已按核心 `route.node_pool` 的正式奖励节点顺序接到 `nodeId`：`node_reward_pet -> reward_node_001`、`node_d02_reward_pet -> reward_node_002`，依此类推到 10 个正式奖励节点；剩余 15 张图保留为未使用资源。

## 压缩包界面和 Godot 项目的差别

压缩包是美术专用的只读视觉交付物，负责定义界面长什么样；Godot 项目是运行时适配层，负责把这个界面接到当前单机状态和玩家操作上。程序不回写压缩包，不通过改美术界面解决代码问题。

| 项目 | 美术压缩包 | Godot 项目适配 |
|---|---|---|
| 文件定位 | 外部交付源，只读保存 | 本仓库运行时副本和适配代码 |
| 场景来源 | 原始 `UI.tscn` 和 prefab | `scenes/ui/artist_flow/ui.tscn`、`prefabs/*` |
| 路径规则 | 可保留美术工具导出的原始路径 / 命名 | 转成 `res://assets/artist_ui/**` 和 ASCII 工程路径 |
| 视觉布局 | 决定布局、比例、槽位数量、按钮位置、装饰层级 | 不改布局，只实例化和引用 |
| 图片内容 | 美术给定的背景、框体、图标、槽位底图 | 只导入和映射；宠物图通过 `pet_id_map.json` 选择 |
| 动态文字 | 压缩包不提供通用商品 / 宠物文字层，但原脚本有 `Top_Sell` / “出售”占位 | 主界面不新增 RuntimeLabel、价格、名称、缺图文字或 tooltip；按用户授权新增独立详情层显示宠物决策信息 |
| 动态宠物图 | 压缩包提供已有按钮 / 图片承载节点 | Godot 只替换美术已有 `TextureButton.texture_normal`，不新增可见节点 |
| 交互 | 压缩包里的 demo/按钮和拖拽预览是视觉 / 交互基础 | Godot 绑定 `CHOOSE_ROUTE`、`DROP_ITEM_ON_TARGET`、`EXIT_SHOP`、背包开关，并复用原 `DragPreview` 跟手反馈 |
| 数据来源 | 不承载 `YsbzsState` | `artist_ui_middle_controller.gd` 读取 `YsbzsState.snapshot()` |
| 缺口处理 | 不通过改美术稿补洞 | 写入本报告和任务卡，代码降级或等待确认 |

当前允许的 Godot 差异只有这些：路径 ASCII 化、资源导入 `.import`、`res://` 引用修正、挂脚本、信号连接、状态读取、图片映射表、复用美术已有 `TextureButton` 换图、复用原 `Top_Sell` 出售占位、复用原 `DragPreview` 跟手反馈、临时代码层 `RunTools` 存档 / 读档 / 导出工具条、按用户授权新增独立 `pet_detail_panel.tscn`、截图 / smoke 验证产物。主界面仍不新增 `RuntimeLabel` / `RuntimeIcon` 等可见节点，也不叠加商品名、价格或缺图提示。

本轮已经从同一个压缩包重新清空导入一次，并用 Godot 4.7 重新跑过 editor import、headless smoke 和真实窗口截图 smoke。smoke 现在会在缺图、三选按钮没图、商店按钮没图或出现运行时叠加节点时直接失败；等待逻辑按原动画 0.5 秒切换节奏检查。

当前禁止的做法：改压缩包原文件、为了多一个商品槽改商店布局、移动按钮位置、重排背包 / 队伍槽、裁切或重绘框体、用错误图片冒充映射、把代码需要的功能直接画进美术界面。

## 没有接好的统计

| 类别 | 数量 | 明细 |
|---|---:|---|
| 原始界面槽位小于当前数据 | 0 | 用户确认普通商店最多 5 件；核心已统一限制为 5，完整适配美术原始五槽。背包候补继续通过五槽分页处理。 |
| 当前可见宠物 / 商品图片映射缺失 | 0 | 已按用户指令接入顺序映射；当前商店 5 个商品和队伍 1 个宠物均显示图片。 |
| 原始界面动画未接 | 0 | 已接回原 `AnimationPlayer` 切换流程；没有改动画资源本身。 |
| 原包拖拽图片跟手未接 | 0 | 已恢复原脚本 `TextureRect` 拖拽预览；smoke 验证创建、跟随鼠标位置和释放清理。 |
| 商店人物图片数量不足 | 4 | 核心当前有 29 个正式商店节点，图片只有 25 张；`node_d09_fire_shop`、`node_d10_tier3_shop`、`node_d10_output_shop`、`node_d10_fire_shop` 暂无对应商人图。 |
| 奖励节点图片数量不足 | 0 | 核心当前有 10 个正式奖励节点，图片有 25 张；已接 10 个，剩余 15 张暂未使用。 |
| zip demo 拖拽未接真实命令 | 0 | 拖拽购买、队伍/背包拖拽切换、拖到出售区均已派发 `DROP_ITEM_ON_TARGET`；核心返回后刷新 UI。 |
| 原包阈值拖拽已纠正 | 0 | 原包也不该等待阈值；当前启动时机按玩家常规拖拽修正为 button_down 立即开始，不再保留 12px 阈值。业务结果仍由核心 `DROP_ITEM_ON_TARGET` 决定。 |
| 拖拽语义仍需核心/美术确认 | 1 | 同一列表内拖拽重排 / 交换（队伍槽之间、背包槽之间）当前未承载；购买到队伍 / 背包、队伍 / 背包互转和出售已接核心落点命令。 |
| 正式贴图映射需复核 | 1 | 当前是顺序映射，不是美术逐只确认后的最终语义映射；如果后续发现 `pal_xxx` 和图不一致，应改 `pet_id_map.json`。 |
| 商店高级功能未接 | 2 | 用户明确要求不做锁定 / 解锁 offer；商店事件按钮仍未出现在原始美术界面里。 |
| 队伍 / 背包管理未完整接 | 0 | 上阵 / 下阵和出售已通过原始槽位拖拽、背包面板和 `Top_Sell` 占位承载，不新增按钮。 |
| 宠物决策信息承载 | 0 | 已由独立详情层承载名称、属性和核心技能中文说明，不挤占原始卡面槽位。 |
| 存档 / 回放工具未接入原始界面 | 0 | 已先用临时代码层 `RunTools` 普通工具条接入保存、读档、导出回放、导出战报；主界面和战斗覆盖层都可访问。后续美术给正式按钮后替换这条临时工具条。 |
| 战斗正式界面未覆盖 | 1 | zip 是三选 / 商店 / 背包界面，不是完整战斗 HUD；战斗只用三选槽做命令兜底。 |
| 真实鼠标可见验收发现的按钮缺口 | 0 | 商店返回已像背包一样接外层可见热区；`smoke_artist_ui.gd` 覆盖 `Top_Shop.gui_input -> EXIT_SHOP -> route`。 |

## 真实鼠标录屏验收

- 录屏：`output/artist_ui_mouse_visible_demo.mp4`
- contact sheet：`output/artist_ui_mouse_visible_demo_contact.png`
- 录制方式：真实 Godot 全屏窗口，系统鼠标事件移动 / 点击，30fps，正常人眼可见速度。
- 已在录屏中看见：路线三选页、进入商店、5 个商店商品图片、点击购买后队伍槽位新增宠物图。
- 历史录屏中未通过的商店返回、背包开关均已用 smoke 覆盖修复：点外层背包图可开 / 关背包且不会退出商店核心 phase；点外层 `Top_Shop` 可见区域会派发 `EXIT_SHOP` 并返回 route。

## 可玩闭环验收

- PASS: `scripts/test/smoke_playable_flow.gd` 覆盖真实三选战斗按钮进入战斗、临时战斗操作条自动战斗、战斗结算继续、奖励领取 / 返回路线，以及 RunTools 保存 / 读档回路。
- PASS: `scripts/test/smoke_artist_ui.gd` 覆盖商店返回外层热区；返回只走核心 `EXIT_SHOP`，不改美术布局。

## 当前可见图片清单

| 界面位置 | id | pet_id | 名称 | 当前图片 |
|---|---|---|---|---|
| 路线奖励节点 | `node_reward_pet` | - | 宠物奖励 | `reward_node_001.png` |
| 路线商店节点 | `node_shop_basic` | - | 夜市商人 | `shop_character_001.png` |
| 路线商店节点 | `node_shop_fire` | - | 火系补货商人 | `shop_character_002.png` |
| 队伍槽 | `pal_002` | `pal_002` | 捣蛋猫 | `pet_sheet_002.png` |
| 商店槽 | `shop_001` | `pal_008` | 新叶猿 | `pet_sheet_008.png` |
| 商店槽 | `shop_002` | `pal_014` | 玉藻狐 | `pet_sheet_014.png` |
| 商店槽 | `shop_003` | `pal_034` | 棉花糖 | `pet_sheet_034.png` |
| 商店槽 | `shop_004` | `pal_035` | 灌木羊 | `pet_sheet_035.png` |
| 商店槽 | `shop_005` | `pal_009` | 燎火鹿 | `pet_sheet_009.png` |

## 需要美术或策划确认

- 商店商品槽已确认固定为 5 个，不需要美术补第 6 个槽。
- 背包是否只展示 5 个候补，还是需要分页 / 滚动 / 展开态。
- 锁定 / 解锁商品是否需要美术补明确交互；当前不新增按钮。
- 当前顺序映射是否就是最终语义映射；若不是，直接改 `assets/artist_ui/pet_sheet/pet_id_map.json`。
