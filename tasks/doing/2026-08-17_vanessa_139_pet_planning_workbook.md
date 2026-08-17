# 凡妮莎 139 物品 × 139 宠物一对一策划表

- status: complete
- goal: 以项目138条正式Vanessa映射谱系为基线，并将Pontoon Skimmer作为1个Pygmalien跨英雄灵感候选单列，完成138+1只不同宠物的一对一策划讨论；保留来源机制、转译建议、分歧/撤回、风险与完整性校验，并同步形成通用代码模块和配套策划系统路线图。
- stop_conditions:
  - 不修改正式 workbook、CSV、生成 JSON 或运行时代码；
  - 不占用已映射给其他 Bazaar 对象的宠物而不标记冲突；
  - 当前表格运行时不可用时停止，不使用未授权的替代表格库绕过。
- write_scopes:
  - `tasks/doing/2026-08-17_vanessa_139_pet_planning_workbook.md`
  - `reports/design/vanessa_139_pet_planning_discussion_log.md`
  - `outputs/01a00c55-8bb0-7350-9d02-a01e97a6e5a3/vanessa_139_pet_planning.xlsx`
- exclusive_files:
  - `tasks/doing/2026-08-17_vanessa_139_pet_planning_workbook.md`
  - `reports/design/vanessa_139_pet_planning_discussion_log.md`
  - `outputs/01a00c55-8bb0-7350-9d02-a01e97a6e5a3/vanessa_139_pet_planning.xlsx`
- existing_wip:
  - 工作树存在其他 AI/用户的战斗美术、商店美术、测试以及 `tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md` 改动；本任务不触碰。
  - 当前正式快照含 138 个凡妮莎物品对象；当前外部清单含 139 件物品。
- sources:
  - 初始输入清单：`https://bazaarwinner.com/hero/vanessa`（推断聚合139件，已确认混有旧名/跨英雄对象，不能作当前原生真相源）
  - 当前逐卡来源：BazaarDB 17.2直达页、public/Deep内容签名、card ID alias与抓取时间；Pontoon当前页 `https://bazaardb.gg/card/jv7wlq4chk28sy4lwhntcj8zvt/Pontoon-Skimmer`
  - 当前运行时映射参考：`data/content/generated/006_economy.json`（含369个shop pet占位，不能按`bz_van_*`备注前缀统计item来源数）
  - 正式来源目录（只读）：`/Users/ywh/Documents/ysbzs/data/csv/34_bazaar_objects.csv`
  - 正式策划真相源（只读）：`/Users/ywh/Documents/ysbzs/xlsx/ysbzs_master.xlsx`
- validation:
  - 项目正式映射逐项审阅 = 138/138；跨英雄draft = 1；正式ID重排 = 0；
  - 正式来源目录复核：369条=`item 138 + skill 138 + merchant_package 93`；138个item的object ID、pet ID均唯一，object_no连续1..138；
  - 当前名、历史alias、英雄/patch、public/Deep冲突、撤回与本地偏离分栏记录；Pontoon显式 `SOURCE_SCOPE_CONFLICT_STOP`；
  - 分类复算为25/46/28/13/17/9=138，另计Pontoon器械draft后总数139；
  - Markdown讨论表已做空白/格式检查；因artifact-tool不可用，正式xlsx的公式与渲染检查未执行。

## 当前核对结果

- 现有项目：138 个凡妮莎 `item` 来源对象，分别映射 `pal_001` 至 `pal_138`。
- `REJECTED`：第 1～5 轮采用的“当前 139 件凡妮莎原生物品”判断。该清单来自 BazaarWinner 的推断聚合，混入 3 个旧名与 1 个跨英雄物品。
- 当前 17.2 较强证据：凡妮莎原生仍为 138 件；项目旧清单的 `Bonfire`、`Bilge Worm`、`Suppressor` 是现行名，BazaarWinner 的 `Flame Signal`、`Hate Leech`、`Silencer` 是过期阶段。
- `Pontoon Skimmer` 当前为 Pygmalien 原生物品。若产品仍要求 139 个方案，只能标成“138 原生 + 1 跨英雄灵感候选”，不能伪装为凡妮莎原生。
- 潜在冲突：`pal_139` 当前对应 `Alacrity` 技能对象；跨英雄候选也不得占用它。若批准额外宠物，仍优先使用新 ID 候选 `pal_370`。

## 阻断

- 本轮已按表格技能尝试载入 `@oai/artifact-tool`，运行环境返回 `Module not found: @oai/artifact-tool`；依赖加载工具也未提供。
- 按技能契约，不安装依赖、不猜测路径、不改用其他本地 Excel 库。工作簿尚未创建。
- `tasks/ai/QUEUE.md` 与 `tasks/ai/STATUS.md` 已有他人改动，因此未更新，避免覆盖现有 WIP。

## 2026-08-17 策划小队讨论协议

- 战斗转译组：从正式回合、格子、形状、行动点与触发链出发，判断《大巴扎》机制哪些保留体验、哪些必须改写。
- 宠物身份组：审核 139 件物品与 139 只不同宠物的主题、定位和辨识度，检查旧映射是否只是序号绑定。
- 数值与成长组：只建立品质、体型、冷却、弹药、相邻关系到本项目预算维度的换算框架，不写正式数值。
- 第一轮独立提案；第二轮交叉审阅并记录反对意见；主策汇总后才进入工作簿。
- 讨论阶段不修改正式 workbook、CSV、生成 JSON 或运行时代码。
- 用户允许持续推进，不要求实时查看对话；每轮必须把事实、提案、反对、纠错和未决项追加到本地讨论日志，不能只在聊天中汇报。
- 代码模块轨只做责任层、接口、依赖、优先级与验收设计；在机制裁决和独立任务授权前不直接实现。

## 第一、二轮讨论记录

- 旧 `bz_van_001..138 -> pal_001..138` 不是纯随机：来源品质 138/138 直接写成本地品质，主附魔也粗略决定职责；但宠物名、形状和具体技能与来源物品普遍没有稳定语义关系，不能视为机制定稿。
- 来源品质与本地成长品质必须拆列。来源品质只作为当前来源事实与弱先验；本地阶段另设 0/2/5/9 进化点质变字段。旧本地品质保留为历史映射值，不直接覆盖或删除。
- `Small/Medium/Large` 只作为来源尺寸与预算参考，不能直接换成多格单位、宠物位数或技能槽数。
- 秒级 Cooldown 默认转译候选为 `cooldown_ticks`；不能默认换成 AP。当前共享技能条执行不逐技能扣 AP，技能阶段结束才清空 AP。
- Haste/Slow 不能默认映射到 speed：共享技能条按玩家重排后的稳定顺序执行，不按 speed 重排。
- Multicast 保留为同一次发动重复核心效果，不得偷换成扩大形状或插入其他宠物技能序位。纯伤害可候选 `strike_count`，纯铺层可候选 `application_count`；复合效果标记 `NEEDS_EFFECT_PACKET_REPEAT`。
- “相邻物品”必须翻译成玩家可读的相邻宠物、左/右/前/后格或明确的技能结算前后关系。
- `RETRACTED_SOURCE_FACT`：早期“Pontoon只能确认Large/Gold/D5推断、当前机制为空”的判断已被17.2直达页推翻；当前为Pygmalien、Silver、Large、Vehicle/Aquatic，Flying/Shield/Charge循环可核。保留该句作为纠错过程，不得再输出为当前事实。

## 策划小队首轮共识

- 设计目标不是逐字复制原效果，而是保留每件物品的体验循环、触发关系、风险收益、空间关系、资源消耗和反制点，再用本项目战斗语言重写。
- 139 行先统一裁决六个公共语义：Haste/Slow、Ammo、Multicast、Adjacent、Destroy、局外经济成长；公共语义未定前不逐宠填正式数值。
- 每宠最多承载 A 技能、B 技能、一个被动循环、一个明确形状和最多一个新增底层原语，避免 139 个不可维护特例。
- 当前 138 映射只保留为来源对象与宠物身份候选。来源事实、宠物身份、本地战斗语义、技术可行性和讨论裁决必须分区。
- `Pontoon Skimmer` 使用草案键 `draft_van_pontoon_skimmer`；若正式接受新增对象，首选新增 `pal_370`，禁止挪用已绑定 Alacrity 的 `pal_139`。
- 身份组初分六类：海兽伙伴 24、舰炮兵器 55、器械载具 24、船体据点 20、奇物谋略 6、自然异象 10，共 139。
- 数值审核不使用单一总分；至少同时比较单回合峰值、五回合累计、十二回合上限、稳定性、经济贡献和连锁风险。

## 下一轮讨论顺序

1. 先形成六个公共机制词典及其本地权威责任层。
2. 再按六个身份主类分批审阅 139 行，每批保留反对意见和未决问题。
3. 先做身份与机制草案，不填正式数值。
4. 公共机制和代表宠物通过固定种子模拟后，才进入全量数值阶段。

## 持续讨论进度

- 已完成第 6 轮来源修复与基线纠错：当前有效口径为 138 个 Vanessa 原生来源，加 1 个 Pontoon Skimmer 跨英雄候选席位。
- 已形成 P0/P1/P2 通用代码模块路线图，以及品质、成长、获取、经济、图鉴、美术、文本、存档、AI、表现和 QA 配套策划路线图。
- 已完成海兽伙伴批次 A、B、C 共 24/24 项的三组独立提案、来源纠错、交叉复审、物种防撞与风险分层。
- 已冻结的阶段规则：允许合法一技能宠；技能提交/效果包/操作/具体应用四级事务；相邻使用显式关系域；多身体仍为单单位；底稿复用不得交换正式 ID 或继承旧机制。
- 下一批进入船体据点与奇物谋略；继续保持无正式数值、先事件骨架与身份裁决。
- 已完成船体据点批次 A 8 项的独立提案与交叉复审；新增 passive-only、批量非死亡退场和原子支援包合同，并将 Disguise/Holsters 调整到更合适的主类。
- 已完成第 11 轮船体据点批次 B 8 项的三组独立提案、两轮对质与主审裁决；累计完成 40/138 个原生对象的逐项身份/事件骨架审阅（海兽 24 + 本轮前后两批 16）。
- 第 11 轮新增的代码裁决：优先扩展现有 skill/status/modifier/death/run-event 权威层，只独立新增冷却唯一写者、跨单位反应队列、控制饱和策略和战斗阵容标签快照等可复用窄模块。
- Life Preserver 已确认应保护正式 `player_hero`，但当前 leader shield 每次投影为 0，缺少权威状态，故正式接入阻断；Port、Saloon、Iceberg 继续保持深红门禁。
- 已完成第 12 轮剩余船体4项与奇物6项的三组独立提案、来源纠错、身份防撞、交叉复审与主审裁决；累计完成 50/138 个原生对象的逐项身份/事件骨架审阅。
- 第 12 轮已纠正对象键：`Coral=pal_028`、`Figurehead=pal_045`、`Lockbox=pal_073`、`Tripwire=pal_128`；不得与 `Coral Armor=pal_029` 混淆，也不进行 ID 交换。
- 第 12 轮已锁定：Tropical Island 的 Coconut+Citrus 是战后外部奖励包；Turtle Shell 只增强既有 Shield operation、不注入新操作；Ambergris/Lockbox 的战力计量与真实售价必须分名但保持同源；Coral 使用购买前监听者快照；Beach Ball 自我催动因冷却提交顺序继续阻断。
- 空间关系采用真实棋盘口径：Swash Buckle、Water Wheel 使用同排左右一格的回合快照，Figurehead 使用同排全左/全右；必须通过自动站位模拟验证这些关系在实际四宠布局中有足够出现率，否则再回到固定编队序位方案复审。
- 新增代码路线：统一 `LeaderCombatantState/CombatantStateAccessor`、原子 `RewardGrantBundle`、`DerivedStatProjection`、`InventoryInstanceValue`、同排方向 `RelationSnapshot`、`ContentDependencyValidator`；优先扩展现有 hook/status/modifier/cooldown/support/passive/run transaction 层，不给单只宠物建立平行服务。
- 船体据点与奇物谋略两类已完成闭环。主类计数现为海兽24 / 舰炮55 / 器械载具25 / 船体据点13 / 奇物谋略10 / 自然异象11，共138；Pontoon 跨英雄候选另计为器械第26项、草案总数139。
- 下一轮进入器械载具：先审 `Astrolabe`、`Captain's Wheel`、`Custom Scope`、`Diving Helmet`、`Dock Lines`、`Fishing Net`、`Fishing Rod`、`Honing Steel`，继续同时讨论身份、机制转译、通用模块、经济/UI/AI/QA配套，不填正式数值。
- 已完成第 13 轮器械载具批次 A 8 项的独立提案、两次来源纠错、交叉复审与主审裁决；累计逐项审阅 58/138。
- 本轮确认当前 17.2 Honing Steel 仍是左右最外 Weapon，Deep 为两个独立 operation；单 Weapon 同为左右极值时保留两次 application，不在事务层去重，并把双命中纳入峰值/12回合预算门禁。
- 第 13 轮空间继续以可见棋盘为权威：Captain's Wheel/Diving Helmet 为同排左右一格，Custom Scope/Fishing Rod 为同排正右一格，Honing Steel 使用施放 prepare 时的全棋盘左右 Weapon 极值；拒绝共享技能条邻位。
- 本轮新增/细化 `SupportSkillExecutionPolicy`、`SkillCooldownService`、`BattleEventEnvelope`、`CombatTagProjection`、`CriticalOutcomeAggregator`、`TaggedSkillTargetResolver`、`SkillParameterModifierLedger` 与跨英雄 `GrantRewardFromPool` 路线；仍优先扩展现有权威层。
- 本轮最终三档：Dock Lines 可进入无数值骨架；Astrolabe/Captain's Wheel/Custom Scope/Fishing Net/Fishing Rod/Honing Steel 带硬门禁；Diving Helmet 因 leader Shield 与派生标签权威层暂停。
- 下一批器械载具改为 `Integrated HUD`、`Lighter`、`Oni Mask`、`Powder Horn`、`Ramrod`、`Rowboat`、`Sextant`、`Shipwreck`；仍只讨论身份、机制和公共模块。
- 已完成第 14 轮器械载具批次 B 8 项的三组独立提案、来源 ID 对质、身份迁类复审与主审裁决；累计逐项审阅 66/138。
- 本轮来源页存在同名多 card ID、地区镜像与抓取缓存分歧；正式证据口径改为 `canonical_slug + patch页头 + 抓取时间 + public/Deep内容签名 + alias状态`，不再把单一 card ID 当永久版本权威。内容相同可继续设计，public/Deep 实质冲突则 `SOURCE_CONFLICT_STOP`。
- 本轮锁定真实棋盘关系：Integrated HUD/Powder Horn 为同排正右一格，Ramrod/Rowboat 为同排左右一格；拒绝共享技能条邻接。Ramrod 按每个 `delta_ammo>0` 的 Reload application 成长，Sextant 允许同 root 的 Crit→Haste→Crit成长两步链但各消费者每 root 一次。
- 本轮确认 Shipwreck 只有符合 Aquatic、有冷却且显式 `multicast_eligible` 的主动技能获得整包连发；没有 Destroy、残骸、召唤、死亡或经济机制。Oni Mask 迁奇物谋略、Shipwreck 迁自然异象仅改变身份/图鉴/美术分类，不自动改来源类型或战斗标签。
- 本轮新增/细化 `AmmoResourceService`、`ReloadOperation`、`BurnLedger/BurnResolver`、`MulticastExecutionPolicy`、application 级事件与 source alias 审计模型；Lighter 可作低依赖纵切，Powder Horn/Ramrod 在 Ammo/Reload 权威服务前暂停。
- 下一批收束器械载具剩余项：`Stealth Glider`、`Submersible`、`Suppressor`、`Spyglass`、`Star Chart`、`Weather Glass`、`Wetware`；Pontoon Skimmer 继续作为跨英雄第139草案单列，不挤占原生138。
- 已完成第 15 轮剩余器械载具 7 项的当前来源纠错、三组独立提案与交叉复审；累计逐项审阅 73/138，器械载具主类完成闭环。
- 本轮撤回两处旧机制：Stealth Glider 的玩家减伤已是固定光环，不再按其他 Flying 数量增长；Wetware 已改为 Shield 成功后随机强化 Weapon 伤害，不再是 Weapon 使用后自身 Shield 成长/另有 Tech 减冷却。
- Suppressor 的 `Silencer` 只保留历史改名 alias；商人索引中紧邻的“100伤、唯一Weapon倍增”属于 Sniper Rifle，本轮误归属已显式撤回，不加入 Suppressor。
- 本轮锁定：Flying 是幂等战斗关键词且只修饰每宠一个 `tempo_anchor_skill_id`；Submersible 的四个 Deep operation 不按目标去重；Star Chart 的 `max_by_stat` 是本地安全裁剪；Weather Glass 按四种唯一标签冻结 0..4 个额外整包 packet。
- 本轮新增/细化 `BattleKeywordStateService`、`CooldownModifierRegistry`、`RootApplicationAggregator`、技能级 `source_equivalent_operation_id` 与二维极值解析；Wetware 继续等待 LeaderCombatantState/Shield 权威状态。
- 下一类进入自然异象剩余对象；先从未审对象中重建该类清单，排除已经在前轮完成的 Iceberg、Shipwreck 与 Weather Glass，再分批讨论。
- 已完成第 16 轮自然异象批次 A 5 项的来源更新、身份迁类检查、强制使用/购买赠品/弹药上限/连发成长对质；累计逐项审阅 78/138。
- 本轮来源纠错：Cannonball 已从相邻 Ammo 上限改成全队；Card Table 的 non-Friend 自身冷却惩罚已删除；Chum 目标扩为 Aquatic OR Food；Clamera 不再开战自动用，而是监听敌方前若干次正常使用；Bonfire 为现行名、Flame Signal 仅历史 alias。
- 本轮冻结 `ForcedUsePolicy.BYPASS_READY_RESTART_ON_SUCCESS`：Clamera 反应忽略当前冷却/AP，在同一 causal root 下执行一次完整反应包，成功后将自身 A 冷却替换为完整冷却；只监听 scheduled active，双方反应包不得互相递归。
- Chum 的 Piranha 是 `BUY_OFFER` 原子购买附赠，不是战斗召唤；Card Table 的本战 Multicast 与 Cannonball 的 AmmoMax 都需全局上限、锚点与套利/包量门禁。
- 下一批自然异象 B：`Incendiary Rounds`、`Piano`、`Seaweed`、`Volcanic Vents`、`Wanted Poster`；完成后自然异象13项闭环。
- 已完成第 17 轮原自然异象批次 B 5 项的17.2直页/缓存对质、身份迁类、动态Friend、Heal成长、固定连发与PVP经验事务审阅；累计逐项审阅 83/138。
- 来源抓取分歧：搜索/地区缓存仍显示16.1/16.2，但战斗组与身份组在同日实时直达页读到17.2；保留双方证据与内容签名，不让缓存摘要覆盖直页，也不将单一card ID永久化。
- 本轮迁类：Incendiary Rounds → 舰炮兵器，Piano/Wanted Poster → 奇物谋略；Seaweed/Volcanic Vents 留自然异象。
- `RETRACTED`：第16轮“分类计数不变”及第17轮早期 `24/56/21/13/14/10`。三组独立复算确认最终原生138为海兽24 / 舰炮57 / 器械21 / 船体13 / 奇物15 / 自然8；Pontoon跨英雄草案加入器械后为139。
- 自然异象8项至此闭环。下一类进入舰炮兵器57项，先审近战/投射代表批次：`Anchor`、`Arbalest`、`Ballista`、`Bayonet`、`Bladed Hoverboard`、`Blowgun`、`Blunderbuss`、`Bolas`。
- 已完成第 18 轮舰炮兵器批次 A 8 项的来源版本停止线、三组独立提案、空间规则撤回、身份防撞、弹药/连发/强制使用与死亡安全点裁决；累计逐项审阅 91/138。
- `CORRECTED_SOURCE_REFRESH`：本轮初查因 `bazaardb.gg` 入口超时，只读到16.2/旧缓存并暂标 `17.2_change_unverified`；同日改用 `global.bazaardb.gg` 直达页后，Anchor、Arbalest、Ballista、Bayonet、Bladed Hoverboard、Blowgun、Bolas 均已重复核到页头17.2，撤回这7项的版本阻断。Blunderbuss 当前页仍待复核；旧判断保留在讨论日志中作为纠错过程，不用缓存数值覆盖正式成长表。
- `RETRACTED`：Bayonet 的共享技能条左邻，以及 Anchor/Hoverboard 的每root即时邻接。三项统一采用可见棋盘 `board_horizontal_round_snapshot`；移动、死亡、撤回、exit立即断边，本回合新移入者下回合接入。
- Blowgun 本地顺序锁定为 `Damage -> death safe point -> Poison if target alive`；Poison读取prepare时面板Damage，不读取暴击后、护盾后或实际掉血量，禁止给已败北目标挂状态。
- Bladed Hoverboard 正式从舰炮迁入器械身份类；原生138分类更新为海兽24 / 舰炮56 / 器械22 / 船体13 / 奇物15 / 自然8；Pontoon跨英雄草案另加器械后为139。
- 本轮新增/细化 `EffectPacketTransaction`、`ReactionScheduler`、`AmmoResourceService`、`BoardRelationService`、`MulticastPacketExecutor`、`CombatParameterLedger`、`PercentHealthDamagePolicy`、`PoisonResolver` 与 `ControlSaturationPolicy` 路线。
- 下一批舰炮兵器 B：`Butterfly Swords`、`Cannon`、`Cannonade`、`Cauterizing Blade`、`Concealed Dagger`、`Cutlass`、`Cyber-Sai`、`Dart Launcher`；仍先核来源版本与身份/事件骨架，不填正式数值。
- 已完成第 19 轮舰炮兵器批次 B 8 项的17.2来源刷新、三组独立提案、任务/经济/连发/死亡安全点交叉裁决；累计逐项审阅 99/138。
- `RETRACTED_SOURCE_VERSION`：三组早期“仅Cyber-Sai可核17.2”的结论由主审global直达页推翻；本批8项均已核到页头17.2与当前public/Deep签名。
- 本轮身份暂定：双锋凤蝶、炮角黑犀、三响雷袋鼠、灼爪食蚁兽、藏锋穿山甲、弯盔鹤鸵、脉叉三角龙、麻针海胆；Dart Launcher因当前仅Tech且无Weapon/Damage，从舰炮迁入器械。
- 本轮主裁决：Concealed Dagger按17.2 Deep优先级 `Haste -> Damage`，但下游Haste消费者须等父root完整结束；Cannon/Cauterizing遵循现有每Damage effect死亡安全点，目标败北后Burn写语义skip且不改投。
- Cauterizing Blade来源只证明public `OR`与Deep双Quest块同时存在，未证明选择协议；本地候选先用获取/部署前显式二选一，必须标 `local_safety_deviation`，不能冒充来源事实。
- 原生138分类更新为海兽24 / 舰炮55 / 器械23 / 船体13 / 奇物15 / 自然8；Pontoon跨英雄草案另加器械后为139。
- 本轮补入 `QuestProgressService`、`BattleStartRewardService`、`CritDamageModifierChannel`、`DerivedEffectParameterResolver`、`BoardSkillAnchorIndex`；均须并入正式Command/Result/Trace/Snapshot与幂等存档链。
- 下一批舰炮兵器 C：`Dive Weights`、`Double Barrel`、`Elemental Depth Charge`、`Flagship`、`Grapeshot`、`Grappling Hook`、`Grenade`、`Handaxe`。
- 已完成第 20 轮舰炮兵器批次 C 8 项的当前来源复核、三组独立提案、弹药取样/动态连发/标签存在/装填反应对质与主审裁决；累计逐项审阅 107/138。
- 本轮来源口径：Dive Weights、Double Barrel、Elemental Depth Charge、Flagship、Grappling Hook、Grenade、Handaxe 当前直达页均为17.2；Grapeshot card页仍为17.1 Hotfix，保留 `17.2_change_unverified`，不以站点总版本替代卡级版本。
- `RETRACTED`：Handaxe“强化全部物品”的身份组初读。17.2 public存在图标抽取缺损，Deep明确只给board Weapons增加DamageAmount；本地每宠只作用显式 `weapon_anchor_skill_id`。
- Elemental Depth Charge保留来源双目标域：Burn/Poison作用敌方Leader、Freeze作用敌宠tempo anchor；拒绝为省模块静默改投普通单位，在统一LeaderStatusService完成前保持深红阻断。
- Dive Weights锁定本地事务顺序：使用前冻结Ammo与packet数，`packet_count=1+ammo_before_spend`，随后root只扣一次Ammo；Reload与执行中状态不得改写本次packet数。
- Flagship按Property/Tool/Friend/AmmoMax/Relic五个类别存在布尔值计连发，不按对象数量；同一其他宠物可同时贡献多个不同类别，最多+5。
- Grappling Hook当前只有Damage+Slow固定两个敌方tempo anchors，没有Pull、Destroy或位移；本批明确不新增相关服务，结算前后坐标必须一致。
- 身份暂定：沉耳跃兔、双响炎牛、三相爆鳍蓑鲉、舰帆棘龙、散弹蜂后、钩臂树懒、爆腺炮步甲、斧喙犀鸟。Dive Weights、Flagship从舰炮迁器械，原生138分类更新为海兽24 / 舰炮53 / 器械25 / 船体13 / 奇物15 / 自然8；Pontoon draft另加器械后为139。
- 本轮新增/细化 `DynamicPacketCountResolver`、`TagCategoryPresenceResolver`、`AmmoUseCommittedConsumer`、`SkillLocalCritModifierChannel`、`AuraStackingPolicy`；继续归并到正式Ammo/Multicast/Cooldown/Leader/Modifier/Trace权威链。
- 下一批舰炮兵器 D：`Harpoon`、`Ice Pick`、`Javelin`、`Jitte`、`Katana`、`Kusarigama`、`Langxian`、`Musket`；仍只讨论来源、身份、机制与公共模块，不填正式数值。
- 已完成第 21 轮舰炮兵器批次 D 8 项的17.2来源刷新、三组独立提案、非死亡封存/控制成长/胜场进度/燃烧装填交叉裁决；累计逐项审阅 115/138。
- `CORRECTED_SOURCE_REFRESH`：Musket 较早抓取显示卡级17.1 Hotfix；同日重开同一 `gtmq...` 直达页后，数据库页头与卡片 `As of` 均明确17.2，public/Deep内容一致。撤销17.1停止线，同时保留抓取时序与旧相邻文案的纠错记录。
- Harpoon 的 Destroy 主案锁为独立 `combat_weight_class=light` 目标的非死亡 `UnitExit(reason=destroy_banish)` 至战末；禁止Damage、拉拽、死亡/击杀收益。正式执行仍等待轻量池、Boss/英雄免疫、每root/每战退出cap和战末幂等恢复。
- Ice Pick/Jitte的Freeze/Slow成长按对应成功root各once/root、root_end提交；Javelin按Deep固定 `Haste其他tempo anchors -> Damage`；Katana保持纯高速单点，不继承旧每回合成长。
- Kusarigama保留Slow与Crit两条独立Deep消费者，各once/root；同root两类都发生时最多成长两次。相邻采用同排x±1回合快照，断链即时、新移入下回合接入。
- Langxian改为inventory instance胜场计数与战后幂等事务，Damage由胜场数×当前品质系数派生；普通死亡不取消，明确Destroy/UnitExit封存取消本场资格。不得复用战内每回合成长字段。
- 本轮身份暂定：穿浪鲣鸟、凿霜银狐、贯风雷猿、迟锋棘蜥、刃鳞青蛇、环刃梦貘、胜棘甲龙、燧喉角鸮；`REVISED_NAME`：Javelin因与正式`pal_088`豪猪底稿产生物种碰撞，由掷风豪猪改为贯风雷猿，只改身份/图鉴/本地化，不改ID或机制。无主类迁移，原生138分类仍为海兽24 / 舰炮53 / 器械25 / 船体13 / 奇物15 / 自然8。
- 本轮新增/细化 `CombatWeightClassRegistry`、`UnitExitService.destroy_banish`、`RootOutcomeAggregator`、`PersistentInstanceProgressService`、`BattleResultIdempotencyLedger`、`DerivedEffectParameterResolver`；继续归并既有Ammo/Reload/Cooldown/Relation/Modifier/Trace权威链，不新增Pull模块。
- 下一批舰炮兵器 E：`Nesting Doll`、`Pistol Sword`、`Pop Snappers`、`Powder Keg`、`Repeater`、`Revolver`、`Rifle`、`Scimitar of the Deep`；仍只讨论来源、身份、机制与公共模块，不填正式数值。
- 已完成第 22 轮舰炮兵器批次 E 8 项的17.2来源、三组独立提案、弹药反应/强制使用/非死亡自退场/跨日实例成长对质与主审裁决；累计逐项审阅 123/138。
- `AUDIT_METHOD_ERROR`：身份组阶段消息曾把题面暂写序号误当正式来源，误报Pistol/Pop为087/088并误归因生成JSON偏移；正式CSV与生成链实际无错，三组均已撤回，正确锚点为079/088/089/092/095/096/097/099，无需修正式数据。
- Powder Keg撤回第3轮“自毁走死亡钩子”：17.2为首个accepted Damage后 `UnitExit(reason=destroy_self)`，不发死亡/击杀/尸体/亡语/召唤收益；其余Multicast包取消。最后单位结算采用全局 `DECISIVE_DAMAGE_LATCH`，同步伤害/免死/反伤完成后再锁胜负。
- Pistol Sword自身Ammo use同root含主动包和一次reaction包；reaction可独立Crit但不是新ITEM_USED，不再耗资源或递归。Repeater保留真实forced use，以causal root的visited source集合阻止双实例循环。
- Nesting Doll显式采用耗弹后Ammo快照计算Leader Shield，每日只给当前Run实例永久+1 MaxAmmo且不补current；Rifle全部Multicast包读root-start Damage、root_end成长once/root；Scimitar的Crit毒与Haste毒队成长各once/root，新成长只影响未来root。
- 身份暂定：层尾山狐、双响刃豪猪、爆响炎獒、爆壳寄居蟹、应鸣花鹿、六晶熔灵、叠晶岩獒、毒潮刃驼；Nesting Doll从舰炮迁奇物，原生138分类更新为海兽24 / 舰炮52 / 器械25 / 船体13 / 奇物16 / 自然8，Pontoon draft另加器械后为139。
- 本轮新增/细化 `OutcomeResolver.DecisiveDamageLatch`、`UnitExitService.destroy_self`、`ForcedUsePolicy`、`RunInstanceProgressLedger`、Ammo反应去重与Leader Shield/Burn/Poison目标；继续并入正式Command/Result/Trace/Snapshot权威链。
- 下一批舰炮兵器 F：`Sharkclaws`、`Shoe Blade`、`Shot Glasses`、`Shovel`、`Shuriken`、`Sniper Rifle`、`Submarine`、`Switchblade`；仍只讨论来源、身份、机制与公共模块，不填正式数值。
- 已完成第 23 轮舰炮兵器批次 F 8 项的17.2来源刷新、三组独立提案、团队Weapon成长/首次根/双状态/整匣连发/唯一Weapon/攻盾/相邻成长交叉裁决；累计逐项审阅 131/138。
- `SOURCE_PUBLIC_DEEP_SCOPE_CONFLICT`：Sharkclaws public简写为“Your items”，Deep明确只筛Weapons；本地候选按Deep，只强化每宠唯一Weapon伤害锚点，并保留冲突证据，不能静默扩成全队技能。
- `ID_ALIAS_CONFLICT_CONTENT_EQUIVALENT`：Submarine的`h88...`与`5rj...`直达页本轮均显示17.2且内容签名一致；正式业务键不依赖card ID，两者均留alias审计，不生成第二对象。
- Shot Glasses锁定同一support root内 `Slow己方 -> Haste己方` 两条独立application通道；即使最终冷却净抵消，也不得在事件前合并，否则会丢失Slow/Haste消费者。
- Shoe Blade首次成功root的所有Multicast包共享首次Crit资格，拒绝/回滚不耗标志；Shuriken按使用前当前Ammo冻结内生包数，外部Multicast另加，一次清空Ammo后结算全部包。
- Sniper唯一Weapon按棋盘来源宠物实例计数；Submarine每包Damage后过死亡安全点再给Leader等面板Damage盾，唯一Weapon抗控只作用自身；Switchblade继续用可见棋盘同排左右回合快照，root-end成长只影响未来根。
- Shovel每日奖励走局外Run库存事务，不是召唤；跨英雄Small池、品质、出售、背包满、RNG持久化与多实例政策冻结前保持经济深红。
- 身份暂定：鲨爪海狮、踏刃赤雕、双拍夜鸦、掘宝土豚、旋棘甲蝎、孤准射水鱼、深潜铁鲸、弹冠雷蜥；工作分类接受Shot Glasses迁奇物、Shovel/Submarine迁器械，原生138更新为海兽24 / 舰炮49 / 器械27 / 船体13 / 奇物17 / 自然8。
- 本轮新增/细化 `FirstUseLedger`、`RootApplicationAggregator`、`CombatTagProjection`、`GrantRewardFromPool`、`DeterministicTargetSelectionSnapshot`，继续归并既有Ammo/Multicast/Leader/Relation/Modifier/Trace权威链。
- 下一轮处理最后7个Vanessa原生对象并做138覆盖复核；之后再单列Pontoon Skimmer跨英雄第139草案，不篡改原生ID。
- 已完成第24轮正式映射收尾7项：Bilge Worm、Jetbike、The Boulder、Throwing Knives、Tiny Cutlass、Torpedo、Trebuchet；项目正式映射累计审阅达到138/138。该口径不等于当前17.2凡妮莎原生清单，Tiny Cutlass当前为Common/neutral，Bilge Worm存在历史别名/抓取链不一致，均已单列来源警告。
- `RETRACTED_ALIAS_INPUT`：撤回把bz_van_009称为Hate Leech及继承自毒/全队Crit成长/己方Crit催动；正式锚点仍为Bilge Worm→pal_009，Hate Leech只留历史别名。
- The Boulder本地候选按普通敌方战斗单位MaxHP快照造成Damage，仍走Crit/盾/减伤/免死，不是Destroy/处决；在统一动态公式、目标权威与峰值门禁完成前暂停正式数值。
- Throwing Knives按当前17.2改为“另一对象Crit后forced use”，不再用旧Charge；Tiny Cutlass固定2个完整包并独立Crit；Torpedo对public/Deep布尔歧义采用玩家可读括号并标本地偏离。
- `SOURCE_PUBLIC_DEEP_TRIGGER_CONFLICT`：Trebuchet当前public排除自身Weapon，Deep为any Weapon。三组复议后最终按既有Deep优先政策采用“任意Weapon，包含自身”；自身A先启动CD再提交pending Charge，避免现有finish顺序覆盖。public排除自身只保留为文案优先备选。
- Jetbike的Flying是幂等战斗关键词，不提供位移/闪避/额外身体；邻接使用按可见棋盘回合快照，同root刚获得Flying不追溯触发Charge。
- 身份暂定：舱底血蛭、翠翼喷驹、崩岳岩团虫、飞牙白象、双斩狨猴、蓄冲剑吻豚、投焰槌尾龙。Bilge/Boulder/Jetbike分别迁海兽/自然/器械，正式138工作分类更新为海兽25 / 舰炮46 / 器械28 / 船体13 / 奇物17 / 自然9。
- 本轮新增/细化 `EnemyRelationSnapshot`、`LifestealResolver`、`DynamicDamageFormulaResolver`、`ForcedUseCoordinator`、`FlyingKeywordState`、`CritDamageModifierChannel`；继续归并既有Ammo/Multicast/Cooldown/Leader/Trace权威链。
- 下一轮单列Pontoon Skimmer跨英雄第139候选并做总收口：核当前来源英雄/版本/机制，给出不抢占正式ID的身份草案、P0/P1/P2模块依赖、AI/UI/教程/经济/存档/QA/来源刷新路线。仍不填正式数值、不改运行时代码。
- 已完成第25轮Pontoon Skimmer来源刷新、跨英雄第139候选与全案总收口。当前17.2直页确认其为Pygmalien、Silver、Large、Vehicle/Aquatic，起飞/落地/Leader Shield/Charge机制可核；撤回早期“机制未知”，保留 `SOURCE_SCOPE_CONFLICT_STOP`。
- 第139身份定为“双舟滑獭”，仅使用 `draft_van_pontoon_skimmer`，body_count=1、主类器械；“浮潮翼鳐”因与IllusoRay/Sharkray撞型撤回。`pal_139`禁止占用，未来只有主策批准跨英雄新增并完成全局扫描后才考虑`pal_370`。
- Pontoon本地候选采用support_bundle：每个真实Flying false→true application分别触发Leader Shield和对应tempo anchor Charge；Flying友方use时在提交安全点让触发者与Pontoon幂等落地。技术/平衡深红，只可作隔离fixture，不进入正式内容或池。
- 全案P0收敛为来源schema、四级事件事务、执行模式、可见棋盘关系/标签、冷却/关键词、Multicast/Ammo/forced use、Leader/Outcome/UnitExit、成长/经济存档和确定性QA；禁止138个专属handler。
- 首批无数值纵切建议Tiny Cutlass + Bayonet + Star Chart + Mantis Shrimp；随后Bilge Worm + Submarine补Leader链，Jetbike + Pontoon fixture补Flying链，再做UnitExit、动态MaxHP与局外经济。
- 策划层138只身份防撞已审阅通过；美术量产仍需规范化identity manifest、全量黑剪影墙、动作/VFX语义门、图鉴本地化和解锁引用门。正式138分类锁为25/46/28/13/17/9，另计Pontoon为139。
- 本任务已完成用户要求的本地全过程记录与138+1机制/身份/模块/配套策划收口。因artifact-tool缺失，未生成xlsx；正式workbook、CSV、生成JSON、运行时代码和数值均未修改。
- `SCOPE_AUDIT_WARNING`：006_economy中的369个`bz_van_*`生成备注覆盖item/skill/merchant_package对应的全部shop pet，不能误计为369件Vanessa item；本轮以正式CSV的`source_type=item`过滤得到138行。

## 第三轮公共机制词典裁决

- Haste 玩家词定为“催动”：秒数型优先解释为减少目标技能剩余 `cooldown_ticks`；百分比冷却缩减另用冷却效率。禁止改共享技能条顺序或免费补发已经经过的技能。
- Slow 玩家词定为“阻滞”：秒数型优先解释为增加目标技能剩余冷却；百分比型另用负向冷却效率。Freeze 若要硬控，另建“封锁下一次技能”，不与普通阻滞混用。
- Multicast 玩家词定为“连发”：`连发 +N` 表示同一次技能发动额外完整结算 N 次；不扩大形状、不增加技能条项目、不重复启动冷却。复合技能需要 `NEEDS_EFFECT_PACKET_REPEAT`。
- Adjacent 禁止裸写“相邻”。至少区分上下左右1格、固定左/右1格、面向前/后/两侧、周围8格、命中目标上下左右；每件还要明确锚点、阵营、单位类型、数量和触发时点。
- Destroy 拆为击败、处决、自毁、退场、驱散、拆除、消散、变形。击败/处决/自毁必须走死亡安全点；驱散召唤物、拆墙和临时单位消散不得冒充击杀。
- Ammo 玩家词定为“弹药 X/Y”，使用独立单场资源账本；换回合不补、同场宠物重置不补、新战斗按定义初始化，不能复用 AP、冷却或宠物重置次数。
- 购买、获得、出售、复制、合成、每日触发必须是不同的权威事务。`身价` 默认只参与技能计算，不改变出售所得。
- 当前存在潜在“折扣购买 -> 按完整品质退款出售”的正收益路径；经济组要求引入带实际支付成本和获得方式的 `acquisition_lots`，并在套利门禁通过前暂停出售成长正式定案。

## 第四轮 12 个试金石会审

- 可优先进入机制草案：`Bayonet`、`Star Chart`，风险为黄色；仍需裁决左/右或上下左右相邻、暴击判定粒度和光环叠加。
- 带硬门禁才可进入草案：`Ambergris`、`Anchor`、`Ballista`、`Barrel`、`Beach Ball`、`Iceberg`、`Shuriken`、`Shipwreck`，风险为红色。
- 暂停：`Dam` 未裁决体型、献祭对象和死亡链；`Pontoon Skimmer` 当前来源机制缺失。
- 身份组建议进入全局交换池：`Anchor -> pal_104 铁甲巨兕`、`Barrel -> pal_032 石甲鲮`、`Iceberg -> pal_099 冰峰巨驼`、`Shuriken -> pal_027 惊羽雀`；这些只是候选，必须检查交换后的另一端是否同样改善。
- 新身份草案包括：Ambergris“琥香鲸灵”、Beach Ball“弹潮海豚”、Dam“堰潮河狸”、Pontoon“浮潮翼鳐”；均非正式命名。
- 三组共同要求：Adjacent 每个已提交技能事务只触发一次；Multicast 只重复主效果包；Destroy 先冻结候选再进入死亡/退场协议；经济触发只认成功提交的权威事务。
- 当前优先级：先以 Bayonet 和 Star Chart 做黄色机制样板，再处理红色门禁，不从 Pontoon 或 Dam 开始。
