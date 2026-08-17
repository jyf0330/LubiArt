# 凡妮莎 139 物品 × 139 宠物策划小队持续讨论纪要

- 状态：持续讨论中
- 建立日期：2026-08-17
- 目标：将《大巴扎》凡妮莎当前 139 件物品分别转译为 139 只不同宠物；保留玩法体验，不照搬实时物品战斗规则。
- 当前边界：只做来源审计、宠物身份、机制转译、风险分级与测试设计；不修改正式 workbook、CSV、生成 JSON、运行时代码或正式数值。
- 权威项目：`/Users/ywh/Documents/godot-latest`
- 当前来源清单：`https://bazaarwinner.com/hero/vanessa`
- 当前项目来源快照：`data/content/generated/006_economy.json`
- 正式上游策划表（只读）：`/Users/ywh/Documents/ysbzs/xlsx/ysbzs_master.xlsx`

## 阅读方法

本文件按讨论轮次追加，不覆盖早期错误观点。每一轮保留：

1. 当时的提案；
2. 反对意见；
3. 证据或代码事实；
4. 被纠正内容；
5. 阶段裁决；
6. 仍未决定的问题。

标记说明：

- `FACT`：当前来源或当前代码已确认事实。
- `HISTORY`：旧版本参考，不能冒充当前规则。
- `PROPOSAL`：策划候选。
- `REJECTED`：已明确否决。
- `PENDING`：等待主策或后续证据。
- `BLOCKED`：缺当前来源、底层能力或数据口径，禁止进入正式方案。

## 第 0 轮：目标与数据口径

### 用户确认

- 采用严格口径：凡妮莎 139 件物品分别对应 139 只不同宠物。
- 物品之间不得复用同一只宠物。
- 讨论过程需要持续保存在本地，便于之后完整复盘。

### 当前来源核对

- `FACT`：当前凡妮莎清单为 139 件。
- `FACT`：项目现有旧基线为 138 个凡妮莎 item 来源对象，绑定 `pal_001..pal_138`。
- `FACT`：当前项目共有 369 个 Bazaar 来源对象与 369 个宠物映射对象；除 138 件 item 外，还包括技能和商人包来源对象。
- `FACT`：3 个差异属于改名兼容，不新增宠物：
  - `Bonfire -> Flame Signal`
  - `Bilge Worm -> Hate Leech`
  - `Suppressor -> Silencer`
- `FACT`：真正新增的是 `Pontoon Skimmer / 浮筒滑翔艇`。
- `FACT`：`pal_139` 已绑定 `Alacrity / 雷鲭王`，不能无冲突挪给新物品。
- `PROPOSAL`：策划阶段使用 `draft_van_pontoon_skimmer`；若正式接受新增对象，优先新增 `pal_370`，不重排现有 369 对象。

## 第 1 轮：三组独立审阅

### 战斗转译组

#### 当前战斗事实

- `FACT`：战斗棋盘为 8×7，双方各最多四只宠物，另有双方英雄。
- `FACT`：最长 12 回合；英雄死亡立即结算，否则按第 12 回合英雄生命判断。
- `FACT`：四宠共享可由玩家重排的技能控制条，每宠最多两个正式技能。
- `FACT`：技能按稳定顺序执行；隐式标签组合技已经关闭。
- `FACT`：宠物价值由站位、19 种可旋转形状、技能序列、元素铺层、受击/死亡/召唤等共同构成。
- `FACT`：召唤物、墙和陷阱占真实棋盘格。
- `FACT`：死亡必须经过统一伤害管线和死亡安全点。
- `FACT`：旧 138 宠实际 `skills` 大量复用相同基础技能，不能把来源序号映射当作机制已设计完成。

#### 初步反对项

- `REJECTED`：Small/Medium/Large 直接变成 1/2/3 格宠物。
- `REJECTED`：秒数直接变成 AP。
- `REJECTED`：Multicast 直接扩大形状。
- `REJECTED`：相邻物品统一解释成任意友军。
- `REJECTED`：Destroy 直接删除宠物或绕过死亡安全点。
- `REJECTED`：把旧 `pal_001..138` 当作 138 套已完成技能。

### 宠物身份组

#### 旧映射不是完全随机

- `FACT`：来源品质与旧本地品质 138/138 一致。
- `FACT`：主附魔强烈影响粗职责：
  - Deadly 多为输出/逐回合攻击成长；
  - Turbo 多为机动；
  - Icy/Toxic 多为控制；
  - Restorative 多为治疗；
  - Shielded 多为坦克。

#### 旧映射仍不够成为宠物身份设计

- `FACT`：宠物名称、物种和来源物品主题普遍缺少语义联系。
- 示例：
  - Ambergris → 棉角羊；
  - Anchor → 灰尾狸；
  - Beach Ball → 藤甲猿；
  - Pufferfish → 连理双鹿。
- `FACT`：来源尺寸与攻击形状没有稳定关系。
- `PROPOSAL`：保留来源 ID、来源事实、来源标签与历史映射；宠物名、物种、元素、形状、职责和技能均可重排。

### 数值与成长组

- `FACT`：本地品质不是单纯数值倍率；0/2/5/9 进化点关联阶段质变。
- `FACT`：当前旧效果分没有计入命中概率、形状覆盖、技能频率、元素层、连发、弹药或成长上限，不能作为最终 139 宠平衡总分。
- `PROPOSAL`：预算至少拆成：基础面板、形状覆盖、频率、主效果、控制/治疗、成长、经济、条件成本、冷却/弹药/站位成本。
- `PROPOSAL`：同时观察单回合峰值、五回合累计、十二回合理论上限、稳定性和经济贡献，不使用单一总分。

## 第 2 轮：交叉互审与纠错

### 争议一：来源品质是否等于本地品质

身份组初始意见：旧表 138/138 一致，可考虑保留。

数值组反对：

- 来源 Gold/Diamond 若直接成为本地黄金/钻石，会同时获得晚出现、高基础面板、本地品质成长和品质质变，形成重复计价。

阶段裁决：

- `FACT`：旧一致性只证明生成规则，不证明玩法合理。
- 来源品质更名为 `来源起始品质`。
- 独立增加 `本地初始阶段`、`2点质变`、`5点质变`、`9点质变`、`本地最终稀有度`。
- 旧本地品质保留为历史映射值，不直接覆盖或删除。

### 争议二：Cooldown 是否换 AP

数值组初始提案：Cooldown 可成为 AP 机会成本。

战斗组用代码事实纠正：

- `FACT`：当前“全部出击”不会逐技能扣 AP；技能阶段结束才统一把 AP 归零。
- `FACT`：AP 主要服务移动、旧行动槽和自动站位预算。

阶段裁决：

- `REJECTED`：把秒制冷却默认换成 AP。
- 默认候选为按回合推进的 `cooldown_ticks`。
- AP 只用于明确表达“放弃其他行动机会”的少量机制，且需先验证正式技能链能兑现。

### 争议三：Multicast 的本地含义

阶段裁决：

- 玩家词定为“连发”。
- `连发 +N` 表示同一次发动额外完整结算 N 次。
- 不扩大形状，不插入额外技能条项目，不重复启动冷却。
- 纯伤害可候选 `strike_count/repeat_count`。
- 纯铺层可候选 `application_count`。
- 伤害+状态+护盾等复合包标记 `NEEDS_EFFECT_PACKET_REPEAT`。
- 每一包之间是否结算死亡必须显式配置，不能混用“多段伤害”和“完整技能连发”。

### 争议四：Pontoon Skimmer 当前机制

身份/数值组初始引用：Silver、Vehicle/Aquatic、Flying、Shield、Charge。

随后复核：

- `FACT`：当前页面只确认 Vanessa、Large、推断 Gold、D5。
- `FACT`：`dataSource=inferred`，置信度 0.50。
- `FACT`：当前 `tags=[]`、`tierData=[]`、`unifiedTooltips=[]`。
- `HISTORY`：Silver、Vehicle/Aquatic、Flying、Shield、Charge 来自 2026-04-13 patch 13.3 旧版本。

阶段裁决：

- `REJECTED`：用旧版本机制填补当前空白。
- `BLOCKED`：Pontoon 的正式元素、角色、技能、冷却、充能和数值全部暂停。
- 允许在历史灵感列记录“浮筒/滑翔/水空机动”，但不得进入正式机制列。

## 第 3 轮：公共机制词典

### Haste：催动

- 秒数型推荐语义：目标技能剩余冷却减少 N 回合，最低为 0。
- 百分比冷却缩减另用冷却效率，不和即时催动共用字段。
- 已经执行或已经经过的技能被催动到 0，本轮不补发。
- 尚未轮到的技能被催动到 0，轮到时可正常发动。
- 禁止永久重排玩家技能条。

需要的公共能力：

- `modify_skill_cooldown`
- 指定宠物/指定技能选择器
- 冷却 before/after/delta Trace
- Snapshot 显示技能剩余冷却

### Slow：阻滞

- 秒数型推荐语义：目标技能剩余冷却增加 N 回合。
- 百分比型另用负向冷却效率。
- 不撤销已发生的技能。
- Freeze 若要做硬控，应单独建立“封锁下一次技能”，不与普通阻滞混用。
- 现有 `status_slow` 只改 speed，无法完成共享技能条阻滞。

### Multicast：连发

最小词典：

- `multicast_extra`
- `resolution_count = 1 + multicast_extra`
- `repeat_scope = damage | element | effect_packet`
- `target_policy = locked_cells_live_occupants`
- `death_policy`
- `skill_hook_policy = once`
- `cooldown_policy = once`
- `max_multicast_extra`

### Adjacent：禁止裸写“相邻”

允许的玩家词和几何：

- 自身上下左右 1 格：`orthogonal_1`
- 自身左边 1 格：`screen_left_1`
- 自身右边 1 格：`screen_right_1`
- 面向方向前面 1 格：`facing_front_1`
- 面向方向后面 1 格：`facing_back_1`
- 面向方向两侧各 1 格：`facing_sides_1`
- 周围 8 格：`surrounding_8`
- 命中目标上下左右 1 格：`target_orthogonal_1`

每件还必须填写：锚点、友敌关系、单位类型、目标数量、触发时点、是否随移动更新。

### Destroy：拆成八个正式动词

- 击败：正常伤害使 HP 归零，走死亡安全点。
- 处决：条件成立后产生致死结果，走死亡安全点。
- 自毁：自身作为代价被击败，走死亡安全点。
- 退场：正式宠本场暂离棋盘，不触发死亡，需要新生命周期。
- 驱散：移除召唤物/临时单位，不触发死亡/击杀。
- 拆除：移除墙/障碍，不触发击杀。
- 消散：临时单位自然结束，不触发死亡链。
- 变形：原单位退场并生成新单位/墙，分两步处理。

三件来源逐项问题：

- Dam：变墙、退场、自毁三案未决。
- Harpoon：项目没有正式 Small/Medium/Large 战斗体型；候选为驱散召唤物、低血处决或新增体型字段。
- Powder Keg：最适合自毁，但爆炸前后、护盾、自身亡语、击杀归属均需定案。

### Ammo：弹药

默认语义：

- 独立的单场战斗资源，不复用 AP、冷却或宠物重置次数。
- 新战斗按配置初始化。
- 换回合不补弹。
- 技能被拒绝、无合法目标时不耗弹。
- 技能成功提交时原子扣弹一次。
- 装填不超过上限，溢出丢弃。
- 同场宠物重置不补弹，需由稳定实例/技能资源账本恢复。
- 战斗结束清空；若要跨战，另建 Run 资源。

建议运行态：

- `battle_resource_ledger`
- `owner_instance_id`
- `skill_id`
- `current/max`
- `spent_total/reloaded_total`
- `last_transaction_id`

### 购买、出售、获得、复制、合成、每日

必须是不同权威事务：

- 购买：扣金并成功得到商品后触发。
- 获得：奖励、生成、复制等非购买来源。
- 出售：金币到账且持有数量减少后触发。
- 复制：产生副本，不算购买。
- 合成：相同宠物合并升级，不算购买/出售。
- 每日：成功进入新一天时触发一次；当天新得宠物从下一天开始生效。

`身价` 默认只参与技能计算，不改变出售退款。

经济红线：

- 当前存在潜在“折扣购买 -> 按完整品质退款出售”的正收益路径。
- 免费生成、复制、合成、升级后出售可能继续放大。
- `acquisition_history` 不足以准确消费合成后的成本批次。
- `PROPOSAL`：新增 `acquisition_lots`，记录 kind、实际支付成本、品质、数量、日期、父批次。
- 在经济循环审计通过前，购买/出售/身价成长保持讨论状态。

## 第 4 轮：12 个高争议试金石会审

### 会审总结果

- 黄色，可先进入机制草案：Bayonet、Star Chart。
- 红色，只有满足硬门禁才可进入：Ambergris、Anchor、Ballista、Barrel、Beach Ball、Iceberg、Shuriken、Shipwreck。
- 暂停：Dam、Pontoon Skimmer。

### 逐项摘要

| 物品 | 现映射 | 身份组草案 | 战斗转译核心 | 风险/状态 | 主要未决问题 |
|---|---|---|---|---|---|
| Ambergris | pal_001 棉角羊 | 琥香鲸灵 | 购买水系宠物积累 Run 成长；战斗内按固化成长治疗 | 红 / 条件草案 | 成长按次数、金币还是专属身价；经济套利 |
| Anchor | pal_002 灰尾狸 | 沉锚海犀；可考察 pal_104 铁甲巨兕 | 相邻宠物技能后催动自身；对形状首目标造成有上限的最大生命比例伤害 | 红 / 条件草案 | 相邻按棋盘还是队伍栏；Boss/英雄上限 |
| Ballista | pal_005 赤尾狐 | 雷弩角鹿 | 其他弹药技能使用后，本场获得有上限连发；自身为重型形状伤害 | 红 / 条件草案 | 连发上限；多段还是包间死亡；乘法爆炸 |
| Barrel | pal_006 碧水鸭 | 箍甲犰狳；可考察 pal_032 石甲鲮 | 相邻宠物技能后提升自身后续护盾能力 | 红 / 条件草案 | 每事务还是每轮成长；即时盾与能力成长分离 |
| Bayonet | pal_007 雷须猫 | 刺锋蜜獾 | 左边 1 格输出宠物技能后，对其目标追击一次 | 黄 / 优先样板 | 左边按棋盘还是阵容；原目标死亡后落空或重选 |
| Beach Ball | pal_008 藤甲猿 | 弹潮海豚 | 主动催动若干水系/玩具友军技能，不额外施法 | 红 / 条件草案 | Toy 正式标签；目标数量；互相催动循环 |
| Dam | pal_035 藤巢蜂 | 堰潮河狸；可考察 pal_069 碎岩巨龟 | 变墙、退场或自毁/献祭三案 | 红 / 暂停 | 本地体型、献祭对象、死亡归属、Run 名册保护 |
| Iceberg | pal_058 丹角火麟 | 冰脊巨鲸；可考察 pal_099 冰峰巨驼 | 敌方技能结算后阻滞刚发动的技能 | 红 / 条件草案 | 普通阻滞还是硬冻结；Boss 抗性；软锁上限 |
| Shuriken | pal_111 毒甲蝎将 | 雷镖飞鼯；可考察 pal_027 惊羽雀 | 消耗全部弹药，按冻结的弹药快照结算纯伤害连发 | 红 / 条件草案 | 0 弹是否可用；基础1次还是弹药即总次数；Boss 总上限 |
| Shipwreck | pal_107 天羽云螭 | 沉舟骨鲸 | 水系宠物获得不叠加的安全连发光环 | 红 / 条件草案 | 只支持 repeat_safe 包；死亡后光环；是否含自身 |
| Star Chart | pal_115 南明朱雀 | 星航鸾 | 相邻友军获得暴击和冷却效率光环 | 黄 / 优先样板 | 左右还是上下左右；动态还是开场锁定；叠加规则 |
| Pontoon Skimmer | 无 | draft：浮潮翼鳐 | 当前机制未知，不写技能 | 白 / 来源阻断 | 等当前权威资料；不占 pal_139 |

### 三组共同门禁

- Adjacent 每个已提交技能事务只触发一次；三段、范围、连发子包不增加触发次数。
- Multicast 只重复显式主效果包；外层技能使用事件、冷却启动、弹药消费各一次。
- 当前旧形状普遍含三段结算，“连发 × 三段 × 多格”不能三轴都按满额预算。
- Destroy 先冻结全部候选，再进入死亡/退场协议；不能因逐只结算重新计算候选。
- 经济触发只认成功提交的购买/出售事务。

## 身份分群基线

当前 139 宠建议先按六个身份主类分批讨论：

| 身份主类 | 数量 | 转译原则 |
|---|---:|---|
| 海兽伙伴 | 24 | 来源本身是生物时优先保留物种大类或明确神话演化 |
| 舰炮兵器 | 55 | 用角、牙、爪、甲壳、尾刺等生物器官承接枪炮/刀械的攻击动词 |
| 器械载具 | 24 | 用机械共生、骑乘、飞行、水陆转换轮廓承接工具和载具 |
| 船体据点 | 20 | 用龟、犀、鲸、贝、甲壳兽承接护盾、场地和前排阵地 |
| 奇物谋略 | 6 | 以收藏、诱饵、陷阱、价值、骗术塑造宠物性格 |
| 自然异象 | 10 | 用火山、海雾、风暴、潮汐表达元素和环境机制 |
| 合计 | 139 | 次级标签允许交叉，但每只宠物只占一个来源物品 |

## 后续追加计划

1. 先用 Bayonet、Star Chart 形成两个黄色风险完整样板行。
2. 按六个身份主类分批审阅其余 127 件。
3. 每批保留身份组、战斗组、数值组的不同意见，不只记录主策结论。
4. 每行必须填写来源事实、当前/历史版本、身份决议、机制转译、技术缺口、风险色和未决问题。
5. 在公共机制样板通过固定种子模拟前，不填写正式数值。

## 当前未决问题总表

1. 相邻默认采用棋盘上下左右还是队伍控制条左右。
2. Haste/Slow 的秒数到回合冷却换算档位。
3. Freeze 是否建立独立硬控制原语。
4. 复合 Multicast 的效果包重复和包间死亡安全点。
5. Ammo 的稳定宠物实例 ID、同场重置和回撤协议。
6. Destroy 的处决/退场/驱散/拆除生命周期。
7. Dam 的核心本地身份到底是变墙、退场还是自毁献祭。
8. 经济退款按品质、实际支付成本还是批次成本核算。
9. 来源品质与本地获取稀有度、成长品质的最终产品关系。
10. 139 宠允许多少只依赖新增公共底层原语。
11. Pontoon Skimmer 当前权威机制何时补齐。
12. 是否正式新增 `pal_370`。

## 第 5 轮：全量身份索引与两个完整样板

### 139/139 身份索引校验

- 139 个当前英文名唯一。
- 139 条身份分类唯一，无重复、无遗漏。
- 138 个旧 `pal_id` 加 `draft_van_pontoon_skimmer`，身份键唯一。
- 3 个改名继续继承原 ID：
  - Flame Signal / pal_014
  - Hate Leech / pal_009
  - Silencer / pal_119

#### 海兽伙伴 24

`Calico/pal_016`、`Catfish/pal_023`、`Darkwater Anglerfish/pal_036`、`Electric Eels/pal_043`、`IllusoRay/pal_059`、`Jellyfish/pal_063`、`Mantis Shrimp/pal_074`、`Mr. Richardson/pal_076`、`Narwhal/pal_078`、`Old Saltclaw/pal_080`、`Orange Julian/pal_082`、`Pesky Pete/pal_084`、`Pet Rock/pal_085`、`Piranha/pal_087`、`Pufferfish/pal_093`、`Seashadow/pal_102`、`Sharkray/pal_106`、`Slumbering Primordial/pal_112`、`Tortuga/pal_126`、`Vampire Squid/pal_131`、`Yeti Crab/pal_137`、`Zoarcid/pal_138`、`Flying Fish/pal_049`、`Marlon/pal_075`。

身份组裁决：这 24 件最先重做身份。绝大多数来源已经是明确生物，现有陆生或随机物种映射不能继续当正式身份。

#### 舰炮兵器 55

`Anchor/pal_002`、`Arbalest/pal_003`、`Ballista/pal_005`、`Bayonet/pal_007`、`Bladed Hoverboard/pal_010`、`Blowgun/pal_011`、`Blunderbuss/pal_012`、`Bolas/pal_013`、`Butterfly Swords/pal_015`、`Cannon/pal_017`、`Cannonade/pal_018`、`Cauterizing Blade/pal_024`、`Concealed Dagger/pal_027`、`Cutlass/pal_033`、`Cyber-Sai/pal_034`、`Dart Launcher/pal_037`、`Dive Weights/pal_039`、`Double Barrel/pal_042`、`Elemental Depth Charge/pal_044`、`Flagship/pal_048`、`Grapeshot/pal_050`、`Grappling Hook/pal_051`、`Grenade/pal_052`、`Handaxe/pal_053`、`Harpoon/pal_054`、`Hate Leech/pal_009`、`Ice Pick/pal_057`、`Javelin/pal_062`、`Jitte/pal_065`、`Katana/pal_066`、`Kusarigama/pal_068`、`Langxian/pal_069`、`Musket/pal_077`、`Nesting Doll/pal_079`、`Pistol Sword/pal_088`、`Pop Snappers/pal_089`、`Powder Keg/pal_092`、`Repeater/pal_095`、`Revolver/pal_096`、`Rifle/pal_097`、`Scimitar of the Deep/pal_099`、`Sharkclaws/pal_105`、`Shoe Blade/pal_108`、`Shot Glasses/pal_109`、`Shovel/pal_110`、`Shuriken/pal_111`、`Sniper Rifle/pal_113`、`Submarine/pal_117`、`Switchblade/pal_121`、`The Boulder/pal_122`、`Throwing Knives/pal_123`、`Tiny Cutlass/pal_124`、`Torpedo/pal_125`、`Trebuchet/pal_127`、`Jetbike/pal_064`。

边界项：Submarine、Flagship、Jetbike 若最终核心是移动/运载/占格，应迁入器械载具，不能只按名称决定。

#### 器械载具 24

`Astrolabe/pal_004`、`Captain's Wheel/pal_021`、`Custom Scope/pal_032`、`Diving Helmet/pal_040`、`Dock Lines/pal_041`、`Fishing Net/pal_046`、`Fishing Rod/pal_047`、`Honing Steel/pal_056`、`Integrated HUD/pal_061`、`Lighter/pal_071`、`Oni Mask/pal_081`、`Powder Horn/pal_091`、`Ramrod/pal_094`、`Rowboat/pal_098`、`Sextant/pal_104`、`Shipwreck/pal_107`、`Silencer/pal_119`、`Spyglass/pal_114`、`Star Chart/pal_115`、`Stealth Glider/pal_116`、`Submersible/pal_118`、`Weather Glass/pal_135`、`Wetware/pal_136`、`Pontoon Skimmer/draft_van_pontoon_skimmer`。

#### 船体据点 20

`Barrel/pal_006`、`Captain's Quarters/pal_020`、`Coral Armor/pal_029`、`Cove/pal_030`、`Crow's Nest/pal_031`、`Dam/pal_035`、`Disguise/pal_038`、`Holsters/pal_055`、`Iceberg/pal_058`、`Korxena Crest/pal_067`、`Life Preserver/pal_070`、`Lighthouse/pal_072`、`Pearl/pal_083`、`Port/pal_090`、`Sea Shell/pal_100`、`Seadog's Saloon/pal_101`、`Swash Buckle/pal_120`、`Tropical Island/pal_129`、`Turtle Shell/pal_130`、`Water Wheel/pal_134`。

边界项：Disguise、Holsters、Swash Buckle 是否迁入奇物谋略，等逐项机制裁决。

#### 奇物谋略 6

`Ambergris/pal_001`、`Beach Ball/pal_008`、`Coral/pal_028`、`Figurehead/pal_045`、`Lockbox/pal_073`、`Tripwire/pal_128`。

#### 自然异象 10

`Cannonball/pal_019`、`Card Table/pal_022`、`Chum/pal_025`、`Clamera/pal_026`、`Flame Signal/pal_014`、`Incendiary Rounds/pal_060`、`Piano/pal_086`、`Seaweed/pal_103`、`Volcanic Vents/pal_132`、`Wanted Poster/pal_133`。

边界项：Cannonball、Card Table、Piano、Wanted Poster 很可能需要在逐项机制审阅后迁类。

### 建议分批顺序

1. 来源修复门禁：Flying Fish、Marlon、Jetbike、Pontoon Skimmer，以及 3 个改名兼容。
2. 海兽伙伴 24：先修复明确物种错位。
3. 船体据点 20 + 奇物谋略 6。
4. 器械载具 24。
5. 自然异象 10，并复核边界项。
6. 舰炮兵器 55，拆成近战投掷、枪械弹药、重炮平台三批。

### Bayonet 完整样板的三方分歧

#### 战斗组初稿

- `PROPOSAL A`：共享技能条左邻。
- 优点：最贴近原作物品栏左侧关系；玩家可通过技能条重排构筑。
- 风险：一宠两技能、技能格拆散、反应/连发/追击递归，需要外层技能事务 ID 和每轮上限。

#### 数值组初稿

- `PROPOSAL B`：编队左侧宠物。
- 优点：预算按宠物而不是技能格计算，关系更稳定。
- 风险：左邻宠物有 A/B 两技能，仍需每轮一次门禁。

#### 交叉复审

- 数值组复审后接受 A：共享技能条左邻。
- 身份组复审后接受 A，认为刺刀像装在另一技能上的附件，UI 可用卡榫和连线表达。
- 战斗组二次复审却改判为 B，理由是商业化可复用性更高、规则协议更小，不会形成“技能格谜题”。

当前状态：`PENDING`，三组未达成一致。

两案共同门禁：

- 只接受玩家外层成功技能事务，不接受连发子包、追击、反击或免费效果。
- 每轮最多触发一次。
- 追击是 `REACTION_EFFECT`，不得再次发布武器使用事件。
- 追击使用 Bayonet 自己的方向与窄形状，不继承来源技能范围。
- 三段、多格、连发都不能增加触发次数。

### Star Chart 完整样板的三方分歧

#### 战斗组初稿 / 数值组复审接受

- `PROPOSAL A`：棋盘上下左右四格；在回合布局锁定后记录受益友军，增益保留到回合末。
- 优点：充分使用 8×7 棋盘，规则稳定，回放简单。
- 风险：最大受益者从原作左右两件扩大到四只；先聚拢获取增益再移动散开可能形成快照利用。

#### 战斗组二次复审改判

- `PROPOSAL B`：棋盘同行左右两格；回合开始获得资格；关系断开立即失效；新进入者本轮不补发。
- 优点：保留原作最多两个邻居，站位光环可被移动反制，来源退场后效果立即失效。
- 风险：每次属性读取都要检查来源与目标位置，协议更复杂。

#### 身份组纠错

- 身份组曾把“冻结受益者集合”误读为“冻结敌人”。
- `REJECTED`：Star Chart 冻结敌人的提案。来源没有 Freeze。
- 修正后身份组支持 A：回合开始锁定四邻友军，给予暴击率和冷却效率；UI 使用星芒与计时环，禁止雪花/冰晶反馈。

当前状态：`PENDING`，A/B 都保留。

两案共同门禁：

- 只作用友军宠物，不作用英雄。
- 暴击与冷却效率必须白名单作用域。
- 多个 Star Chart 默认使用 `max_by_stat`，不无上限相加。
- 已有剩余冷却不即时回改，只影响之后启动的新冷却。
- 回合快照必须在所有免费自动站位/方向调整结束后、第一项能产生收益的行动之前生成。

### Bayonet 与 Star Chart 无数值预算模板

Bayonet：

`单回合追击价值 = 有效外层触发数 × 单次追击主效果 × 有效率`

`五回合价值 = Σ(存活且关系有效 × min(触发数, 回合上限) × 单次主效果 × 有效率)`

转红门槛：追击递归、同时多段和多目标、五回合追击接近或超过左邻完整输出、先手稳定在后手首次行动前减员。

Star Chart：

`五回合增量 = Σ受益宠物[有增益时五回合合法发动价值 - 无增益时五回合合法发动价值 - 站位/移动成本]`

转红门槛：第一回合跨冷却阈值多发动、三至四宠沿用两邻强度、多个星图无上限叠加、快照阶段早于免费站位、读档/回撤重复发放。

### 经济套利证据等级

`FACT`：基础品质价格为 2/4/6/8。

`FACT`：商店候选购买价按折扣计算：`core/shop/shop_offer_factory.gd`。

`FACT`：购买扣商品快照中的折后 `offer.price`：`core/state/game_state.gd` 的购买路径。

`FACT`：出售退款只读取当前品质，不读取实际支付价格或折扣：`core/state/game_state.gd` 与 `core/party/quality_rules.gd`。

`FACT`：当前获得记录没有 `paid_cost` 或 acquisition lot。

`FACT`：存在支付 1 金币设置 50% 折扣的正式事件：`core/run/events/legacy_run_event_catalog.gd`。

`INFERENCE`：50% 折扣后，青铜/白银/黄金/钻石折后买价为 1/2/3/4，品质退款为 2/4/6/8。若忽略折扣事件成本，单件毛收益为 +1/+2/+3/+4；计入一次 1 金币事件成本后，白银及以上仍为正收益。

`NOT YET RUN`：本轮没有执行“触发折扣 → 生成商品 → BUY_OFFER → SELL_UNIT”的完整命令链。因此正式表述为：高置信代码级套利，尚无端到端运行证据。

建议后续专门建立只读/隔离复现任务；在复现和退款政策裁决前，经济型宠物保持红色讨论状态。

## 第 6 轮：来源修复门与支撑系统扩展

### 本轮范围

- 来源修复：`Flying Fish`、`Marlon`、`Jetbike`、`Pontoon Skimmer`。
- 改名兼容：`Flame Signal`、`Hate Leech`、`Silencer`。
- 新增一条并行讨论轨：为 139 宠机制识别需要补充的通用代码模块，以及战斗之外的配套策划系统。
- 本轮仍是只读策划审计，不修改正式数值、运行时代码、上游 workbook、CSV 或生成快照。

### 代码模块轨的初步边界

`FACT`：当前技能由 `PlayerTurnService -> PlayerTurnPort -> SkillExecutionService -> EffectInterpreter -> SkillEffectPort` 执行；效果处理器采用白名单插件发现，适合扩充通用能力，不适合为 139 只宠物各写一条散落特例。

`FACT`：当前冷却记录在单位的 `skill_cooldowns`，技能发动后由 `SkillEffectPort.start_skill_cooldown()` 写入；回合开始由 `RoundLifecyclePort.tick_skill_cooldowns()` 统一减 1。尚未看到独立的“催动/阻滞剩余冷却”服务。

`FACT`：当前 `strike_count` 只重复物理打击，`application_count` 只重复元素施加；`SkillExecutionService` 只按一次 effects 列表执行，尚无可重复完整复合效果包的事务封装。

`FACT`：通用效果目标通过 `core/effects/targets/` 插件解析；现有相邻实现散落在品质溅射、召唤找空格和部分机制中，尚无同时表达锚点、方向域、阵营、单位类型、选择规则与锁定时点的统一关系解析器。

`FACT`：伤害死亡已有集中安全点 `DamageDeathService`；非死亡退场、驱散召唤物、拆墙、消散和变形不能复用击杀事件，需要单独生命周期协议。

`FACT`：当前获得记录只有来源、日期、节点、阶段和状态版本；购买扣除折后 `offer.price`，出售却只按当前品质退款。获得批次尚未保存 `paid_cost`、折扣、获得方式和合并贡献。

下面的正式模块优先级、最小接口和验收门禁，等三组本轮交叉审阅后追加。

### 来源基线纠错

`REJECTED`：第 1～5 轮“BazaarWinner 当前 139 = 凡妮莎当前 139 个原生物品”的判断。

纠错证据：

- BazaarWinner 在 2026-08-17 显示 Vanessa `139 / 139`，但它的 Pontoon 页面标记为推断数据，不能证明英雄归属。
- BazaarDB 17.2（2026-08-13）把 Pontoon Skimmer 明确标成 Pygmalien、Silver、Large、Vehicle/Aquatic。
- BazaarDB 17.2 历史记录显示 `Flame Signal -> Bonfire`、`Hate Leech -> Bilge Worm`、`Silencer -> Suppressor`；方向与前几轮写反。
- Hate Leech 到 Bilge Worm 不只是改名，还同时从 Poison/Crit 自毒循环重做为 Weapon/Aquatic、监听敌方最左物品、伤害与吸血循环。
- 项目当前 138 行使用 Bonfire、Bilge Worm、Suppressor，与 17.2 的现行名一致。

因此本任务的有效范围暂改为：

- `138` 个 Vanessa 原生来源对象：继续逐项讨论。
- `1` 个跨英雄灵感候选 Pontoon Skimmer：保留第 139 个策划席位，但状态为 `SOURCE_SCOPE_CONFLICT_STOP`。
- 若主策最终坚持“139 个都必须来自 Vanessa 原生”，必须另找真实的第 139 个来源；不得用牌组出现推断英雄归属。
- 若主策允许“138 原生 + 1 跨英雄客串”，Pontoon 必须显式保存 `source_owner=Pygmalien` 与 `local_collection=Vanessa_inspiration`。

### 七对象来源修复裁决

| 对象 | 有效来源裁决 | 身份方向 | 机制状态 |
|---|---|---|---|
| Flying Fish / `pal_049` | 当前仍为 Vanessa、Bronze、Small、Aquatic/Friend/Weapon；旧项目快照的 Flying 循环可用 | 由铁臂黑猿改为小型飞鱼候选；锁定巨大胸鳍与跃浪轮廓，避开鳐类 | 可做草案，红色；缺 Flying、跨宠事件、冷却推进与精确相邻 |
| Marlon / `pal_075` | 当前仍为 Vanessa、Bronze、Medium；伤害、令对象 Flying、使用 Flying 对象后本战暴击成长 | 由赤刃螳螂改为枪鱼/马林鱼候选；以背帆、鱼身、吻枪区别 Narwhal/Harpoon | 可做草案，红色；需 Flying 事件、确定性目标与战内成长上限 |
| Jetbike / `pal_064` | 当前仍为 Vanessa、Silver、Large、Weapon/Vehicle；相邻联动 Flying、其他 Flying 对象使用后 Charge | 花螭底型可重做为喷射海龙/鳍骑；突出单骑、前冲、双喷口 | 只进接口草案，红色；同时依赖相邻、Flying、Charge 三个公共语义 |
| Pontoon Skimmer / draft | 当前 17.2 属 Pygmalien，不是 Vanessa | 跨英雄客串候选“浮潮翼鳐”或“双舟滑獭”；后者更不易撞 IllusoRay/Sharkray | `SOURCE_SCOPE_CONFLICT_STOP`；不进入正式 Vanessa 行，不占 `pal_139` |
| Bonfire / `pal_014` | 现行名 Bonfire；Flame Signal 是旧名。旧项目机制与当前核心循环相符 | 狸类可改为背负信号火盆的“烽火狸”；与 Lighter/火山区分 | 可做历史一致草案，红色；先裁决 Burn 本地语义与外层触发次数 |
| Bilge Worm / `pal_009` | 现行名 Bilge Worm；Hate Leech 是中间历史形态，且机制已重做 | 由火角鹿改为舱底蛭/船蛆式水生环节动物；突出吸盘、锈甲 | 可做草案，黄色；沿用敌方最左外层技能事务触发，不得换成 Hate Leech 自毒暴击循环 |
| Suppressor / `pal_119` | 现行名 Suppressor；Silencer 是旧名。核心仍是左侧对象伤害与唯一 Weapon 冷却 | 狐姬底型可改为吸音尾环和枪口套筒；避开准镜/HUD/刺刀轮廓 | 可做草案，黄色；缺标签查询、精确左邻与来源追踪的技能值光环 |

三个来源组在本轮留下的分歧与最终处理：

- 数值组最初仅把三个改名效果视作“中置信历史参考”；身份组与当前 17.2 历史记录进一步确认，本地旧名才是现行名，故采用后者。
- 战斗组曾把 Hate Leech 的自毒暴击循环当作现行对象。`REJECTED`：该循环属于 12.0 的中间阶段；正式候选继续采用 Bilge Worm 的敌方最左位触发伤害与吸血。
- 三组一致反对把 Flying 当“风元素”；它是独立战斗关键词。
- 三组一致认为 Pontoon 的机制资料已足够，但英雄归属不合格；来源范围冲突优先于机制设计。

### 通用代码模块路线图

所有模块都必须留在 `GameSession -> Command -> YsbzsState -> Result/Trace/Snapshot` 权威链内。内容只声明 ID 和参数；UI 只渲染权威结果；禁止物品或宠物脚本直接互调。

#### P0：先于全量技能数据的基础契约

| 模块 | 责任与最小接口 | 当前缺口 | 验收门禁 |
|---|---|---|---|
| `SourceFactRegistry + ContentDecisionSchema` | 分开保存 `source_* / historical_* / translation_* / local_* / validation_*`；稳定 ID、别名、来源英雄、补丁与置信度 | 当前混合清单把旧名和跨英雄牌组推断当现行事实 | 138 原生 ID 唯一；第 139 候选显式跨英雄；新旧名都可追溯；低置信行 fail closed |
| `CombatEventLedger + ReactionScheduler` | `publish(event)->event_id`、`enqueue(reaction)`、`drain(safe_point)`；事件带回合、阵营、来源单位、技能、目标、效果包、标签与父事务 | 现有钩子围绕当前单位收集，缺跨宠统一事件与反应深度协议 | 同一事件只消费一次；固定顺序；反应次数/深度封顶；回放 stateHash 一致 |
| `CombatRelationPolicy` | `resolve(snapshot, anchor, domain, directions, filters, selection_policy)`；区分编队邻、技能条邻、棋盘邻、命中目标邻和锁定时点 | 相邻逻辑散落在品质溅射、召唤找空格和机制 handler | 队首/队尾、死亡、移动、双邻选择、快照/动态关系均有确定性测试 |
| `CombatTagQueryService` | `has_tag`、`count`、`filter`；scope 明确宠物、技能、正式四宠、召唤物和存活策略 | Weapon/Aquatic/Vehicle 等目前主要是内容元数据，技能侧缺查询契约 | “恰好一个 Weapon”、死亡重算、召唤物排除、Snapshot 与权威一致 |
| `SkillCooldownService` | 冷却唯一写入口：`is_ready/start/advance/delay/tick_round/remaining` | `SkillEffectPort` 写入、`RoundLifecyclePort` 递减，尚无当前冷却推进/阻滞服务 | 0 下限、延迟上限、同 tick 多次变化、未冷却时 Charge 规则、回合 tick 顺序 |
| `EffectPacketRepeatService` | `execute_packet(context,effects,repeat_total,snapshot_policy,death_policy)`；Multicast 重复完整效果包 | 现有 `strike_count` 与 `application_count` 只能分别重复伤害或元素，effects 列表只执行一次 | 纯伤害、纯铺层、复合包；包间死亡安全点；整次发动只启动一次冷却 |
| `SkillResourceService` | 单场弹药账本：`initialize/can_spend/spend/reload/current/max` | 没有正式 Ammo；不能借 AP、宠物重置次数或遗物 charges | 0 弹药禁用、连发耗弹规则、溢出装填、战斗初始化、存读档与回撤一致 |

#### P1：首批代表宠物所需的可复用能力

| 模块 | 责任与最小接口 | 服务对象 | 验收门禁 |
|---|---|---|---|
| `BattleKeywordStateService` | `change(unit,keyword,enabled,reason)`、`has()`，并发布一次 `KEYWORD_CHANGED` | Flying Fish、Marlon、Jetbike；若批准跨英雄则含 Pontoon | 重复 start 不重复触发；start/stop 各一次；死亡/重置/战斗结束清理；不自动等同移动或风元素 |
| `ScopedModifierLinkService` | `attach(source,target,modifier,acquire_policy,retain_policy)`、`invalidate(reason)` | Star Chart、Bayonet、Suppressor 等位置依赖光环 | 来源死亡、移动、换位、回合冻结、读档恢复均不残留孤儿增益 |
| `SkillValueModifierService` | 按技能、效果选择器和字段修改 Damage/Cooldown 等值，不改宠物基础 ATK | Suppressor 只增目标技能伤害，避免误增治疗/召唤 | A/B 技能可区分；只改白名单效果；来源失效准确回滚 |
| `MechanismRuntimeStateService` | `get/increment/capped/clear(scope,key)`；统一每轮一次、前 N 次、本战成长 | Bayonet 反应上限、Marlon 暴击成长、各种成长/首次触发 | round/battle/run scope 分明；死亡重生和读档不重发；Snapshot 可解释 |
| `PeriodicEffectService` | `apply/tick/remove/stacks`；Poison/Burn/Regen 都经 DamageResolver/治疗权威路径 | 若采用持续灼烧、自毒等设计 | 明确回合时点、护盾防御、死亡安全点；火元素铺层不自动等于 Burn |
| `UnitExitService` | `request_exit(unit,reason,source,hook_policy)->ExitResult`；区分退场、驱散、拆除、消散、变形 | Dam、Harpoon、Powder Keg 等 Destroy 转译 | 不直接 `units.erase`；非死亡不触发击杀奖励；正确释放格位并写 Trace/Snapshot |

#### P2：独立纵切与制作工具

| 模块 | 责任 | 验收门禁 |
|---|---|---|
| `HealthRatioDamageEffect` | 百分比生命伤害计算后统一进入 DamageResolver | 普通怪/Boss/队长上限、护盾/防御/暴击、预览与实战一致 |
| `PlanningWorkbookExporter` | 从来源事实与本地决策生成工作簿，不反向成为运行时真相源 | 139 策划席位、138 原生、跨英雄候选、别名、公式错误和空字段自动检查 |
| `DeterministicBalanceHarness` | 固定种子跑单回合峰值、5 回合累计、12 回合上限、镜像先后手和连锁深度 | 同配置可复现；输出 Command/Result/Trace/Snapshot；禁止只报均值 |
| `MechanicPreviewProjector` | 给 AI、策划预览与 UI 提供与实战同源的目标域、冷却、弹药、Flying 和来源光环投影 | 预览与正式结算逐字段一致，不能各算一套 |

明确反对的实现捷径：

- 用速度状态代替当前冷却推进/阻滞。
- 用扩大形状代替 Multicast。
- 用宠物 ATK 增加代替 Suppressor 的定向技能伤害。
- 用 AP、重置次数或遗物 charges 冒充 Ammo。
- 用直接删除单位冒充非死亡退场。
- 先给每只宠物写专属 handler，再事后抽公共规则。

### 其他配套策划系统路线图

| 优先级 | 系统 | 正式产出与门禁 |
|---|---|---|
| P0 | 来源、ID、别名与版本 | 138 原生来源全覆盖；第 139 位明确跨英雄或替换来源；3 个过期名可搜索但不覆盖现行名 |
| P0 | 本地品质与成长 | `source_tier` 与 `local_start_quality` 分列；0/2/5/9 进化点的每次质变独立设计；单场/Run/永久成长分离且封顶 |
| P0 | 获取日、货池与重复保护 | 每宠至少一条合法获取路径；无不可达宠；权重、保底、重复保护和品质分布通过抽样 |
| P0 | 购买、出售、复制、合成 | 引入 `acquisition_lots`，记录实际支付成本、折扣、免费/复制/奖励来源与合并贡献；所有套利环路先验证 |
| P0 | 标签与协同词典 | 元素、职责、物种、Weapon、Aquatic、Vehicle、Flying 等分层；风与 Flying 不冒充正式元素；召唤物计数规则明确 |
| P0 | 存档、回撤与迁移 | 旧 138 ID 不重映射；新增席位不占 `pal_139`；成长、弹药、lot、图鉴和别名带 schema 版本迁移 |
| P0 | 内容状态与审批 | 每行 `draft/reviewed/approved/blocked`、责任组、反对意见、批准版本；低置信与红色机制不能导出正式数据 |
| P1 | 身份与美术圣经 | 中文名、物种、性格、轮廓、色系、装备意象、VFX、禁撞对象；139 个轮廓键与资产键唯一 |
| P1 | 图鉴与收藏 | 未见/已见/已拥有/已进化；新旧名搜索同一条；来源英雄与历史版本说明；未发现内容不泄露 |
| P1 | 玩家文本与本地化 | 禁止裸 Adjacent/Multicast/Destroy/Flying；短描述与详细说明引用同一机制词典，目标、时点、上限一致 |
| P1 | AI 与敌方使用规则 | AI 使用与玩家相同目标域、资源、冷却和触发协议；不会利用隐藏信息或走专属捷径 |
| P1 | 可视反馈规范 | 相邻连线、来源光环、飞行/落地、催动/阻滞、弹药、连发包和非死亡退场都有稳定且不误导的表现 |
| P0 | QA 与上线门禁 | 逐行完整性、标签/池可达性、经济环路、固定种子 1/5/12 回合、镜像先后手、存档/回撤、真实界面验收 |

推荐实施顺序：先修来源/ID/别名与标签契约；再建事件调度、关系解析、冷却、效果包和弹药；随后做 Flying/来源光环/运行时计数；最后才批量写 138+1 的正式机制、品质、池与数值。

## 第 7 轮：海兽伙伴批次 A 独立提案

本批对象：Calico、Catfish、Darkwater Anglerfish、Electric Eels、IllusoRay、Jellyfish、Mantis Shrimp、Mr. Richardson。来源口径使用 17.2；本轮不写正式数值。

### 身份组独立提案

| 来源 | 现有映射 | 身份候选 | 初判 |
|---|---|---|---|
| Calico | `pal_016 涧水象` | 三花火枪手 / 花斑船猫；三花毛色、猫耳粗尾、低姿拔枪 | 重做；可借猫科骨架，不能保留象体型 |
| Catfish | `pal_023 墨潭鲵` | 毒须鲶 / 翡翠毒须；宽嘴、长须、腹部毒囊 | 候选接收 `pal_043 泥甲巨鲶` 底稿 |
| Darkwater Anglerfish | `pal_036 云纹巨驼` | 幽灯鮟鱇 / 渊焰灯鱼；冷绿诱饵灯与暖色口焰 | 完全重做 |
| Electric Eels | `pal_043 泥甲巨鲶` | 雷索鳗群 / 三环电鳗；三条以上鳗体缠成活结 | 候选接收 `pal_023` 长体底稿后重做；一个多身体单位，不占多个格 |
| IllusoRay | `pal_059 冰角白鹿` | 幻潮鳐 / 镜海幻鳐；透明投影与错位残影 | 完全重做；独占幻象鳐语言，Pontoon 避免鳐型 |
| Jellyfish | `pal_063 蜃雾白鹿` | 彩裙水母 / 毒舞海蜇；钟形伞盖、垂直触须、彩裙毒囊 | 完全重做 |
| Mantis Shrimp | `pal_074 霜翼冥龙` | 虹甲拳虾 / 爆拳螳虾；虹彩分节甲、棒状捕捉肢、空化爆闪 | 候选接收 `pal_075 赤刃螳螂` 底稿并水生化；Marlon 另做枪鱼 |
| Mr. Richardson | `pal_076 迅雷金雕` | 理查森先生 / 缆索绅猴；具名小型海盗猴、卷尾、船索、防护结构 | 具名角色重做；Aquatic 是玩法标签，不强制水生物种 |

身份组要求补充的独立字段：`proper_name`、`species_anchor`、`body_count`、`silhouette_key`、`material_language`、`signature_prop`、`animation_verbs`、`do_not_overlap`。来源标签、身份标签、战斗标签、美术标签必须分开。

### 战斗组独立提案

战斗组提出一个有争议的结构原则：本批 8 项先只保留一个主动 A，B 留空。理由是来源物品只有一次主动冷却，强拆 A/B 会把一次完整使用变成两次独立机会，扭曲冷却、成长、Ammo 和敌方反应频率。此原则仍需交叉复审，尚非全局定案。

| 来源 | A 技能草案 | 被动循环 | 依赖与风险 |
|---|---|---|---|
| Calico | 单格远射/窄直线物理攻击，技能带 Weapon 标签 | 其他宠物的 Weapon 技能成功提交后，本战暴击成长；自身不喂自己 | 事件、技能标签、本战计数；🟢候选 |
| Catfish | 单格/窄短直线施加 Poison | 自身 A 的剩余冷却被实际催动后，A 的 Poison 字段本战成长；冷却为 0 时不算 | 冷却、持续伤害、技能值成长；🟡 |
| Darkwater Anglerfish | 窄扇/短直线施加 Burn | 任意己方技能成功阻滞敌方技能后催动自身 A | Slow 事务、冷却、Burn 定义；🟡偏🔴 |
| Electric Eels | 直线/短链形，完整包同时伤害与阻滞 | 每个敌方技能成功提交后催动 A；连发包不额外计 | 事件、冷却、完整包；阻滞目标技能选择未定；🔴 |
| IllusoRay | 长直线/单格阻滞；额外连发重复完整 Slow 包 | 回合开始读取编队左右 Friend/Ray 邻居，来源/邻居移动死亡后失效，新邻居下回合生效 | 关系、标签、冷却、整包连发；目标去重未定；🔴 |
| Jellyfish | 单格/集中形状施加 Poison | 编队相邻 Aquatic 宠物完成技能后催动自身 A；每项技能一次 | 事件、关系、标签、冷却、Poison；🟡 |
| Mantis Shrimp | 先原子扣 Ammo，再按顺序结算伤害+Burn；失败则整包不发生 | 己方成功阻滞后，A 的伤害与 Burn 字段共同成长；同一 Slow 包一次 | 事件、弹药、持续伤害、技能值成长；🔴 |
| Mr. Richardson | 自身获得护盾 | 己方实际催动或阻滞成功后，A 护盾字段本战成长；一次操作只成长一次 | 事件、冷却、技能值成长；“玩家护盾”映射仍待裁决；🟡 |

### 数值组独立审计

`HIGH RISK`：本批最大的危险不是单宠，而是 Slow 生产者—消费者网络：IllusoRay、Electric Eels 生产 Slow；Darkwater Anglerfish 消费 Slow 获得冷却推进；Mantis Shrimp 消费 Slow 获得伤害+Burn 双成长；Mr. Richardson 同时消费 Slow/Haste 获得护盾成长。

若一次多目标、三段或 Multicast 的 Slow 分别广播事件，一个外层技能就会产生乘法收益。因此数值组提出：

- 默认只监听一次“成功提交的外层状态事务”，不监听动画段、命中段、每个目标或每个连发子包。
- 若个别宠明确需要逐目标触发，必须单独标红并另给预算。
- 冷却下限、单回合额外发动上限、状态成长上限和单回合触发预算必须同时存在。
- Poison/Burn 的 1/5/12 回合预算必须在结算时点、叠层、净化与死亡残留明确后再算。
- Mantis Shrimp 只有在单场 Ammo 严格耗尽且无自然回填时长局会自行停机；任何装填、复制、复活补弹或重置补弹都会把它升为深红。
- 8 项均可进入无数值事件骨架；Electric Eels、IllusoRay、Mantis Shrimp 保持深红，其他项也不能直接成为可玩定案。

### 本批新增系统缺口

- 不可变来源快照：URL、抓取日、补丁号、数据源、字段哈希与冲突仲裁。
- Crit 权威规则：整次技能还是逐段判定、暴击倍率叠加、期望值与高分位峰值。
- Haste/Slow/Charge 权威事件词典：外层事务、每目标包、无效施加和状态刷新各自是否触发。
- 全宠协同图与循环检测：按 Slow、Haste、Weapon、Aquatic、Adjacent 建生产者—消费者图，自动找同事务递归。
- 多身体单宠身份规则：Electric Eels 是一个战斗单位和一个格，不产生额外目标、AP 或召唤物。

### 交叉复审前未决项

1. 8 项只有一个主动 A，是正式结构还是事件骨架阶段的临时约束。
2. IllusoRay、Jellyfish 采用编队左右、棋盘正交还是共享技能条邻接。
3. Slow/Haste 默认“一次外层状态事务一次”是否损失多目标构筑价值。
4. Mr. Richardson 的玩家护盾翻译成自身盾、队长盾还是其他可见防护。
5. Catfish 与 Electric Eels、Mantis Shrimp 与 Marlon 的美术底稿交换，是否让交换另一端真正改善。

### 第 7 轮交叉复审裁决

#### 主动技能结构

`DECISION`：本批正式允许 `skills=[A]`、B 不存在；不是全项目强制单技能。来源只有一个主动冷却循环时，不为填 UI 凭空创造 B，也不把被动伪装成 B。

代码边界：非空的单元素 `skills` 可原样进入共享技能条；空 `skills=[]` 会触发兼容普攻补位。因此正式 schema 必须区分：一技能宠、双技能宠、数据缺失。数据缺失必须校验失败，不能静默生成隐藏普攻。

数值门禁：一个主动按钮不代表同额预算。每宠统一核算 `主动 + 被动 + 免费触发 + 成长`；Large 来源失去原作槽位成本后，至少要从主动成本、触发限制、获取位置或阵容唯一性中承担一项机会成本。

#### 状态事务与防递归

`DECISION`：多目标价值保留，但本批成长消费者默认按一次根行动消费一次，而不是按目标、伤害段或连发包计数。

事件至少分四层：

| 层级 | 含义 |
|---|---|
| `root_action_id` | 一次玩家或自动技能使用 |
| `packet_id` | 一次完整效果包；Multicast 每包一个 |
| `operation_id` | 包中的一次 Haste/Slow 等语义操作 |
| `application_id` | 对具体目标技能冷却的实际修改 |

一个 Electric Eels 技能可以真实阻滞三个目标并保存三条 application；但 Darkwater、Mantis、Richardson 默认各按 `root_action_id` 消费一次。默认去重键为 `(root_action_id, consumer_unit_id, consumer_rule_id)`。

共同硬规则：

- `SKILL_COMMITTED` 只在整个技能、死亡安全点与冷却启动后发布一次；Multicast 子包只发布 `PACKET_RESOLVED`。
- Haste/Slow 先经过抗性、冷却下限与钳制；实际差值为 0 时不产生成功事件。
- Charge、自然回合冷却和重置不是 Haste；禁止借同名事件喂 Catfish/其他 Haste 消费者。
- 同一 `consumer_rule_id` 已在 `cause_chain` 中时禁止重新进入；每个根行动另设总派生事件预算与硬深度上限，超限写入 Trace。
- 目标在提交前死亡、退场或技能移除，application 失败且不自动换目标；反应拥有者死亡时取消尚未执行的反应并留 Trace。

#### 相邻政策

`DECISION`：所有相邻共用 `CombatRelationPolicy` 解析器，但不同物品不强制共用同一域。

- Bayonet：`formation_order_left`。绑定编队左侧宠物，不受棋盘临时移动影响，表达稳定的附件所有权。
- Star Chart、IllusoRay、Jellyfish：`board_horizontal_round_snapshot`。回合开始以棋盘格为锚，建立同行左/右 1 格的可见链接；原对象移动、死亡或退场后立即断开；本回合新移入者不补入，下回合重建。
- 共享技能条左右不再用作空间光环；技能重排不得改变 Star Chart/IllusoRay/Jellyfish 的受益者。

这也解决了前一轮 Bayonet/Star Chart 的主要争议：它们不是二选一的“全局相邻定义”，而是两种显式命名的关系域。

#### 身份交换链复审

`REJECTED`：Catfish 与 Electric Eels 正式交换 `pet_id`。`pal_023` 继续对应 Catfish 并重做“毒须鲶”；`pal_043` 继续对应 Electric Eels 并重做“雷索鳗群”。泥甲巨鲶只能作为概念参考，不能携带旧品质、池、形状或机制跨行迁移。

`REJECTED`：Mantis Shrimp 与 Marlon 正式交换 `pet_id`。`pal_074` 继续对应 Mantis Shrimp 并重做“虹甲拳虾”；`pal_075` 继续对应 Marlon 并重做“枪吻马龙”。赤刃螳螂的前肢动画只能登记为 `art_base_reference`。

底稿复用只允许借轮廓、骨架或局部动画；禁止继承名称、元素、职责、形状、攻击范围、技能、机制、数值、品质与货池。

#### 八项阶段裁决

| pet_id | 身份方向 | 机制骨架 | 风险与状态 |
|---|---|---|---|
| `pal_016` | 三花火枪手 | A 攻击；其他带 Weapon 技能标签的友军技能提交后，本战暴击成长 | 黄；需 Crit 粒度与事件层 |
| `pal_023` | 毒须鲶 | A 施毒；自身 A 被实际 Haste 后，后续 Poison 字段成长 | 红；需持续伤害、冷却推进与成长上限 |
| `pal_036` | 幽灯鮟鱇 | A 灼烧；己方一次 Slow 根行动成功后 Charge 自身 A | 红；需 Burn 与 Slow/Charge 严格分义 |
| `pal_043` | 雷索鳗群 | A 伤害+阻滞；每个敌方技能正式提交后 Charge 自身 A | 红；多身体仍为一个单位、一个格、一份生命和一次事务 |
| `pal_059` | 幻潮鳐 | A Slow；回合开始的有效左右 Friend/Ray 链接决定本次整包连发 | 条件黄；只限左右、回合建链、断链即失效、连发不复制被动 |
| `pal_063` | 彩裙水母 | A 施毒；已链接 Aquatic 邻居提交主动后 Haste 自身 A | 红；需关系、标签、冷却与 Poison |
| `pal_074` | 虹甲拳虾 | 原子扣 Ammo 后结算伤害+Burn；己方 Slow 根行动使二者共同成长 | 红；无自然装填、无复活补弹只是正确性底线，不自动降风险 |
| `pal_076` | 理查森先生 | A 仅给自身盾；己方 Haste/Slow 根行动使护盾字段成长 | 黄；Haste+Slow 同一根行动合并消费一次 |

玩家可见要求：Weapon/Friend/Aquatic/Ray 必须出现在技能卡或图鉴；Calico 显示精准成长层数，IllusoRay/Jellyfish 显示左右连接线与有效链接数，Electric Eels 使用一个选中环和一条血条，Richardson 的盾只显示在自身。

#### 代表纵切与实施顺序

数值组建议首个代表纵切为 `IllusoRay + Mantis Shrimp`，覆盖关系快照、整包连发、Slow 成功事件、成长、Weapon 标签、Ammo 原子扣除和伤害+Burn 事务；战斗组认为可先独立实现 Calico/ Richardson 的基础 A，但它们的被动仍必须等事件层。

`DECISION`：策划验证顺序采用二者结合：

1. 先建立事件信封、事务 ID、确定性反应队列与去重。
2. 做冷却推进/阻滞，区分 Haste、Slow、Charge。
3. 做统一关系解析器与回合快照。
4. 用 IllusoRay 验证整包 Multicast 与关系断链。
5. 做战斗内技能参数成长与 Ammo，用 Mantis Shrimp 验证原子扣弹与双字段成长。
6. 再补持续伤害，接 Catfish/Jellyfish/Darkwater。
7. 最后补 Flying，再接 Marlon/Flying Fish/Jetbike。

本批尚未填任何正式数值；八项都只是有审计轨迹的事件骨架。

## 第 8 轮：海兽伙伴批次 B 独立提案

本批对象：Narwhal、Old Saltclaw、Orange Julian、Pesky Pete、Pet Rock、Piranha、Pufferfish、Seashadow。17.2 核对后，8 项仍都只有一个独立主动冷却循环，因此均为一个正式 A 加被动/光环，B 不存在。

### 身份组提案

| pet_id | 身份方向 | 关键身份字段与防撞 | 裁决 |
|---|---|---|---|
| `pal_078` | 赤角独鲸 | 独角鲸长牙是身体结构，不手持鱼叉；避开 Harpoon/Javelin | 重做 |
| `pal_080` | 老盐钳 / 盐钳老船长 | `proper_name=true`；蓝色老蟹、三角帽、胡须、巨钳；避开冰雪 Yeti Crab | 保留专名后重做 |
| `pal_082` | 橘利安 / 橘利安账房 | `proper_name=true`；橙毛猩猩、眼镜、账簿、金币；文职账房而非重型猿 | 保留专名后重做 |
| `pal_084` | 鹦鹉皮特 | `proper_name=true`；红鹦鹉、护目镜、点火器；顽皮海盗而非凤凰 | 保留 Pete 后重做 |
| `pal_085` | 宠物石 | `lifeform_kind=animated_object`、`sentience=true`；小型有脸卵石，不长四肢、不变石巨人 | 按宠物认知处理，但不伪装生物 |
| `pal_087` | 赤牙鱼群 / 饥潮食人鲳 | `body_count=multiple`；前景领鱼加鱼群，一个战斗单位；避开电鳗活结 | 重做为多身体单宠 |
| `pal_093` | 鼓毒河豚 | 圆体、可收放尖刺、红蓝毒囊；避开 Beach Ball 与 Pet Rock | 重做 |
| `pal_102` | 海影宝驹，专名“海影” | `proper_name=true`；黑色海上战马、鞍辔、踏浪；不是鱼类海马，不加鹿角 | 保留专名后重做 |

身份组反对任何正式 `pal_id` 交换；旧素材只登记 `art_base_reference`。Pet Rock 继续属于玩家认知的伙伴类，因为来源明确带 Friend，但图鉴要把“动画物件生命”讲清。

### 战斗与数值联合风险表

| 对象 | 机制骨架 | 关键规则 | 风险 |
|---|---|---|---|
| Narwhal | A 高频窄形状伤害，无额外被动 | 一次 A 一个 Weapon-use；短秒数只转为高频档，不机械换回合 | 黄，可作为事件管线基准 |
| Old Saltclaw | A 短扇/爪击；全队成功 Haste/Slow 后提高 A 本战伤害 | 同根 Haste+Slow 合并一次；不按目标成长；共享上限 | 黄偏红 |
| Orange Julian | A 冻结 Run 累计获得金币指标，为合法己方伤害技能附加本战伤害 | 不读取当前余额；局外指标与单场增益双账本；当前公开文案“所有物品”与 Deep Mechanics 的 Weapon 筛选冲突 | 红，`SOURCE_DATA_CONFLICT` |
| Pesky Pete | 战斗开始 Flying；A Burn；同行左右 Friend/Property 链接决定整包 Multicast | 复用空间横向回合建链；最多两邻；飞行先于首轮快照；包数在 A 开始冻结 | 红 |
| Pet Rock | A 小落点伤害；若战斗锁定阵容中只有自己带 Friend，给全队可暴击技能光环 | 只在 `formal_roster_at_battle_start` 判定；队友死亡不补开；Pet Rock 退场立即解除 | 黄 |
| Piranha | A 短距群食伤害；其他 Friend 或 Food 标签宠提交技能后 Charge A | 全队域而非相邻；双标签同根只触发一次；多身体仍是一次技能事务 | 黄 |
| Pufferfish | A 小范围 Poison；己方成功 Haste 后 Charge A | 每根行动一次；Charge 不发布 Haste；自然冷却、重置、冷却率光环都不算 | 红 |
| Seashadow | A 原子地降低其他三宠后续基础冷却，同时增加自身 A 后续基础冷却 | 不回改当前剩余冷却；自身本次结束启动冷却即读取新基值；任一侧失败则整包不落 | 红 |

### 两批合并后的协同网

- Weapon 外层 A 喂 Calico；Orange Julian 再全局放大伤害技能，Seashadow 提高后续发动频率。
- IllusoRay/Electric Eels 生产 Slow，同时喂 Darkwater Charge、Mantis 双成长、Richardson 自身盾、Old Saltclaw 伤害成长。
- 相邻 Aquatic 主动喂 Jellyfish Haste；该 Haste 又喂 Pufferfish Charge、Richardson 与 Saltclaw 成长。
- Pet Rock 的唯一 Friend 光环与 Calico/Piranha 暴击/武器高峰叠加，必须统一 Crit 粒度和光环修饰顺序。
- Orange Julian 的 Gold 指标若误把出售退款、复制补偿、撤销或读档恢复计为新收入，会把现有经济套利扩散成永久战斗成长。

### 本批新增公共缺口

1. `SupportSkillExecutionPolicy`：支持技能不应被迫取得攻击 option。当前 `SkillEffectPort.begin_skill()` 在无攻击 option 时会失败；正式方案需要无攻击形状/支持目标路径，不能伪造空攻击目标。
2. `RunMetricSnapshotService`：提供带来源分类、Run ID 和幂等记录的累计获得金币指标，不能从 UI 或当前余额反推。
3. `ScopedSkillModifierService`：统一 Pet Rock 暴击光环、Orange Julian 伤害增益与 Seashadow 冷却修改的目标、层级、来源失效和清除。
4. 冷却双模型：严格分开当前剩余冷却推进与后续基础/本场冷却时长修改；二者发布不同事件。
5. 条件光环求值器：锁定阵容、标签计数、候补/召唤/英雄排除与中途失效。
6. Gold 事件分类：奖励、出售、退款、复制补偿、撤销和读档恢复必须有不同 acquisition/economy kind。

本批阶段结论：Narwhal、Piranha 可直接进入无数值骨架；Old Saltclaw、Pesky Pete、Pet Rock、Pufferfish、Seashadow 进入带门禁骨架；Orange Julian 只进入来源冲突与双账本骨架。

### 第 8 轮交叉复审裁决

#### 无攻击支持技能

`DECISION`：新增显式 `execution_mode=support`，缺省仍是 `shape_attack`。支持技能不调用攻击方向、敌方 option、攻击形状品质链，也不伪造空攻击目标；它仍保留共享技能条顺序、技能可用性、冷却、前后钩子和 Result/Trace/Snapshot。

支持上下文为 `option={kind:support}`、`cells=[]`，目标是预先冻结的友方单位/技能实例。内容校验禁止 support 携带物理伤害、形状命中元素铺层或依赖方向/cells 的效果。

当前执行链在效果失败后仍可能 finish 并启动冷却，整回合也不会因单技能失败自动回滚。因此 support 需要明确：prepare 失败不写 Trace/不启冷却；commit 失败执行 `abort_skill`，不保留部分状态。现有攻击路径暂不顺带重写。

#### Orange Julian

`BLOCKED`：17.2 顶部玩家文案为 all items，同页 Deep Mechanics 仍筛 Weapon；旧快照又表现为读取本 Run 累计金币的派生公式。只能确定“Run 内 Gold 成长 -> 橘利安增益能力 -> A 为多个伤害技能提供本战增益”这一不变量。

正式字段：`source_public_scope=all_items`、`source_deep_scope=weapon`、`source_conflict=TARGET_SCOPE_MISMATCH`、`resolved_target_scope=null`。未裁决时导出必须失败；运行时误入也必须 `CONTENT_DECISION_UNRESOLVED`，无目标、无增益、无冷却。

另外必须新增权威 `run_gold_earned_total`，进入 save/load、state hash、命令回滚、回撤和 Snapshot。禁止从当前余额反推；也暂不绑定正式 Gold 监听器或成长公式。“永久”最多指当前 Run 的当前实例，不是账号永久。

#### Pet Rock

`DECISION`：在 `BATTLE_ROSTER_LOCKED` 一次冻结资格，统计正式出战且带来源 Friend 的宠物，排除英雄、召唤、候补和临时复制。只有 Pet Rock 是唯一 Friend 才获得本战资格。

- 第二 Friend 后来死亡不补开；战中召唤 Friend 不撤销。
- Pet Rock 死亡/退场时链接立即失效；本战复活不重新挂接，下一场重算。
- 暴击增益通过来源—目标—技能实例 link 保存，不直写基础字段。
- 部署 UI 显示“独伴条件 1/1 或 2/1”及锁形角标，避免玩家把阵亡误解为开光环条件。

满足开战锁定、来源存活依赖、暴击按效果包判定、非 Friend 池确有机会成本后，Pet Rock 可由红降黄。

#### Seashadow

`DECISION`：团队后续冷却缩减与自身后续冷却增长必须是一个 `modifier_bundle`，使用通用 `apply_cooldown_modifier_batch(plan)` 两阶段提交，不能写成两个普通 effect handler。

- prepare 冻结其他正式宠物的 authored skill instance ID、来源与自身 A，计算 requested/effective 修饰但不写状态。
- commit 再核对所有实例，通过一次 authority assignment 替换完整 modifier ledger，成功后才写 application Trace 并启动自身冷却。
- commit 前来源死亡、A 被替换、任一目标技能消失、非法字段、重复 batch 或越界，整包失败：0 收益、0 代价、0 冷却、0 committed application。
- commit 后来源死亡，已写入的“本战后续冷却”收益与自身代价都保留；目标技能移除后不转给新技能。
- 其他技能当前 remaining 不变，下一次启动才读取缩减；Seashadow 本次启动冷却立即读取刚增长的新基值。
- 该事件是 `COOLDOWN_DURATION_MODIFIED`，不是 Haste/Slow/Charge，不喂任何 tempo 消费者。

原子化只堵套利，不代表数值安全；Seashadow 的五/十二回合团队乘法仍为红色。推荐用 `Seashadow + Narwhal` 做支持纵切，比较“现在攻击”与“现在支援、未来回本”；Pet Rock 另用 Friend/非 Friend 两组阵容夹具验证资格快照。

#### 最小测试组

- 旧攻击技能在 support 分流加入前后，固定种子 Snapshot、伤害、cells、Trace、stateHash 完全一致。
- support 无攻击 option 可合法执行；support 携带物理伤害或未知 selector 时 fail closed 且无冷却。
- Orange Julian 未裁决作用域时导出失败；当前余额相同但累计收入不同，未来批准后的增益只随累计收入变化。
- Pet Rock 初始第二 Friend 死亡后仍不启用；来源死亡后链接失效；回撤恢复资格、链接与 stateHash。
- Seashadow commit 前任一目标技能消失则整包回滚；commit 后来源死亡仍保留批次；多次施放 batch ID 唯一；回撤恢复 ledger、冷却、Trace 与 stateHash。

本轮 16 只海兽已有身份与事件骨架：8 项第 7 轮 + 8 项第 8 轮。尚未填写正式数值，也未修改运行时代码。

## 第 9 轮：海兽伙伴批次 C 与 24/24 阶段闭环

### 来源纠错

数值组曾因 BazaarWinner 的 Flying Fish/Marlon 空字段，把二者误判为当前机制缺失。`REJECTED`：站点缺失不等于物品机制缺失。有效优先级修正为：明确标注当前补丁的 BazaarDB 条目 > 未标补丁且可能缺字段的 BazaarWinner > 旧 CSV/旧补丁历史页。

Flying Fish 与 Marlon 均可进入红色无数值骨架，不再是灰色阻断。Flying 是独立战斗关键词，不是风元素。

### 八项身份与机制骨架

| pet_id | 身份裁决 | A / 被动骨架 | 关键门禁与风险 |
|---|---|---|---|
| `pal_049` | 翼潮飞鱼；单体飞鱼，巨型胸鳍与上升轨迹；远景小鱼仅 VFX | A 短距俯冲，令自身和一个有效左右邻宠 Flying；根行动开始已 Flying 的技能提交后 Haste 自身 A | 相邻两候选用种子随机；重复 Flying 幂等；本次才起飞不追认；深红 |
| `pal_075` | 枪吻马龙；`proper_name=true`；长吻翼鳍枪鱼 | A 长直线攻击并从全阵容选一个未 Flying 宠；Flying 技能提交后自身 A 暴击成长 | 目标可含自身、种子确定；本次起飞不追认；红 |
| `pal_106` | 鲨翼鳐；实体鲨口厚翼盘，区别透明 IllusoRay | A 浅扇/双翼伤害；成功 Haste Friend 后提交友军成长包 | 顶部 Friend 文案与 Deep Mechanics 的 Weapon/Poison 筛选冲突，`SOURCE_TARGET_SCOPE_CONFLICT`，未裁决 fail closed；红 |
| `pal_112` | 沉眠元祖；称号式唯一古代克拉肯，非个人专名 | A 长蓄力整包连发；Poison/Freeze/Burn 后成长并 Charge | 连发不扩形状；同根不同状态可分别成长，但 Charge 同根最多一次；深红终局件 |
| `pal_126` | 托尔图加；`proper_name=true`；背负舰体的赤色龙龟，Vehicle 是职责 | A 重型单路冲撞并 Haste 其他三宠 A；其他 Friend 技能提交后 Charge 自身 | 全队域而非相邻；无可 Haste 目标时伤害仍成功；深红 |
| `pal_131` | 血纱幽鱿；红黑斗篷状腕膜，不擅自加入来源没有的吸血主题 | A 单格物伤+Lifesteal；准备时读取有效 Crit，经独立尺度增伤 | 吸血只按实际 HP damage；现有伤害链可纵切，仅缺 Crit→Damage 修饰；黄偏绿 |
| `pal_137` | 冰髯雪怪蟹；低伏兽态冰蟹，区别直立老船长 Old Saltclaw | A 为无攻击 support，冻结一个敌方正式 A；Freeze 后让左右已链接 Poison A 本战成长 | 无有效目标则 prepare 失败、无 Trace/冷却；不伪造零伤害攻击；红 |
| `pal_138` | 灼鳍绵鳚；单条火纹 S 形鱼，区别多鳗电结 | A 短折线伤害并 Haste 左右邻宠 A；己方 Burn 后 Charge 自身 | 一个 Haste operation 最多两个 application；Burn 同根只 Charge 一次；深红 |

八项保持原 `pal_id`，全部重做物种；Marlon、Tortuga 保留专名。多身体宠仍只有 Electric Eels 与 Piranha。

### 海兽 24 只风险分层

| 层级 | 数量 | 对象 |
|---|---:|---|
| 深红 | 7 | Electric Eels、Pufferfish、Seashadow、Flying Fish、Slumbering Primordial、Tortuga、Zoarcid |
| 红 | 12 | Calico、Catfish、Darkwater Anglerfish、Jellyfish、Mantis Shrimp、Old Saltclaw、Orange Julian、Pesky Pete、Marlon、Sharkray、Vampire Squid、Yeti Crab |
| 条件黄 | 3 | IllusoRay、Mr. Richardson、Pet Rock |
| 黄 | 2 | Narwhal、Piranha |

战斗组认为 Vampire Squid 在现有 HP damage→Lifesteal 管线下可作黄偏绿技术纵切；此为“实现复杂度风险”判断，不覆盖数值组对暴击三重收益的红色“平衡风险”。工作簿必须把技术风险与平衡风险拆列。

### 同质化审计

- 7/24 是外部事件后 Charge 自身；9/24 是事件后本战技能字段成长；去重后 15/24 围绕这两类循环。
- 6/24 使用同行左右关系；Poison 主动 3 只、Burn 主动 3 只。
- 不能靠换名/换形状掩盖循环雷同：Catfish=单体深毒，Jellyfish=相邻水生联动，Pufferfish=小范围毒与 Haste 回转；Darkwater=Slow 带动 Burn，Mantis=Ammo 下伤害+Burn 双成长，Pete=Flying+邻接连发 Burn。
- Slumbering 必须保留长蓄力、多包终结、三状态唤醒，不能压成普通状态后 Charge。
- 当前海兽缺干净的团队治疗、净化、召唤、位移、地形、嘲讽及无被动状态对照件；不得硬改海兽填坑，应从其余 115 项找来源匹配对象，或建立不进内容池的 benchmark fixture。

### 代表验证阵容

1. Narwhal + Piranha：验证单包伤害、Weapon-use 与 Crit 粒度。
2. Seashadow + Narwhal：验证无攻击支援、后续冷却修饰、自身负反馈与回本周期。
3. Catfish — Zoarcid — Mantis Shrimp — IllusoRay：验证左右关系、Slow、Haste、Burn、Charge、Ammo、成长、连发、循环深度与回放。
4. Flying Fish + Marlon：验证 Flying 设置时点、自催动反馈与暴击成长去重。
5. Tortuga、Slumbering Primordial 只作最后的深红压力测试，不作为首批可玩实现。

### 海兽 24/24 阶段结论

- 24 个来源对象、24 个现有 `pal_id` 均已完成身份方向、机制事件骨架、技术依赖、风险分层和反对项审计。
- 24 个现有宠物物种均不适合原样保留；正式 ID 不交换，只允许底稿参考。
- 物种无完全重复；蟹、鳐、头足、灵长和长体鱼通过姿态、身体数量、尺度、材质和标志道具区分。
- 本阶段不含正式数值，不代表 24 只已可玩或已批准进入正式数据。

## 第 10 轮：船体据点批次 A 独立提案

本批：Barrel、Captain's Quarters、Coral Armor、Cove、Crow's Nest、Dam、Disguise、Holsters。来源页面部分显示最近单卡变更版本而非全局 17.2，正式落表前仍需与内部 17.2 快照差异核对。

### 身份裁决

| pet_id | 宠物身份 | “设施成为身体”的规则 | 分类建议 |
|---|---|---|---|
| `pal_006` | 箍甲犰狳 | 木板状角质甲与铁箍长成桶形背甲，蜷缩成桶，不背外置桶 | 船体据点 |
| `pal_020` | 司令舱灵；动画物件生命 | 本体就是可折叠活舰舱，桌台/舷窗/吊索/武器架是器官；展开越格仅为 VFX | 船体据点 |
| `pal_029` | 珊甲鲎兽 | V 形珊瑚矿化背甲是天然身体，购买成长表现为甲层与珊瑚枝增长 | 船体据点 |
| `pal_030` | 盘湾宝龙 | 海龙盘成 U 形防波堤，身体负空间形成海湾；宝藏是数值可视化，不是单位 | 船体据点 |
| `pal_031` | 桅冠瞭鸦 | 长腿、躯干与竖羽形成桅杆，颈羽形成瞭望篮，不背木塔 | 船体据点 |
| `pal_035` | 堰潮巨狸 | 宽尾与前肢展开成同一身体的水闸；身份动画不预判死亡/退场规则 | 船体据点 |
| `pal_038` | 千面衣灵；活服装 | 帽、面具、披风本身是流动身体，里面没有普通动物 | 建议迁奇物谋略 |
| `pal_055` | 双匣快灵；成对组件的一个活装备单位 | 双枪套为一宠，皮带是肢体，两个套口不算两只或武器单位 | 建议迁器械载具 |

八项保持原 `pal_id`，现有物种均重做。设施可作为身体、展开形态或身体形成的负空间，但不能只是普通动物背着原物品。

### 机制结构与风险

| 对象 | 正式结构候选 | 核心规则 | 风险 |
|---|---|---|---|
| Barrel | 单 A，显式 support 自身盾；左右邻居提交技能后提高未来 A 的本战护盾 | `board_horizontal_round_snapshot`；成长不补发护盾 | 黄偏红 |
| Captain's Quarters | 单 A，显式 support 三操作原子包：Haste Tool/Vehicle、Reload Ammo、Weapon 本战增伤 | prepare 冻结三类目标；缺 Ammo 模块时整包 fail closed，不能静默漏操作 | 深红 |
| Coral Armor | 单 A，显式 support 自身盾；成功购买其他 Aquatic 后永久提高本实例 A 护盾 | 只认付款+取得+库存提交的购买；免费获得/复制/合并不算 | 黄偏红，经济链未修前阻断获取 |
| Cove | 单 A，显式 support，按权威 Value 快照给自身盾；出售提交后提高本实例 Value | Value 不等于价格、退款、金币或品质，也不反向抬高售价 | 红/经济深红 |
| Crow's Nest | `passive_only`：Weapon Crit 光环；唯一 Weapon 获 Lifesteal 与仅 Slow 持续时间抗性 | 战斗阵容锁定唯一 Weapon；中途数量变化不重绑；来源死亡解除 | 黄偏红 |
| Dam | 单 A，显式 support 批量 Destroy；其他 Aquatic A 后 Charge | 冻结双方比来源 Size 小的目标；Destroy 是非死亡退场，不改 HP、不发击杀/死亡；同一安全点批量退出 | 深红，P0 门禁 |
| Disguise | `passive_only`：购买后生成跨英雄对象；使用其他英雄技能后确定性 Charge 本英雄目标 | 依赖 `origin_hero` 与跨英雄白名单池；不是变形/召唤 | 红，外部内容阻断 |
| Holsters | `passive_only`：冷却初始化后，开战 Haste 所有来源 Size=Small 的友方主 A | 只触发一次聚合事务；不因 Apparel 获得护甲/装备槽 | 黄偏红，需先后手测试 |

### 关键裁决

- 本批无任何来源建立真正地形格、位移、净化、嘲讽或战斗召唤；不能由题材名称补写。
- Property 是身份/构筑标签，不自动变成墙、多格单位或不可移动据点。
- 只有 Dam 进入非死亡退场协议；其来源没有 replacement spawn，否决变墙、自爆伤害、献祭死亡和变形四条旧候选。
- `passive_only` 是新增硬门禁：当前空技能列表会被兼容层补 `basic_attack`；Crow's Nest、Disguise、Holsters 在 `PassiveOnlyCombatantPolicy` 前不能落正式数据。
- Barrel、Captain's Quarters、Coral Armor、Cove、Dam 均依赖显式 support；不能用空攻击形状伪装。
- Captain's Quarters 三收益必须原子提交；Coral Armor/Cove/Disguise 与既有折扣—完整品质退款套利相连，经济修复前不进正式获取池。

### 新增模块

1. `PassiveOnlyCombatantPolicy`：明确无主动宠，不注入 basic attack；仍可参与部署、被动、死亡/退场、Snapshot 与 UI。
2. `SupportEffectBatch`：多类支援 operation 的 prepare/commit/abort 原子批次。
3. `PersistentInstanceModifierLedger`：Run 内当前实例的护盾/Value/技能参数成长，进入存档、hash、回撤和迁移。
4. `OriginProvenance + CrossHeroRewardPool`：记录来源英雄并提供显式跨英雄白名单。
5. `SizeQueryService`：读取来源 Small/Medium/Large 元数据，不看美术尺寸、形状面积或棋盘占格。
6. `DestroyBatchService`：逐目标免疫校验后，与 `UnitExitService` 在统一安全点批量非死亡退场。
7. `BattleStartReactionPhase`：在技能实例和初始冷却完成后、首项可获益行动前执行开战被动。

推荐实现顺序：passive-only → support 合同 → 标签/尺寸/相邻查询 → 持久实例修饰与交易事件 → Ammo/冷却唯一写者 → UnitExit + DestroyBatch。Dam 最后做压力纵切。

### 第 10 轮交叉复审裁决

`DECISION`：新增 `action_profile=active|passive_only`。passive-only 仍是完整的四宠棋盘实体：占出战槽与格位，可移动、受击、被治疗/控制、参与自动站位和阵容标签；但不生成共享技能条条目、行动槽或 AP 消耗。全队都是被动时，空技能计划合法结束技能阶段，不得死锁。死亡或 `exit_pending` 后立即停止光环与新反应。

UI 不显示空 A/B，而显示“驻场支援”栏、触发条件、当前有效对象与本场是否触发。桅冠瞭鸦用瞭望线表示 Weapon 光环；千面衣灵在异英雄技能后拟态并发 Charge；双匣快灵只在开战弹匣整备一次。被动价值按覆盖目标数×预计存活回合×触发频率计入槽位预算，不能因没有主动而当成免费弱宠。

`DECISION`：Dam 使用独立 `UnitExit/ExitSystem`，只复用“操作结束后的生命周期屏障”时机，绝不进入 death queue。

Dam 顺序：prepare 冻结自身与双方 `size_class < source.size_class` 候选及免疫快照；resolve 为每目标记录 `DESTROY_RESISTED` 或 exit intent；commit 原子标记所有非免疫目标 `exit_pending`，统一禁行动/禁新目标/禁被动，拆关系、未来计划、技能条投影、格位与临时关联，释放全部格位后再按稳定 ID 发布 `UNIT_EXITED(kind=destroy)` 与 `UNIT_DESTROYED`。监听者看到的 Snapshot 已是全部离场。

Destroy 不改 HP、不发 `UNIT_DEFEATED`，不触发死亡/击杀/尸体/复活/吸血；只删除本场实例与投影，不删除 Run roster。Dam 自身免疫则存活并启动冷却；不免疫则同批退场且不保留幽灵冷却。仍保持深红。

`DECISION`：Captain's Quarters 的 Haste、Reload、Weapon 增伤为一个 SupportEffectBatch。某类别无目标、满弹或冷却已为 0 是合法 no-op；三类全无实际变化则提交前以 `NO_EFFECT_TARGET` 拒绝，防空放刷被动。模块缺失、字段非法、版本冲突或 operation 异常则整包回滚，无 packet、无冷却、无 `SKILL_COMMITTED`。至少一个子效果有效时只消耗一次行动和冷却，共享父 `cause_command_id`。

`DECISION`：Disguise 迁奇物谋略，Holsters 迁器械载具。调整后原生 138 主类计数为海兽24 / 舰炮55 / 器械载具24 / 船体据点18 / 奇物谋略7 / 自然异象10。若另计 Pontoon 跨英雄草案，器械载具25、总草案139。完整性检查只要求每项一个主类，不要求旧类数量不变。

代表纵切顺序：Barrel 验证防御型左右成长；Crow's Nest 验证 passive-only、Weapon 标签和持续光环；Dam 最后验证 Size、免疫、批量非死亡退场和关系重算。Barrel、Crow's Nest、Holsters 满足各自硬门禁后可条件降黄；其他五项暂不降级。

## 第 11 轮：船体据点批次 B 独立提案

本批：Iceberg、Korxena Crest、Life Preserver、Lighthouse、Pearl、Port、Sea Shell、Seadog's Saloon。三组先独立审阅，再针对触发基数、保护对象、空放语义和连发选目标互相复审。本轮仍不填正式数值。

### 来源审计

- 内部 `34_bazaar_objects.csv` 可确认八项与 `pal_058/067/070/072/083/090/100/101` 的历史一对一锚点，但其效果与品质只能作为旧快照。
- 当前可直接确认的核心循环：Iceberg 为敌方行动后冻结触发者；Korxena Crest 为可暴击对象提供 Crit 光环；Life Preserver 为主动护盾加每战一次败北预防；Lighthouse 为 Slow 转 Burn；Pearl 为 Aquatic 友军行动后给自身 Charge；Port 为 Ammo 全队 Reload+Charge 并带每日跨英雄补给；Sea Shell 按 Aquatic 数量提供护盾；Seadog's Saloon 为 Haste+Slow 整包并按 Friend 数获得 Multicast。
- Port 已有明确 17.2 页面证据，核心 Reload、Charge 和每日 Small Ammo 跨英雄奖励未变。其余直接页有的仍停在 16.x 或只在聚合索引保持同一机制，核心循环可讨论，精确起始品质、目标数和数值继续标中等置信，不能伪称 17.2 已全量核实。
- Source Size、Property、Aquatic、Friend、Ammo 等仍只是来源事实；不得直接推导多格单位、地形、所有宠物都是 Friend、或本地初始品质。

### 身份组阶段提案

| pet_id | 暂定身份 | 单体化与轮廓规则 | 主类建议 |
|---|---|---|---|
| `pal_058` | 冰脊拱鲸 | 鲸背与冰脊长成拱形冰山；冰体是身体结构，不是背景地形 | 迁自然异象 |
| `pal_067` | 科尔克瑟娜纹章灵 | 活纹章单体；Korxena 是纹章出处/eponym，不自动成为宠物专名 | 迁奇物谋略 |
| `pal_070` | 浮环海蛇 | 海蛇身体天然盘成救生环，绳结是尾部结构，不背外置救生圈 | 船体据点 |
| `pal_072` | 三灯礁灵 | 三座灯塔是同一礁体的三根发光器官；`body_count=single` | 船体据点 |
| `pal_083` | 潮珠灵 | 珍珠、潮膜与微光共同构成漂浮生命；可参考旧底稿漂浮待机，不继承旧龙种 | 迁奇物谋略 |
| `pal_090` | 赤帆港灵 | 港池是盘卷身体形成的负空间，赤帆与吊臂是鳍/角结构；不是背景港口 | 船体据点 |
| `pal_100` | 红棘螺堡 | 活海螺壳形成堡垒轮廓，软体仍清晰可见；不是普通动物背建筑 | 船体据点 |
| `pal_101` | 海狗酒保 | 单只海狗/海象式酒保；酒客仅是技能 VFX，不增加身体数量 | 船体据点 |

八项保持现有 `pal_id`，现有物种均不直接保留。只有 `pal_101` 的重型体态和獠牙可登记为 `art_base_reference`，但不得保留“白牙雪象”的陆生象身份、旧技能、形状、品质或池；`pal_083` 只可参考漂浮待机。Property 转宠后仍不自动得到 Friend 标签。

### 战斗组独立提案

| 对象 | 结构候选 | 事件骨架 | 关键门禁 | 技术风险 |
|---|---|---|---|---|
| Iceberg | `passive_only` | 敌方 `SKILL_COMMITTED` 后，对该事件的 `skill_instance_id` 施加 Freeze | 只冻结触发技能，不回溯取消已结算效果，不随机换目标；来源 `exit_pending` 后不排新反应 | 红 |
| Korxena Crest | `passive_only` | `BATTLE_ROSTER_LOCKED` 后为友方 `crit_capable` 技能建立 Crit 链接；来源败北/退场拆链 | 不给空技能补普攻；不能假定所有 support、治疗或所有宠物都可暴击 | 黄偏红 |
| Life Preserver | 单 A `support` + 一次性被动 | A 给自身护盾；`BEFORE_DEFEAT_COMMIT` 消耗令牌并治疗，治疗后 HP>0 才取消 defeat candidate | 不是死亡后复活；Destroy/UnitExit 不触发。战斗组独立案选择保护自身宠 | 红 |
| Lighthouse | 单 A `support` + 状态反应 | A 确定性 Slow 敌方；己方成功 Slow 后对目标施加 Burn | 免疫或零有效量不触发；Burn 不反向制造 Slow | 红；触发基数待复审 |
| Pearl | 单 A `support` | A 给自身盾；其他 Aquatic 友军 `SKILL_COMMITTED` 后 Charge 自身 A | 排除自身；每 root 一次；Charge 只推进当前剩余冷却，不是 Haste、额外行动或免费重放 | 黄 |
| Port | 单 A `support` 原子包 + Run 被动 | A 冻结全部 `ammo_capable` 主技能并原子 Reload+Charge；`DAY_STARTED_COMMITTED` 确定性生成跨英雄 Small Ammo 奖励 | 战斗包与每日获取是两个权威事务；缺模块或非法字段整包回滚 | 红/经济深红 |
| Sea Shell | 单 A `support` | prepare 读取 Aquatic 阵容快照，按计数给自身护盾 | 不按占格、形状面积、技能数或整个收藏计数 | 绿偏黄 |
| Seadog's Saloon | 单 A `support` 整包连发 | 每 packet 原子 Haste 一个友方技能并 Slow 一个敌方技能；Friend 数形成 packet count | Multicast 重复完整双状态包，不扩形状、不增技能条、不增 AP | 红 |

### 数值与成长组独立提案

| 对象 | 主要预算轴 | 成长质变建议（无正式数值） | 峰值/长局风险与门禁 |
|---|---|---|---|
| Iceberg | 敌方外层 A 次数 × Freeze × 被动存活回合 | 先限制反应覆盖，再提升控制强度；不追加伤害副轴 | 红→深红；高频敌阵会被持续软锁，必须有控制抗性、Boss 例外和每轮预算 |
| Korxena Crest | 可暴击技能数 × 后续施放次数 × Crit 联动收益 | 从有限目标逐步解锁全队光环；不再叠加 on-Crit 副轴 | 红；同时放大 Calico、Piranha、Vampire Squid 等既有循环 |
| Life Preserver | 主动盾 + 一次致死阻断 + 剩余回合价值 | 低阶段只给盾，后续阶段再解锁一次败北预防；只强化恢复，不增加次数 | 自保红、保护英雄可达深红；必须先锁 `defeat_subject` |
| Lighthouse | 控制目标数 × Slow 事务 × Burn 持续回合 × Slow 消费者扇出 | 先单目标 Slow，再扩大覆盖；Burn 不随目标数与 Multicast无界相乘 | 红→深红；会同时喂多名 Slow/Burn 消费者 |
| Pearl | 其他 Aquatic A 频率 × Charge × 护盾重复 | 先纯盾，后解锁 Aquatic Charge；不扩大监听标签 | 黄红→深红；需冷却下限、单轮推进和额外施放封顶 |
| Port | Ammo 目标数 × Reload × Charge × 每日免费物价值 | 日常补给、战斗 Reload、战斗 Charge 分阶段解锁，不在最低阶段三轴齐开 | 战斗与经济均深红；会重写所有 Ammo 宠的每战上限 |
| Sea Shell | Aquatic 阵容数 × 护盾施放次数 | 先固定盾，后解锁阵容缩放；不增加第二成长轴 | 黄红→深红；明确是否计自身、候补、死亡与召唤 |
| Seadog's Saloon | Friend 数 × packet 数 × Haste/Slow 双状态 × 消费者扇出 | 先单包双状态，后解锁 Friend 连发；禁止再叠范围或三段 | 全程深红；Friend 绝不能解释成所有宠物 |

本批没有任何正式数值。来源品质只进入 `source_tier`；上述阶段建议只进入 `local_quality_unlock_candidate`。

### 独立提案产生的公开分歧

1. **Lighthouse 触发基数**：战斗组初稿按每个成功 Slow application 触发 Burn；数值组坚持每个 root action 最多一次，以符合公共事件词典并阻止多目标倍增。
2. **Life Preserver 保护对象**：战斗组建议转成宠物自身败北替代；来源原义更接近 allied hero，数值组要求先锁 `defeat_subject`，两者预算完全不同。
3. **Port 空放**：战斗组把零目标/满弹/零剩余冷却视作合法 no-op；数值组要求完全无收益时拒绝使用。必须区分“无 Ammo 目标”和“有目标但结果 clamp 为零”。
4. **Sea Shell 计数时点**：战斗组建议锁定开战正式四宠并包含自身，死亡不改变；数值组初稿写“提交时冻结存活部署者”，会造成死亡导致倍率下降。
5. **Seadog's Saloon**：战斗组允许跨 packet 重复目标；数值组要求唯一目标优先。Friend 计数是开战锁定还是逐回合锁定也未统一。
6. **被动实现边界**：数值组提出多个新服务；代码主审发现现有 `battle_hook_pipeline`、`modifier_collector`、`status_service`、`damage_death_service`、`run_event` 管线已有部分责任，交叉复审必须区分扩展现有模块和真正新增模块。

这些分歧已交回三组交叉复审，未提前伪装成共识。

### 第 11 轮二次对质记录

第一次交叉复审并未收敛：战斗组先主张 Lighthouse 每 root 一次、Port 全 clamp 仍完成、Sea Shell/Saloon 开战锁定、Saloon 允许重复目标；数值组先主张 Lighthouse 每成功 packet/application 一次、Port 全零拒绝、两项提交时动态计数、Saloon 唯一优先。

第二次对质后，两组又分别接受了对方上一版的大部分论点，形成“互相改判但方向相反”的真实分歧：

| 争议 | 战斗组二次意见 | 数值组二次意见 | 身份组意见 |
|---|---|---|---|
| Lighthouse | 改为每个 `changed=true` Slow application | 改为每 root 最多一次 | 每个成功 Slow 根行动一次 |
| Port 全 clamp=0 | 改为提交前拒绝 | 改为合法无效果完成并启动冷却 | 未单独裁决 |
| Sea Shell / Saloon 计数 | 改为 A prepare 时当前存活 | 改为 `BATTLE_SETUP_LOCKED` | Sea Shell/Saloon 均偏 A 开始动态 |
| Saloon 跨 packet 目标 | 改为唯一优先、池耗尽后重复 | 撤回唯一优先、允许有放回重复 | 留给主策 |
| Life Preserver | allied hero | allied hero | 自身宠物 |

该轮证明不能把“多数意见”当成规则；最终裁决必须同时满足来源不变量、已冻结公共词典、本地死亡/回合差异、正式代码责任层和可测试性。

### 主审裁决：第 11 轮事件合同

#### Lighthouse：采用本地 root 聚合

`DECISION`：本地 `consume_scope=once_per_root_per_consumer`。同一 root 内至少一个 Slow application 实际改变状态才 Burn 一次；多目标、Multicast packet、三段表现均不增加本宠 Burn 次数。两个独立 root 可各触发一次。

这是明确的本地保守转译，不冒充原作逐 application 事实。理由是第三轮已冻结“下游消费者默认每 root 一次、Multicast 子包不是新技能使用”；若只为 Lighthouse 破例，既有 Darkwater、Mantis、Richardson、Saltclaw 等所有 Haste/Slow 消费者都会重新失去统一基数。未来若产品要支持逐 application 内容，必须新增显式 `consume_scope=application` 并重新评审全网，而不是由单个 handler 暗中特判。

Burn 目标候选采用本 root 中稳定排序后的第一个成功 Slow 目标；来源面向敌方玩家的 Burn 被转成单个棋盘单位 Burn，仍标 `local_target_adaptation=first_changed_slow_target`。若将来决定 Burn 落敌方 leader，则作为主策变更重新评审。

#### Life Preserver：保护 allied hero，但正式接入阻断

`DECISION`：来源不变量保留为保护 allied hero，不改成宠物自保。A 也应给 allied hero 护盾；被动在 allied hero 第一次进入败北候选时消费一次本场令牌并治疗，HP 回正才取消败北。Destroy/UnitExit、普通宠物死亡和死亡后复活均不属于该链。

身份组“当前没有一一对应可受伤英雄单位”的前提被代码实查否决：`game_state.gd` 的 `_leader_unit(true)` 明确生成 `id=player_hero`、持有 `hero_hp/hero_max_hp`，`battle_outcome_policy.gd` 也以 `player_hero_dead` 判负。该对象不是普通 `units` 数组宠物，但确实是正式战斗目标。

新的真实阻断是：`_leader_unit()` 每次把 `shield` 固定投影为 0，尚无权威 `hero_shield` 状态；所以 Life Preserver 的 A 不能在当前数据中伪造。需要先把 leader vitals 纳入权威状态、Snapshot、save/hash/rollback、伤害与治疗管线，再扩展 `damage_death_service.resolve()`，在 `should_die` 与 `on_death` 之间增加 `before_defeat` replacement phase。不得另造复活旁路。

#### Port：区分无目标与有目标全 clamp

`DECISION`：

- 无任何 Ammo 合法目标：`INELIGIBLE_NO_TARGET`，不进执行队列、不耗行动、不冷却、不发使用事件；调度器用目标集合依赖版本缓存不可用状态，依赖未变化不得同帧反复尝试。
- 有合法 Ammo 目标，但 Reload 与 Charge 全部 clamp 为 0：`SKILL_RESOLVED_NO_EFFECT`，作为一次合法 root 完成并启动冷却，只发一次 root 级使用事件，不发 `AMMO_RELOADED/COOLDOWN_CHARGED` 成功 application。
- 至少一个子操作有正差量：整包原子提交；其他 clamp 为 0 的子操作是包内 no-op。
- 模块缺失、字段非法、版本戳过期不是 no-op，必须整包拒绝/回滚。

该裁决与第 10 轮 Captain's Quarters 的“类别无目标可为局部 no-op，整体有合法目标但实际变化判断另行记录”保持一致，也避免自动共享技能条在不可用状态无限重试。

#### Sea Shell 与 Seadog's Saloon：采用开战阵容标签快照

`DECISION`：在 `BATTLE_SETUP_LOCKED` 冻结正式出战实例的 Aquatic/Friend 集合。Sea Shell 包含自身 Aquatic；Saloon 只统计 `source_friend=true`，自身不是 Friend；候补、召唤、临时单位不计。死亡、复活、Dam Destroy 和普通 UnitExit 不重算本场集合。

这是适配本项目死亡频率的本地转译：若提交时动态计数，友军死亡会同时损失单位与 Sea Shell 护盾/Saloon 包数，产生来源物品体系没有对应频率的二次滚雪球。玩家文案必须写“本场出战时的水族伙伴/【伙伴】数”，不得继续写含混的“你拥有”。

#### Saloon：整包、目标策略与消费者

- `packet_count = base_packet + locked_friend_count`；每 packet 原子提交一组 Haste+Slow。
- 整个 A 仅一个 `SKILL_COMMITTED`；每 packet 有独立 `packet_id` 与实际 application。
- 下游 Haste/Slow 消费者默认仍按 root 去重；状态本身当然按 packet 实际结算。
- 来源没有保证唯一目标，因此不把“唯一优先”写进公共 Multicast。当前本地候选为每 packet 使用可回放的确定性随机、有放回选择；重复目标受 `ControlSaturationPolicy`、冷却下限和 `changed` 判定限制。若主策改成显式选定目标，则所有 packet 默认重复该目标并重新跑预算。

目标策略尚是 `candidate_not_formal`；正式数值和抗控曲线通过前，Saloon 保持深红。

#### Iceberg：来源保留、控制饱和兜底

- 只响应敌方正式外层 `SKILL_COMMITTED`；Multicast packet、三段、被动反应不另触发。
- 在敌方 root 全部效果完成后冻结刚使用的同一 `skill_instance_id`，不能取消已经发生的行动，也不能失效后改选他人。
- 每 `(root_action_id, iceberg_instance_id, rule_id)` 最多一次；来源 defeat/exit/silence 后不排新反应。
- Freeze 不叠层延长，默认 refresh/max stack 1；多 Iceberg、Boss 抗性、最低行动出口和全局反应深度统一交给 `ControlSaturationPolicy`。
- 成功 Freeze 携带原 root 因果 ID；可成为其他明确 Freeze 消费者的证据，但不得回入 Iceberg 自身或制造新 `SKILL_COMMITTED`。

### 代码模块归并：扩展现有与真正新增

代码主审直接检查了当前服务后，否决“每种状态/宠物另造一套服务”。

| 需求 | 现有责任层 | 处理方式 |
|---|---|---|
| support/passive-only/原子包 | `skill_execution_service.gd`、`skill_effect_port.gd`、`skill_queue_service.gd` | 扩展 execution policy、prepare/commit/abort 与 `action_profile`；不能复制第二套执行器。当前效果失败仍 finish 并启冷却，必须先补明确失败语义 |
| 状态应用与实际差量 | `status_service.gd` | 把 `apply()->bool` 升为富结果：accepted、changed、before/after、application_id、rejected_reason；Slow/Burn/Freeze 不各造服务 |
| 跨单位反应 | `battle_hook_pipeline.gd` | 扩 hook/event context；另新增窄 `CombatEventLedger + ReactionScheduler` 管 root/packet/application ID、稳定队列、去重和反应深度，pipeline 不递归自调 |
| 光环与链接 | `modifier_collector.gd` | 扩展读取 battle-scoped 外部链接；新增的 Link Registry 只保存来源—目标—技能实例生命周期，最终合并仍只有一个 collector |
| 救生圈败北替代 | `damage_death_service.gd`、`damage_death_port.gd` | 在现有死亡安全点前加 `before_defeat`，支持 leader candidate；不建复活队列 |
| hero 护盾与治疗 | `_leader_unit()`、DamageResolver、UnitVitals/Snapshot | 新增权威 leader shield/vitals 字段或窄 LeaderVitals seam；当前固定 `shield=0` 是 P0 阻断 |
| Haste/Charge/冷却 | 现有 cooldown rate 与散落 port 调用 | 真正新增 `SkillCooldownService` 作为剩余冷却、基础冷却修饰、Charge、Haste/Slow 的单写者 |
| Ammo 批量支持 | 已规划的 `battle_resource_ledger` | 扩展批量预演、上限、部分有效与原子提交；Ammo 仍不可复用 AP/冷却 |
| 标签快照 | 战斗 setup/Snapshot、TagQuery | 新增或扩展 `BattleCompositionSnapshot`，保存开战正式实例与 source tags；不从 UI/物种名反推 |
| Port 每日奖励 | 现有 Run 日切、run event operation、acquisition | 增加版本化 grant handler 与跨英雄白名单池；不建第二套经济状态 |
| 自动条无目标重试 | skill plan/queue | 新增 `EligibilityDependencyStamp` 能力或扩展现有脏标记；依赖集合没变时不重复评估 |

真正独立且可复用的新增策略只有：

1. `ControlSaturationPolicy`：统一 Freeze/Slow 多来源叠加、重复目标、Boss 抗性、最低行动出口。
2. `SkillCooldownService`：冷却唯一写者。
3. `CombatEventLedger + ReactionScheduler`：跨单位事件信封、稳定反应队列与去重。
4. `BattleCompositionSnapshot`：战斗开始冻结的来源标签集合；若 setup 已有等价权威快照，则实现为扩展而非新服务。

### 非战斗策划补充

- **图鉴/教程**：显示【伙伴】是来源标签，不等于“所有宠物”；设施型宠显示移动形态与部署形态。
- **美术**：每个设施型宠仍必须只有一个选中核心、格位、血条、受击中心；超格建筑、船只、灯塔光束和酒客只是非碰撞 VFX。
- **商店/Run**：Port 的跨英雄 Small Ammo 池需要白名单、权重、解锁日、重复、满背包去向、售价/合成资格和 provenance。
- **AI**：能估价 passive-only 槽位、救生圈一次性胜负保险、Port 日收益、Sea Shell/Saloon 开战标签快照和 no-effect 支援，不把无伤害技能估值为零。
- **UI**：被动宠显示“驻场支援”；Saloon 显示锁定【伙伴】数与包数；Sea Shell 显示锁定 Aquatic ID/数量；Life Preserver 显示本场救援令牌是否已消费。
- **本地化**：Korxena 仍是 eponym，正式中文音译待定；所有“你拥有/所有物品/相邻/玩家死亡”必须写成本地可执行范围。
- **QA**：固定种子覆盖 root/packet/application、全 clamp Port、英雄致死拦截、开战标签快照、重复目标控制饱和、多 Iceberg、Dam 与救生圈不相交、存档回撤/stateHash。

### 第 11 轮最终身份与分类

八项仍保持现有 `pal_id`，不交换 ID，不继承旧物种机制。暂名为：冰脊拱鲸、科尔克瑟娜纹章灵、浮环海蛇、三灯礁灵、潮汐珠灵、赤帆港灵、红棘螺堡、海狗酒保。

迁类：Iceberg → 自然异象；Korxena Crest、Pearl → 奇物谋略。其余五项保留船体据点。canonical 138 当前主类计数变为：海兽伙伴 24 / 舰炮兵器 55 / 器械载具 24 / 船体据点 15 / 奇物谋略 9 / 自然异象 11。若另计 Pontoon 草案，则器械载具 25、总草案 139。

第 11 轮可进入无数值骨架：Korxena Crest、Pearl、Sea Shell；带硬门禁骨架：Lighthouse、Iceberg；阻断：Life Preserver（leader shield/vitals）、Port（Ammo+跨英雄日奖励）、Seadog's Saloon（整包 Multicast+控制饱和）。

## 第 12 轮：剩余船体据点 + 原始奇物谋略独立提案

本批十项：Swash Buckle、Tropical Island、Turtle Shell、Water Wheel、Ambergris、Beach Ball、Coral、Figurehead、Lockbox、Tripwire。本轮目标是把船体据点与奇物谋略两类做完阶段闭环。

### 来源纠错与代理纠错

- 17.2 直达页确认 Tropical Island 已是 Silver+、Large，战斗结束固定获得 Coconut 与 Citrus；旧 CSV 的 Gold 与“每小时随机获得一个”均进入历史列，不得进入当前机制。
- 17.2 直达页确认 Turtle Shell 已是 Silver+，使用时给自身/玩家盾并为 board items 的 `ShieldApplyAmount` 写本战增量；其他 non-Weapon 使用后 Charge 自身。旧 CSV 的 Gold 已过时。
- 17.2 直达页确认 Swash Buckle 为 Gold、Medium，左右相邻对象获得 Crit，并按最终 Crit 派生 Damage/Heal/Shield。
- Beach Ball 当前冷却与 16.2 缓存不同；只保留“多目标 Haste Aquatic/Toy”的稳定循环，不落秒数。
- `REJECTED_AGENT_MAPPING`：战斗组独立表误写 `Coral/pal_029` 与 `Figurehead/pal_046`。正式旧锚点始终是 `Coral=pal_028`、`Figurehead=pal_045`、`Lockbox=pal_073`、`Tripwire=pal_128`；`pal_029` 属于 Coral Armor。错误已在进入交叉复审前拦截，不允许据此交换 ID。

### 十项身份提案

| 对象 / pet_id | 暂定身份 | 轮廓与生命形态 | 分类 |
|---|---|---|---|
| Swash Buckle / `pal_120` | 扣尾守宫 | 低伏守宫，尾巴天然卷成扣环；不是腰带扣加眼睛 | 迁奇物谋略 |
| Tropical Island / `pal_129` | 椰湾海牛 | 海牛背部长出有机棕榈叶冠和结果枝，不背岛景/房屋 | 船体据点 |
| Turtle Shell / `pal_130` | 棱盾鳖 | 极低扁菱甲、长鼻、缩甲防守；与高大载具龟 Tortuga 以姿态/尺度/职责防撞 | 船体据点 |
| Water Wheel / `pal_134` | 桨轮水甲虫 | 两侧后足桨毛形成轮桨，腹部天然涡流腔；不是水车加脸 | 迁器械载具 |
| Ambergris / `pal_001` | 琥香海蛞蝓 | 半透明脂质背叶与香脂结节；不是鲸、龙或琥珀块加眼睛 | 奇物谋略 |
| Beach Ball / `pal_008` | 弹潮海豚 | 宽吻幼豚、弯月跃姿、皮肤彩斑；避开河豚/石头的圆球轮廓 | 奇物谋略 |
| Coral / `pal_028` | 愈潮珊瑚虫 | 群落动物但一个战斗单位、一个选择核心、一条血条 | 奇物谋略 |
| Figurehead / `pal_045` | 双舷海马 | S 形海马、左右不对称鳍分别承接冷却/伤害；不是木雕加眼睛 | 奇物谋略 |
| Lockbox / `pal_073` | 金锁袋熊 | 方厚袋熊，腹袋/背甲形成保险结构；不是宝箱主体 | 奇物谋略 |
| Tripwire / `pal_128` | 绊丝猎蛛 | 低腹猎蛛、远伸前足、可见感应丝；不是绳圈加眼睛 | 奇物谋略 |

十项均 `unit_count=1`、`source_friend=false`。Coral 可登记 `body_count=colony`，但仍只有一个权威单位。旧底稿方面仅 `pal_130` 龟体高兼容，可保留低重心龟身和缩壳动作；其他九项最多复用色板、VFX 或动作节奏，旧物种、技能、形状、品质、池均不继承。

### 战斗结构独立提案

| 对象 | 结构 | 本地事件骨架 | 初始风险 |
|---|---|---|---|
| Swash Buckle | `passive_only` | 回合关系快照为即时左右邻建立 Crit 光环；邻宠 A prepare 时，以最终 Crit 单向派生其已存在的 Damage/Heal/Shield 参数 | 红 |
| Tropical Island | `passive_only` | 己方成功 Slow 根行动后给 allied leader 本战 Regen；`BATTLE_ENDED_COMMITTED` 原子发 Coconut+Citrus，胜负均候选触发 | 红/经济红 |
| Turtle Shell | `support` 单 A + 被动 | A 先写友方 shield-capable 主 A 的本战 Shield 参数增量，再给 allied leader 护盾；其他 non-Weapon root 后 Charge 自身 A | 深红 |
| Water Wheel | `support` 单 A + 被动 | A Haste 所有其他合法友方技能；即时左右邻友军 root 提交后 Charge 自身 A | 深红 |
| Ambergris | `support` 单 A + 购买成长 | A 按实例 Value 治疗 allied leader；成功购买其他 Aquatic 后永久增长本实例 Value | 红/经济深红 |
| Beach Ball | `support` 单 A | 从 Aquatic/Toy 正式标签技能中确定性选择多个目标 Haste；同 packet 无放回；来源没有“other”，可包含自身 | 黄偏红 |
| Coral | `support` 单 A + 购买成长 | A 治疗 allied leader；购买 Aquatic 后永久提高本实例 Heal 参数 | 黄偏红 |
| Figurehead | `passive_only` | 同排全部左侧 Aquatic 获后续最大冷却效率；同排全部右侧 Weapon 获 Damage | 黄偏红 |
| Lockbox | `passive_only` | 开战按当前实例 Value 给 Weapon A 建伤害链接；胜利结算后幂等增长实例 Value，作用下场 | 红/经济深红 |
| Tripwire | `passive_only` | 敌方外层 A 全部完成后 Slow 刚使用的同一 `skill_instance_id`；每敌 root 每实例一次 | 黄偏红/控制红 |

所有主动均 `cells=[]`、不虚构 B、不走攻击形状。所有被动空技能必须依赖 `action_profile=passive_only`，禁止兼容层注入 `basic_attack`。

### 数值与成长组独立意见

- Swash Buckle 的混合技能可能同时吃 Damage、Heal、Shield 三份预算；每通道最多修饰一次，Multicast 只重复 prepare 后的包，不能每 packet 重算 Crit。
- Tropical Island 的战斗 Regen 风险由黄升红，十二回合为深红；固定双奖励是经济深红，不能偷换成每日或随机奖励。
- Turtle Shell 的 Shield 成长与 non-Weapon 回转是两条乘法轴；本地品质应分阶段解锁，不能低阶段全开。
- Water Wheel 必须证明“邻居驱动自身→自身驱动全队”的净推进不会构成无限回转。
- Ambergris、Coral、Lockbox 的永久成长必须绑定实例、购买/胜利事务、合并、复制、回撤与存档；不写账号永久。
- Beach Ball 品质只增加目标容量，不同时放大 Haste 幅度和自身周转。
- Figurehead 品质只提高左右两翼强度，不扩第三轴；Tripwire 只提高阻滞强度，不增加目标或触发次数。

### 空间语义

- Swash Buckle、Water Wheel：`horizontal_immediate_adjacent_round_snapshot`，即同排左右各一格。回合开始冻结关系，移动、死亡、exit 立即断链，本回合不重绑。
- Figurehead：`horizontal_same_row_directional_round_snapshot`，即同排全部 `x < source.x` 与 `x > source.x`；不是 Adjacent，也不是共享技能条前后顺序。
- 三者都必须在棋盘/UI 画出不同颜色的关系线；禁止只在隐藏数值里生效。

### 独立提案产生的交叉问题

1. **Turtle Shell 是否创造新 Shield operation**：17.2 Deep Mechanics 给 board items 的 `ShieldApplyAmount` 加值；三组为控制本地事件网，倾向只强化 `shield_capable` 技能。该做法必须标成明确本地裁剪，不能说成来源原义。
2. **Value 是否影响出售**：战斗组认为 Ambergris 的 Value 就是真实 SellPrice；数值组担心当前 acquisition/refund 漏洞，主张拆 `mechanic_value`。Lockbox 有同一冲突。
3. **Coral 是否自触发购买**：来源没有写“another”；战斗组认为新买 Coral 入库后可消费自身购买，数值组认为购买监听集合应在 prepare 冻结，新对象不追认。
4. **Tropical Island 外部奖励**：Coconut/Citrus 不在本轮 138 个原生映射内；缺正式内容 ID、库存溢出与出售/合并规则时必须暂停奖励分支，不能战斗召唤两个占格单位。
5. **Leader 状态缺口**：Tropical Regen、Turtle Shield、Ambergris/Coral Heal 都指向 allied leader；当前 leader shield 固定投影为 0，leader Regen 也无权威账本，四项不能用宠物自身数值偷偷替代。
6. **分类**：Swash Buckle 迁奇物、Water Wheel 迁器械；其余本轮保持身份组提案。若接受，canonical 138 为海兽24 / 舰炮55 / 器械25 / 船体13 / 奇物10 / 自然11。

上述问题已交回三组交叉复审；当前未填正式数值。

### 第 12 轮交叉复审与主审裁决

#### Turtle Shell：全体链接、仅 Shield operation 消费

三组对“只锁 `shield_capable`”仍有表述分歧。最终用两层合同消解：

- 来源事实照录：17.2 对 board items 的 `ShieldApplyAmount` 增加本战数值。
- 本地 A 对全部正式友方主技能实例建立 `shield_apply_amount_bonus` 链接，不按坦克职业、当前护盾或单位名字筛选。
- 该修饰只在一个真实 Shield operation prepare 时被 `modifier_collector` 消费；没有 Shield operation 的技能不会凭空生成护盾 packet、标签、事件或技能类型。
- 若未来另一个正式机制确实给该技能注入 Shield operation，新 operation 可读取仍有效的本战链接；当前 Turtle 自身不负责注入。

这既不把来源目标集合静默缩窄，也遵守本地 `NO_OPERATION_INJECTION`。玩家文案写“本场所有友方的护盾效果提高”，不能写成“所有技能都会获得护盾”。A 内先提交修饰链接，再结算自身给 allied leader 的 Shield；整个 A 是原子 support batch。

#### Ambergris / Lockbox：来源忠实 Value 轨，正式获取阻断

身份组主张把战力指标命名为“香脂/珍藏”并与售价拆分，数值与战斗组指出这会删除来源经济循环。主审采用来源忠实轨：

```text
source_item_value -> local instance_value
instance_value 同时进入技能换算与出售报价
```

- Ambergris 的购买成长同时提高后续 leader Heal 与出售价值。
- Lockbox 的胜利成长同时提高下一战 Weapon 增伤与出售价值。
- 实例价值必须进入 acquisition lot、存档/hash/rollback、复制/合并和出售报价；当前折扣购买后按完整品质退款的潜在套利未修，二者不进入正式获取池。
- “香脂/珍藏”可作为 UI 主题别名，但卡面必须明确“也会提高售价”，不能伪装成与经济无关的战力条。
- 如果产品以后选择移除经济循环，必须形成显式 `ECONOMY_LOOP_REMOVED` 主策决议并重新预算，不能由实现层偷偷拆值。

#### Coral：购买前监听者快照，新买自身不追认

来源没有 `another`，但未给出新实例是否能监听导致自身创建的购买提交。为避免获取钩子安装顺序决定玩法，采用：

1. PURCHASE prepare 冻结交易前已持有、有效的 Coral 监听实例。
2. 扣款与入库成功后提交 `ITEM_PURCHASE_COMMITTED`。
3. 冻结列表中的 Coral 各消费该 transaction 一次；新买实例不在列表中，不自触发。
4. 已持有 Coral 购买另一只 Coral 时，旧实例触发；新实例不触发。
5. 免费获得、奖励、复制、合并、升级均不是 PURCHASE。

这是本地可预测性裁决，标 `source_self_trigger_unknown=true`，不冒充来源事实。玩家文案用“购买另一只水族宠物后”。

#### Tropical Island：外部原子双奖励

- `BATTLE_ENDED_COMMITTED` 后固定生成 Coconut 与 Citrus；胜、负、平局均为正式 fight end，取消、模拟、回放和非法结束不触发。
- 两件是 Run/库存层外部奖励，不是战斗召唤、占格物、临时宠物或随机二选一。
- 任一正式内容定义缺失时，Tropical Island 整体以 `CONTENT_DEPENDENCY_MISSING` 从正式商店/掉落/出战池禁用；不能只保留 Regen 半只宠上线。
- 使用一个 `RewardGrantBundle` 与 `battle_completion_id` 幂等；容量不足进入统一待领取队列，禁止自动出售或只发一件。
- 两件各自记录 `acquisition_kind=grant`、`paid_cost=0`，后续出售/复制/合并不冒充购买。
- 多份 Tropical 是否叠加仍是主策门禁；未裁决前内容校验限制同一持有快照只发一包。

#### 空间关系：采用棋盘横向回合快照

身份组建议固定四宠编队顺序，战斗/数值组建议棋盘同排关系。主审选择棋盘空间，以回应本项目 8×7、可移动、站位可反制的战斗差异，并遵守玩家偏好的可见左/右规则：

- Swash Buckle、Water Wheel：`board_horizontal_round_snapshot`，同排左右各一格。
- Figurehead：`board_horizontal_same_row_directional_round_snapshot`，同排全部左侧/全部右侧。
- 战斗开始建立第一轮，之后每回合开始重建；移动、死亡、exit 立即断链，中途移入不补链，等下回合。
- 关系线、受益者 ID、沙漏/武器/暴击图标必须在布阵预览与战斗中可见，不能只靠颜色。
- 共享技能条重排绝不改变关系。

保留身份组反对意见：固定编队更接近原作 item board 且死亡/移动波动较小。正式采用棋盘域前，必须用自动站位与四宠常见布局验证“同排关系实际可建立且玩家可操控”；若自动站位长期让关系失效，再回到 formation-order 方案，不在数据层静默切换。

#### Leader 状态统一责任层

Life Preserver 已暴露 leader shield 缺口，本批又增加 Heal/Shield/Regen。统一方案为 `LeaderCombatantState / CombatantStateAccessor`，不是三个宠物专属服务：

```text
leader_id, side, hp, max_hp, shield, statuses, alive
```

它必须进入 `GameSession -> Command -> YsbzsState -> Result/Trace/Snapshot`、DamageResolver、EffectInterpreter、StatusService、save/hash/rollback/replay、AI、UI 与中文日志。Regen 有固定 tick 阶段、本战叠加、战后清零；Heal 记录请求/实际/过量；Shield 走现有伤害吸收顺序；败北替代发生在伤害写入后、战败提交前。

在该权威层完成前，Tropical Regen、Turtle Shield、Ambergris/Coral Heal、Life Preserver 均不得偷偷改成宠物自身收益。

#### 其余逐项裁决

- Swash：最终 Crit 合并并封顶后，按技能真实存在的 Damage/Heal/Shield 主通道各转换一次；混合技能可同时吃三通道，故保持深红。多个 Swash 不得对同一最终 Crit 重复做“Crit→数值转换”；Multicast 重复已修饰包，不重算转换。
- Water Wheel：邻居 root 每个消费者一次 Charge；自身 A Haste 其他友方，排除自身。循环需做净推进压力测试。
- Beach Ball：Aquatic/Toy 来自来源标签；同 packet 目标无放回，多目标不是 Multicast。是否允许自身作为目标受当前“冷却在效果后启动”的执行顺序影响，保持 `SELF_TARGET_PENDING_COOLDOWN_ORDER`，未裁决前正式导出失败。
- Figurehead：左侧只改后续最大冷却效率，不是即时 Charge；右侧只修饰 Weapon 的主伤害标量，不逐段复制固定增量。
- Lockbox：当前目标锁 Weapon；历史 public all-items 与 Deep Weapon 的冲突留在来源列，不静默扩大。
- Tripwire：与 Iceberg 共用敌方 root 完成后的反应窗口，目标为刚使用的技能；技术风险黄、平衡风险深红，必须接控制饱和/Boss 抗性/最低行动出口。
- 两龟可条件并存：Tortuga 是高大载具船龟，棱盾鳖是低扁菱甲防守型；黑色剪影不能稳定区分则棱盾鳖更换甲壳物种。

### 第 12 轮模块补充

1. `LeaderCombatantState / CombatantStateAccessor`：leader HP/Shield/status 的统一权威访问与写回。
2. `RewardGrantBundle`：挂在现有 Run event operation registry 内的原子多奖励 handler。
3. `DerivedStatProjection`：接入现有 stat query/modifier collector，负责 Crit→已存在主通道的单向派生。
4. `InventoryInstanceValue`：实例真实价值唯一字段，进入 acquisition lot、出售、存档与成长；不是平行 mechanic value。
5. `RelationSnapshot` 扩充 `board_horizontal_same_row_directional_round_snapshot`；立即左右域复用已有 board horizontal 规则。
6. `ContentDependencyValidator`：外部奖励 ID 缺失时 fail closed，避免半机制上线。

其余复用/扩展既有 `battle_hook_pipeline`、`status_service` 富结果、`modifier_collector`、`SkillCooldownService`、support/passive policy、Run event registry 和交易事务，不另建宠物专属服务。

### 船体据点与奇物谋略阶段闭环

本轮十项最终身份：扣尾守宫、椰湾海牛、棱盾鳖、桨轮水甲虫、琥香海蛞蝓、弹潮海豚、愈潮珊瑚虫、双舷海马、金锁袋熊、绊丝猎蛛。

分类：Swash Buckle 迁奇物谋略，Water Wheel 迁器械载具；Tropical Island/Turtle Shell 留船体据点；原始奇物六项均留奇物。canonical 138 更新为海兽24 / 舰炮55 / 器械25 / 船体13 / 奇物10 / 自然11。另计 Pontoon 草案时器械26、总草案139。

累计已有 50/138 原生对象完成逐项身份、事件骨架、代码依赖和风险审阅。下一类应进入器械载具；先做含左右/冷却/观察/导航的代表批次，再做载具与潜水批次。

## 第 13 轮：器械载具批次 A 独立提案

本批八项：Astrolabe、Captain's Wheel、Custom Scope、Diving Helmet、Dock Lines、Fishing Net、Fishing Rod、Honing Steel。精确旧锚点依次为 `pal_004`、`pal_021`、`pal_032`、`pal_040`、`pal_041`、`pal_046`、`pal_047`、`pal_056`；不交换 ID，不继承旧统一技能。

### 来源证据与两次纠错

当前采用 BazaarDB 明确标注的 17.2 页面为本批版本权威：

| 对象 | 17.2 来源事实摘要 | 当前证据 |
|---|---|---|
| Astrolabe | Silver、Medium、Tool；主动催动多个对象，另一 non-Weapon 使用后推进自身 | https://bazaardb.gg/card/nqnymypyxy5llhs5tn5zwpb25v/Astrolabe |
| Captain's Wheel | Silver、Medium、Aquatic/Tool；催动相邻对象；拥有 Vehicle 或 Large 时自身冷却减半 | https://bazaardb.gg/card/jcj5923pvmhdh7yqbsl4hn84gb/Captain%27s-Wheel |
| Custom Scope | Silver、Small、Tech；右侧 Weapon 获 Crit；恰好一个 Weapon 时，其暴击推进一个 non-Weapon | https://bazaardb.gg/card/xzt9hjdn4y5w5y63k1jqpl6tl7/Custom-Scope |
| Diving Helmet | Gold、Medium、Aquatic/Tool/Apparel；Aquatic 使用时 Shield player；相邻对象战斗中获得 Aquatic | https://bazaardb.gg/card/19fb4133c27l2zd47zgjlnnvpph/Diving-Helmet |
| Dock Lines | Silver、Medium、Tool/Aquatic；主动阻滞多个有冷却目标 | https://bazaardb.gg/card/txntbmpsfwdwnsvp0k975bz35g/Dock-Lines |
| Fishing Net | Bronze、Medium、Aquatic/Tool；主动阻滞多个目标；每日获得任意英雄的 Small Aquatic 或 Loot | https://bazaardb.gg/card/hn4n4qhc9t3hklm0zysh76jn90/Fishing-Net |
| Fishing Rod | Bronze、Medium、Aquatic/Tool；催动右侧 Aquatic；每日获得 Small Aquatic | https://bazaardb.gg/card/zbl1db4fqm6qgj58y4q0z9kn46/Fishing-Rod |
| Honing Steel | Bronze、Small、Tool；使用时强化全局最左与最右 Weapon；Deep 是两个独立 operation | https://bazaardb.gg/card/xyvgqch3v3hjtdjm45wddpx00f/Honing-Steel |

本轮留下完整纠错链：

1. 身份组和数值组最初把 BazaarWinner/howbazaar 无版本页面当成 17.2，遂误报 Diving Helmet 为 Silver/自身护盾成长、Fishing Net 固定产 Piranha、Honing Steel 只强化右侧单 Weapon。
2. 数值组检查 HTTP 元数据后发现这些页面 `dataSource=howbazaar`，Vercel 缓存年龄约 71 天，随即撤回前两项，并一度把 Honing Steel 降为“只确认16.x”。
3. 主审实时重开同一 Honing Steel card ID，页头明确 `Database based on patch 17.2` 与 `As of patch 17.2`；公开文案仍是左右最外 Weapon，Deep 明确列出 right-most 与 left-most 两个 `When this item is used -> Add DamageAmount` operation。因此再次纠正：Honing Steel 恢复 17.2 高置信，右邻单 Weapon 只保留为低置信历史/分支缓存。
4. `REJECT_CURRENT_SOURCE`：Diving Helmet 的 Silver/自身成长、Fishing Net 固定 Piranha、Honing Steel 右邻单 Weapon 均不得写入当前机制列；可留在“历史/缓存冲突”列供未来版本追溯。

本批基础效果没有 Aim、Ammo、Reload 或 Freeze。Custom Scope 是 Crit，不是 Aim；Freeze 只出现在附魔，不得因器械题材擅自加入基础宠物。

### 正式代码只读审计

- 当前 Crit 已存在于 `StatIds.CRIT_RATE_PERMILLE/CRIT_DAMAGE_PERMILLE` 与 `critical_damage_consumer.gd`，但暴击结果主要留在单次 damage result/trace；缺少跨宠可订阅的 root 级 Crit 汇总事件。事件随机种还需纳入 root/action/packet 身份，避免不同发动意外复用同一结果。
- `SkillEffectPort.begin_skill()` 仍强制获取攻击槽、方向和 attack option；纯 `support`、`support_bundle`、`passive_only` 尚无完整正式入口，不能靠空形状伪装攻击。
- 技能冷却当前写在 `unit.skill_cooldowns[skill_id]`，回合推进固定递减；没有统一的 `add_remaining/subtract_remaining/set/start/query` 服务。现有 `status_haste/status_slow` 修改 speed，不能承担本批催动/阻滞。
- 当前目标解析器主要支持 self/allies/enemies 等宽泛集合，没有来源标签、正右格、同排左右格、全局左右极值或技能实例目标。
- 当前 leader HP 有权威流程，但 leader Shield 仍会在投影时回到 0；Diving Helmet 不得降级成给宠物自身护盾。
- 一个来源 item 对应一只宠物。冷却效果只作用于宠物声明的 `tempo_anchor_skill_id`，默认候选为 A；不能因本地允许 A/B 就把一个来源对象复制成两个冷却目标。

### 八项身份独立提案

共同字段：`proper_name=false`、`body_count=single`、`unit_count=1`、`source_friend=false`。每日奖励不是第二身体或战斗召唤物。

| 对象 / pet_id | 暂定身份 | 轮廓与动作锚点 | 旧底稿复用与防撞 |
|---|---|---|---|
| Astrolabe / `pal_004` | 星仪天蛾 | 四片同心星斑翼交错校准，触角感应 non-Weapon 行动；发出多目标星轨脉冲 | 仅留青藤鼠浅青绿色与藤轨；删鼠头、耳、四足、鼠尾。由“星环天蛾”改为“星仪天蛾”，避免与 Star Chart 混淆 |
| Captain's Wheel / `pal_021` | 舵尾海鳄 | 长低鳄体、四短足、末端放射舵鳍；尾摆分别向左右邻格送水流 | 仅留暮羽鸦深蓝色板与观察后转向节奏；删鸟喙、翼、羽尾。与扣尾守宫、浮环海蛇用重鳄体/四足区分 |
| Custom Scope / `pal_032` | 聚瞳蜻蜓 | 细长水平躯干、窄翼、巨大复眼；正右准星锁 Weapon，暴击后尾灯传出脉冲 | 仅留石甲鲮节片层次与锁定火花；删穿山甲鳞体、卷尾、爬姿。禁止瞄准镜加腿或镜片独眼怪 |
| Diving Helmet / `pal_040` | 泡盔蝾螈 | 厚短蝾螈、羽状外鳃、透明压力泡；左右水膜把邻宠临时纳入 Aquatic，Aquatic 行动后回流护盾脉冲 | 仅留黑羊重防御质量感；删羊角、蹄、火焰和外穿铜盔。泡膜是生理结构，不是潜水服怪物 |
| Dock Lines / `pal_041` | 缆须藤壶 | 低矮锥体、四根长捕食蔓足与吸盘；先锚地再按稳定顺序拉紧多个敌方技能 | 仅留回春彩蝶青白金色与对称线；删蝶翼和飞行动作。与珊瑚虫竖枝、螺堡旋壳防撞 |
| Fishing Net / `pal_046` | 网囊鹈鹕 | 巨喙前重、矮胖水鸟；喉囊展开为格网水膜，日切吐出封装奖励泡 | 仅留月镰螳螂夹合 timing 与青绿色；删螳螂头、六足和镰臂。奖励不是永久画在身上的第二生物 |
| Fishing Rod / `pal_047` | 钓丝水黾 | 针状身体、超长水面足与垂直诱丝；正右送水波，日切从诱丝拉出外部奖励 | 仅留裂空苍鹰蓝色轨迹与向右发力节奏；删鹰头、翼、爪、羽尾。禁止水黾手持鱼竿 |
| Honing Steel / `pal_056` | 砺角牦牛 | 厚重牛体、宽弧双磨脊角；两角分别向全棋盘最左/最右 Weapon 发出砺锋火星 | 旧牛科骨架高兼容，保留双角、低头重心和踏地；雷电改金属磨屑/淬火火星。与未来犀类用厚毛宽角/单角甲体防撞 |

八项都保留器械载具主类；外形不会自动赋予 Flying、Weapon、Vehicle、Aquatic 或其他来源标签。

### 三组独立战斗与成长提案

| 对象 | 初始本地骨架 | 独立意见中的主要门禁 |
|---|---|---|
| Astrolabe | `support` 单 A：催动多个合法友方 tempo anchor；另一 non-Weapon root 提交后推进自身 A | 自身能否成为 A 目标、先启动冷却还是先结算催动、每 root 去重、确定性无放回选择 |
| Captain's Wheel | `support` 单 A：催动左右相邻；开战有 Vehicle/Large 时自身 A 冷却减半 | 相邻域、来源 tag/size 锁定、per-skill 冷却修饰、最低冷却与同类叠加 |
| Custom Scope | `passive_only`：正右 Weapon 获 Crit；恰好一个 Weapon 时，其 root 内出现暴击后推进一个 non-Weapon | Weapon 计数单位、Crit root 汇总、右侧关系、确定性目标、多段/连发去重 |
| Diving Helmet | `passive_only`：左右邻获得本战 Aquatic 标签；任一友方 Aquatic root 后给 allied leader Shield | 派生标签生命周期、跨宠 root 事件、leader Shield 权威状态、递归防护 |
| Dock Lines | `support` 单 A：确定性无放回阻滞多个敌方 tempo anchor | ready 技能能否被加 remaining、控制饱和、Boss 抗性、最低行动出口 |
| Fishing Net | `support + run_passive`：战斗多目标阻滞；`DAY_STARTED_COMMITTED` 从跨英雄 Small Aquatic/Loot 池获得一件 | 生成池、跨英雄白名单、随机种、容量/待领取、获取来源与读档幂等 |
| Fishing Rod | `support + run_passive`：催动正右 Aquatic；每日从独立 Small Aquatic 池获得一件 | 正右关系、Diving 派生标签可见性、无目标拒绝、奖励池范围不可从 Net 类推 |
| Honing Steel | `support_bundle`：强化当前最左与最右 Weapon 的主 A DamageAmount，持续本战 | 全局极值选择、同列 tie、单 Weapon 双 operation、参数账本、十二回合累计与整包回滚 |

全部主动 B 暂空；`passive_only` 不得被兼容层注入 `basic_attack`。支援主动使用 `cells=[]`，不生成攻击形状、命中格、基础攻击或伤害事件。

### 交叉争议与主审裁决

#### 空间关系：再次否决共享技能条邻位

数值组提出 Captain's Wheel、Custom Scope、Fishing Rod、Honing Steel 读取共享技能条左右/极值；身份组和战斗组坚持玩家可见棋盘。主审继续采用棋盘，因为本项目的站位、移动和 8×7 格才是可反制的战斗语言；共享技能条是行动顺序，不是空间。

- Captain's Wheel：`board_same_row_immediate`，同排 `x-1/x+1`。
- Custom Scope：`board_same_row_immediate_right`，同排 `x+1` 且目标为 Weapon-capable 宠物。
- Diving Helmet：`board_same_row_immediate`，同排 `x-1/x+1` 获派生 Aquatic。
- Fishing Rod：`board_same_row_immediate_right`，同排 `x+1` 且目标有 Aquatic 来源/派生标签。
- 上述持续关系在回合开始锁定；来源移动、死亡或 exit 立即断链，中途移入下回合才建立；共享技能条重排无影响。
- Honing Steel 不是邻接光环。A prepare 时按当前存活棋盘位置冻结 `board_global_weapon_extremes`；先比较 x，再用 y、稳定 unit_id 破同列。施放后移动不转移已写入的本战增益。
- Astrolabe、Dock Lines、Fishing Net 没有来源空间关系，不强加相邻线。

空间关系仍需自动站位固定种子模拟。若四宠自动布局长期无法形成可操控关系，必须回到主策层复审，不允许实现层暗改成技能条邻位。

#### Honing Steel：单 Weapon 保留两次独立 application

身份组初稿曾建议同目标去重，数值组也倾向为峰值安全去重；战斗组反对。主审采用来源保真：

- Deep 是 `extreme_left` 与 `extreme_right` 两个 operation，不是“最多选择两个不同目标”。
- 只有一只 Weapon 时，它同时是左右极值；同一 root 下产生两个 operation_id、两个 application，target_id 可相同。
- 不能由事务层自动去重改变机制；双命中通过冷却、成长量、单回合峰值和十二回合累计预算控制。
- UI 从牦牛两角绘制两条独立火星线，汇聚时显示“左右双锋 ×2”；不能表现为重复施法或第二个技能提交。
- 最小断言：0 Weapon=`NO_EFFECT_TARGET`；1 Weapon=2 operations/2 applications/同 target；2+ Weapon 按 `(x,y,unit_id)` 稳定冻结；战后清除两条本战 modifier。

#### Astrolabe：允许自目标，但必须改变事务顺序

来源 Deep 未排除自身。为让“催动自身”在本地有实际含义，保留自身为候选，但不是沿用当前“效果后启动冷却”的顺序：

1. prepare 全部目标与修改量；
2. 原子预留/写入自身本次 A 冷却；
3. 执行催动 applications，包括可能的自身；
4. 成功后发布 `SKILL_COMMITTED`，失败整包回滚。

这条顺序只能由通用 support/cooldown 事务支持，不能为 Astrolabe 写特例。被动文本的 `another non-Weapon` 明确排除自身；Multicast/多段不增加被动推进次数。若通用事务无法安全支持预留冷却，则暂时禁用自目标并标 `SOURCE_SCOPE_CUT`，不能让它随机选中自身却产生零效果。

#### Custom Scope：一件 Weapon 等于一只来源宠物，不等于一个技能

- 一对一转译中，一件 item 对应一只宠物；“恰好一个 Weapon”按 `BATTLE_ROSTER_LOCKED` 中具 Weapon 来源/正式战斗标签的宠物 ID 计数，不能把 A/B 当两件 Weapon。
- 正右关系只决定谁获得 Crit aura；唯一 Weapon 构筑条件可以由不在右侧的 Weapon 满足。
- 一次 root 内无论多少 packet、目标或 critical application，推进至多一次。
- 当前 Crit 判定管线可复用，但必须增加通用 `CriticalOutcomeAggregator`；DamageResolver 不得反向认识 Custom Scope。

#### Diving Helmet：来源标签投影与元素分离

- 相邻对象获得的是本战 `source_aquatic` 派生标签，不是水元素、不改变物种/图鉴/商店永久标签，也不自动赋予所有宠物。
- 关系快照先建立，再计算 combat tag projection；天然与派生 Aquatic 的成功 root 都可触发。
- 来源移动、死亡或 exit 后立即撤标签与监听，不把已经提交的 leader Shield 回滚。
- 每 root 只触发一次 Shield，子 packet、Multicast 和派生标签变更不递归发布技能使用。
- `LeaderCombatantState` 未完成前暂停，不得改成给泡盔蝾螈自身护盾。

#### Fishing Net / Fishing Rod：两个独立的外部奖励合同

共同权威时序：

```text
DAY_STARTED_COMMITTED
-> freeze eligible pool + deterministic seed
-> acquisition proposal
-> inventory or pending-reward commit
-> provenance + transaction id
```

- Fishing Net：按公开文案解析为跨英雄 `((Small AND Aquatic) OR Loot)` 专属池；若 Loot 是否也受 Small 限制的服务器规则无法从 Deep 证明，保留 `LOOT_SIZE_SCOPE_PENDING`，不得由实现层自行缩池。池为空 fail closed，不能替成金币、Piranha 或 Vanessa-only。
- Fishing Rod：独立 `Small Aquatic` 白名单；当前来源未证明“任意英雄”，不能与 Fishing Net 共池或从其规则类推。
- 两者都不是战斗召唤、技能连发、临时宠物或身体组成；不发布 `SUMMON_CREATED`，不占格。
- 同 `day_event_id` 幂等一次；容量不足进入统一待领取协议，不自动出售、不部分发放、不因读档重发。
- 记录 `acquisition_kind=grant`、`paid_cost=0`、来源宠物、原池、来源英雄、日数与 RNG 结果；免费获得不是购买，不能触发 Coral/Ambergris 的 PURCHASE 监听。

### 成长轴与风险门禁

- Astrolabe：品质只扩催动目标数；不同时增长催动量、被动推进和自身冷却。
- Captain's Wheel：品质只增长催动强度；不扩邻接数量、不改变 Vehicle/Large 条件。
- Custom Scope：品质只增长 Crit 光环；不同时增加推进量、目标数或 root 触发次数。
- Diving Helmet：品质只增长 Shield 效果；不扩大 Aquatic 邻接范围、不加入自身成长。
- Dock Lines：品质只增长目标数；阻滞强度/持续与冷却不作为第二成长轴。
- Fishing Net：战斗品质只增长阻滞目标数；奖励数量、品质与池范围不随本地品质成长。
- Fishing Rod：来源各品质循环相同；不得擅自增加目标数、奖励数或池范围。
- Honing Steel：品质只增长每次本战 DamageAmount；不改变极值几何、operation 数或冷却。必须专测 `Multicast × 双 operation × 12回合` 累积。

本轮不写任何本地正式数值；来源秒数/品质只保存在来源事实列。

### 第 13 轮通用模块补充

P0：

1. `SupportSkillExecutionPolicy`：为 `support/support_bundle/passive_only` 建立不经过 attack option 的正式入口；攻击技能继续走现有路径。
2. `SkillCooldownService`：冷却唯一写者，提供 `start/set/add_remaining/subtract_remaining/query`、clamp、日志、回撤与 no-effect 结果；RoundLifecycle 只调用它推进。
3. `BattleEventEnvelope`：统一 `root_action_id/packet_id/operation_id/application_id`，定义冷却预留、提交事件与反应队列的精确顺序。
4. `RelationSnapshot + CombatTagProjection`：空间关系不耦合自动站位器；派生标签不复用普通 status，也不写回基础内容。
5. `LeaderCombatantState`：统一 leader HP/Shield/status；Diving Helmet、Turtle Shell、Life Preserver 等共用，不建宠物专属服务。

P1：

6. `TaggedSkillTargetResolver`：按宠物的 `tempo_anchor_skill_id`、来源/战斗标签与稳定关系查询，不盲扫 A/B。
7. `CriticalOutcomeAggregator`：汇总一个 root 内的通用 Crit 结果，并保证确定性 event seed；Custom Scope 只是消费者。
8. `SkillParameterModifierLedger`：按 `unit_id + skill_id + effect_parameter + source_operation_id` 保存本战修饰；Honing Steel 不直接改单位 ATK 或 catalog。
9. 在现有 Run event operation registry 中扩展 `GrantRewardFromPool`、pending reward 与 acquisition provenance；不新建平行经济引擎。
10. `ContentDependencyValidator`：Fishing Net/Rod 奖励池、标签谓词或外部对象缺失时 fail closed。
11. `ControlSaturationPolicy` 扩展到技能剩余冷却阻滞，提供 Boss 抗性、单 root/单回合上限与最低行动出口。

### 非战斗策划补充

- **商店/获取**：每日生成池需 ID、来源英雄、标签谓词、解锁、品质、权重、容量、溢出和重复规则。
- **经济/合成**：免费物必须记录实际成本与来源批次；出售、复制、合并、升级和自动合成不得伪装购买或形成退款套利。
- **图鉴/教程**：说明 Weapon/Aquatic/Vehicle/Large 是来源或战斗标签，不等于技能数量、元素、宠物体型或格子面积。
- **UI**：显示回合锁定关系、正右箭头、唯一 Weapon 条件、左右极值/双锋、本战成长、冷却变化和每日奖励领取状态；图标与连线双编码。
- **AI**：估价被动槽位、邻接保持、唯一 Weapon 构筑、冷却净推进、单 Weapon 双极值和免费物溢出价值。
- **存档/回放**：保存日常奖励事务戳、生成 RNG/provenance、关系快照、派生标签、本战参数成长、冷却和 Crit root 结果；回撤/读档不得重复触发。
- **QA**：固定种子覆盖 1/5/12 回合、无目标、死亡/移动/exit、Multicast、多段 Crit、单 Weapon 双极值、满背包、跨英雄池、重复合成、replay/stateHash。
- **美术**：八项均禁止“器械加眼睛”；所有功能由动物身体结构自然产生。关系 VFX 不得成为碰撞体或额外身体。

### 第 13 轮最终三档与进度

- 可进入无数值骨架：Dock Lines。
- 带硬门禁后进入骨架：Astrolabe、Captain's Wheel、Custom Scope、Fishing Net、Fishing Rod、Honing Steel。
- 暂停机制定案：Diving Helmet，等待 `LeaderCombatantState + CombatTagProjection`。
- 本批不引入：Aim、Ammo、Reload、Freeze 基础机制。

八项最终暂名：星仪天蛾、舵尾海鳄、聚瞳蜻蜓、泡盔蝾螈、缆须藤壶、网囊鹈鹕、钓丝水黾、砺角牦牛。全部保留器械载具主类。

累计已有 58/138 个 Vanessa 原生对象完成逐项身份、事件骨架、来源证据、代码依赖、成长轴和风险审阅。主类计数保持海兽24 / 舰炮55 / 器械25 / 船体13 / 奇物10 / 自然11；Pontoon 跨英雄草案另计时器械26、总草案139。

下一批器械载具建议审阅：Integrated HUD、Lighter、Oni Mask、Powder Horn、Ramrod、Rowboat、Sextant、Shipwreck；继续优先处理可见空间、来源标签、冷却/弹药、局外奖励和本战成长，不填正式数值。

## 第 14 轮：器械载具批次 B 独立提案与交叉复审

本批八项：Integrated HUD、Lighter、Oni Mask、Powder Horn、Ramrod、Rowboat、Sextant、Shipwreck。旧映射锚点依次为 `pal_061`、`pal_071`、`pal_081`、`pal_091`、`pal_094`、`pal_098`、`pal_104`、`pal_107`；不交换正式 ID，不继承旧宠的统一先锋/侧击技能。

### 来源页、版本和 card ID 分歧

本轮三组都直接核对 BazaarDB 的 public、Deep Mechanics 与 History，但同名对象出现不同 card ID、地区镜像和缓存页头。战斗组/身份组取得的一组 17.2 首选 ID，与数值组及普通搜索抓取取得的另一组 ID 部分不同；公开循环和 Deep 主能力一致，没有发生机制内容冲突。

主审不以多数表决或“ID看起来更新”为理由覆盖证据，采用以下审计口径：

- 稳定对象键先用 `bazaar:vanessa:<canonical_slug>`，card ID 作为带版本和证据的 observed identifier，不作为永久唯一版本权威。
- 每次抓取保存 `observed_url`、`observed_card_id`、`observed_at`、观察者、数据库 patch 页头、卡内 As-of 页头、重定向链、HTTP 缓存年龄、public 文本签名、Deep 文本签名和证据路径。
- alias 状态至少区分 `preferred_current`、`redirect_alias`、`historical_snapshot`、`stale_cache`、`suspected_duplicate`、`contested`。
- ID 不同但同 patch 的 public/Deep 内容签名一致，记 `ID_ALIAS_CONFLICT_CONTENT_EQUIVALENT`，机制审阅可继续；若 public 或 Deep 有实质差异，记 `SOURCE_CONFLICT_STOP`，暂停该行，不能退回 BazaarWinner 缓存或搜索摘要。
- 本轮首选观察 ID 为 HUD `48c4...`、Lighter `9kp...`、Oni `7bq...`、Powder `l9qm...`、Ramrod `eyxe...`、Rowboat `bhl...`、Sextant `17p...`、Shipwreck `dvu...`；同时保留 HUD `c6cy...`、Oni `mdc...`、Powder `8aq...`、Rowboat `3yx...`、Sextant `e890...`、Shipwreck `16st...` 等观察 alias。它们只表示本轮证据关系，不声称永久唯一。

| 对象 | 当前高置信机制事实 | 本地旧表/缓存纠错 |
|---|---|---|
| Integrated HUD | Silver、Small、Apparel/Tech；右侧对象获 Crit；右侧对象暴击后 Slow 一个敌方有冷却对象 | 核心一致；本地必须补 passive-only 和真实棋盘右邻，不得读取技能条邻位 |
| Lighter | Bronze、Small、Tool；带冷却主动使用后对 opponent 施加一次 Burn operation | 基础无 Ammo、开战触发或攻击伤害；附魔能力不进入本体 |
| Oni Mask | Silver、Medium、Apparel/Tech；主动 Burn；任意己方对象 Crit 后，所有 Burn-tag 技能本战成长 | 旧 `Slow -> Charge self` 已删除；属性表残留 Charge 字段是孤儿数据，不得复活旧能力 |
| Powder Horn | Bronze、Small、Tool；主动 Reload 正右侧 Ammo 对象 | 只装填右侧一个显式 ammo anchor；基础无 Crit 与 Multicast |
| Ramrod | Bronze、Medium、Tool；主动 Reload 相邻 Ammo；每个实际成功 Reload 的目标获得本战 Crit 成长 | 旧 CSV 的固定 1/2/3/4 Ammo 已过时；当前近似满装填语义，成长不是给装填者 |
| Rowboat | Gold、Medium、Aquatic/Vehicle；主动 Charge 相邻有冷却对象；品质差异主要落自身 CD | 旧“拥有7种类型时减自身 CD”已删除，不能保留；基础不是 Haste 状态 |
| Sextant | Silver、Medium、Aquatic/Tool；其他对象 Crit 后 Haste 一个对象；成功 Haste 后随机可 Crit 技能获本战 Crit | 两条 Deep 触发域必须分开；不是无限反馈，也不按 packet 重复 |
| Shipwreck | Diamond、Large、Aquatic/Vehicle/Property/Relic；Aquatic 且有 CD 的主动技能 `+1 Multicast` | 当前来源没有 Spawn、Destroy、自毁、死亡奖励、战后奖励或经济产物 |

来源基础机制与附魔继续完全分栏。`primary_enchant` 只保留为来源证据，不能把 Freeze、双 Burn、额外 Crit、免控或 Weapon 伤害灌入本体。

### 正式代码只读审计

- `critical_damage_consumer.gd` 当前把 `critical` 与 `critical_roll` 留在单次伤害 context；随机种只基于 `event_seed` 后缀。跨宠被动需要 root/action/packet/application 身份和统一 `CriticalOutcomeAggregator`，不能让每个宠物监听伤害细节。
- `SkillExecutionService.execute()` 当前单次执行 `begin -> effects -> finish -> start_skill_cooldown`，即使 effect 返回失败也会继续 finish 并启动冷却；尚不具备 staged plan、整包回撤、多 packet 或 support 专用事务。
- `EffectHookIds` 没有 Crit-root、Ammo、Reload、Burn、Multicast 或 UnitExit 的正式事件词；不能用现有 `AFTER_SKILL` 猜测实际弹药增量或暴击次数。
- `RoundLifecycleService` 只通过 port 固定 tick 技能冷却；现有 Haste/Slow status 改 speed，不是 Charge/Haste/Slow 对剩余冷却的唯一写者。
- 空技能数组仍会由 `SkillQueueService` 注入 `basic_attack`；HUD、Sextant、Shipwreck 必须有显式 `passive_only` 执行档案，不能靠 `skills=[]`。
- 当前未发现完整 Ammo/Reload、Burn 持续结算或整包 Multicast 权威服务。三类机制都必须进入正式 GameSession/Command/Result/Trace/Snapshot 链，不能保存在表现层。

### 八项身份方案与轮廓防撞

共同默认：`proper_name=false`、`unit_count=1`、`body_count=single`、`source_friend=false`。多足、分节、左右动作、水醒和星轨都不是多身体。

| 来源 / pet_id | 最终暂名 | 身体与动作锚点 | 旧底稿边界与禁用直译 | 主类 |
|---|---|---|---|---|
| Integrated HUD / `pal_061` | 光瞳耳狐 | 低伏耳狐，巨大耳膜与复眼形成侦测阵列；右眼向同排正右技能徽记投一条细锁定线 | 可留旧犬科低姿、巨耳与蓝色电路光；禁外戴HUD、屏幕加眼、激光伤害数字 | 器械载具 |
| Lighter / `pal_071` | 燧牙鼩 | 小型鼩鼱以矿化门齿咬合擦火，长吻向敌 leader 的 Burn 槽送出火星 | 仅留旧暖色火星；删壁虎骨架。禁手持打火机、冲刺咬敌、攻击格与即时火伤 | 器械载具 |
| Oni Mask / `pal_081` | 鬼面角蝉 | 前胸背板天然形成双角鬼面；主动压火，被动时鬼面纹点亮并向 Burn-tag 技能送出同源火纹 | 删鹿体、花枝和外戴面具。禁悬浮面具、多鬼影、Slow→Charge 残影与面具爆炸 | 奇物谋略 |
| Powder Horn / `pal_091` | 硝角蟾 | 单角蟾的中空鼻角与膨胀喉囊向正右 Ammo 技能输送硝粉 | 删龙龟壳体；只留紫金颗粒。禁喷毒、开炮、爆炸、外背粉桶或左右扩散 | 器械载具 |
| Ramrod / `pal_094` | 填膛啄木鸟 | 竖直攀附，长喙作为活体通条，按成功 application 分别敲实左右弹仓 | 鹿体全删，只留蓝金色板。禁啄敌、伤害数字、把左右两次表现成攻击连段或 Multicast |
| Rowboat / `pal_098` | 桨尾鸭嘴兽 | 单只低长鸭嘴兽，四蹼与宽尾分别向左右划出水醒，推进邻宠冷却 | 删驼峰、货物和鞍具。禁船加脸、乘客、独立船桨、拖船召唤物或击退表现 |
| Sextant / `pal_104` | 星纬蛇颈兽 | 小躯四鳍、单根直长颈与两片月牙星鳍；表现 Crit定位→Haste→未来Crit成长的两段星线 | 删犀角和重甲四足。禁手持六分仪、星光攻击、星体分身和无限弹跳 | 器械载具 |
| Shipwreck / `pal_107` | 残桅海百足 | 一条连续分节海百足，背棘像断桅、侧肋像船骨；被动只点亮合法 Aquatic 技能的双水醒 | 可留云螭盘曲与幽蓝尾迹，删龙头翼角。禁沉船加眼、残骸群、幽灵船、Destroy/碎裂/召唤动画 | 自然异象 |

Oni Mask 迁奇物谋略、Shipwreck 迁自然异象只改变 `identity_family`、图鉴货架和美术语汇。硬边界为：

```text
identity_family / art_theme != source_types != combat_tags != execution_mode
```

Oni 不因迁奇物自动获得 Relic、Property、诅咒、开战触发或 Destroy；Shipwreck 不因迁自然丢失来源 Aquatic，也不自动获得自然元素、生成或经济能力。若现有数据链从 identity family 自动派生 combat tags，两项必须暂停正式骨架，先拆耦。

迁类后 canonical 138 主类计数为：海兽伙伴24 / 舰炮兵器55 / 器械载具23 / 船体据点13 / 奇物谋略11 / 自然异象12。Pontoon 跨英雄草案另计时器械载具24、草案总数139。

### 八项战斗骨架、事务粒度与风险

| 对象 | 本地执行骨架 | 粒度与门禁 | 阶段风险 |
|---|---|---|---|
| Integrated HUD | `passive_only`；正右宠物的显式 `crit_capable_skill_ids` 获 Crit；其 root 出现暴击后随机阻滞一个敌方 tempo anchor | Aura 持续；Slow `once/root`，多段/范围/Multicast不乘；来源移动、死亡或退出立即断链 | 红 |
| Lighter | `support` 单 A：对敌 leader Apply Burn；B/被动空、`cells=[]` | 一 root 预留一次 AP/CD，每 packet 一个 Burn application；Multicast 增 packet，不增 root | 深红；可先做无数值纵切 |
| Oni Mask | `support + passive`：A 对敌 leader Burn；任一友方 critical root 后批量增长所有 Burn-capable 技能的后续 Burn 参数 | 被动 `once/root`；modifier 从下一 root 生效，不回溯本次 Crit；批量写入失败整包回滚 | 深红 |
| Powder Horn | `support` 单 A：Reload 正右宠物声明的 `ammo_anchor_skill_id` | 无右邻、非Ammo或已满均在提交前 `NO_EFFECT_TARGET`；不能恢复 AP/冷却代替弹药 | 红；Ammo服务前暂停 |
| Ramrod | `support_bundle + passive`：左右各一个 Reload operation；每个成功 Reload application 给实际目标写本战 Crit modifier | `delta_ammo>0` 才发事件/成长；同 root 两个真实成功 application 不去重，只以 event_id 防重放 | 深红；Ammo/Reload前暂停 |
| Rowboat | `support_bundle`：对左右相邻的 `tempo_anchor_skill_id` 减少 remaining cooldown | 最多两 application；至少一项目标实际变化才提交；Charge不是speed Haste，也不减最大CD | 红 |
| Sextant | `passive_only`：其他友方 root Crit 后催动一个合法目标；同 root 首次成功 Haste 后令一个可Crit技能获本战 Crit | 两消费者分别按 `(consumer,event_kind,root)` 一次；成长从下一root生效，modifier不再发布Crit/Haste | 深红 |
| Shipwreck | `passive_only`：为 `Aquatic AND cooldown_max>0 AND multicast_eligible` 的主动技能 `+1` 完整效果包 | 一次 skill root/AP/CD/Ammo spend；额外 packet 不发新 SKILL_USED；不扩大形状，不只重复伤害 | 深红 |

三个 passive-only 宠物仍占一个正式宠物位、一个棋盘身体格，可以被选中、移动、击败和退出，并承担完整阵容机会成本；它们不占共享技能条、不产生隐藏主动锚点、不消耗技能行动。来源退出后停止影响未来 root，已经入队的 packet 不回滚。

### 空间关系对质：撤回共享技能条方案

数值组初稿一度把 HUD、Powder Horn、Ramrod、Rowboat 的左右关系锁到共享技能条。战斗组和身份组反对；数值组交叉复审后正式撤回。最终关系是：

- Integrated HUD、Powder Horn：`board_same_row_immediate_right`。
- Ramrod、Rowboat：`board_same_row_immediate_left + board_same_row_immediate_right`。
- 立即相邻表示同一棋盘行、占地边界贴合；不能隔空寻找下一只宠物，也不能读取共享技能条顺序。
- root prepare 时解析并冻结目标到该 root 结束；移动只影响后续 root。目标死亡、退出或断开后不自动滑动补位。
- 关系先找到宠物实例，再绑定内容声明的主技能 anchor；不能在该宠物 A/B 中临时挑收益最高者。

棋盘关系降低平均链接率，却不降低峰值；移动、击退和补位还会改变后续 root。预算因此采用“满链峰值 + 实际链接率”双轨，而不是因站位条件直接降风险色。必须用正式自动站位规则固定种子测试关系出现率。

### Ammo / Reload 权威合同

Ammo 玩家词仍为“弹药 X/Y”，是一份按 `skill_instance_id` 保存的单场战斗资源账本，不复用 AP、冷却或宠物重置次数。

```text
BATTLE_ROSTER_LOCKED
-> 冻结 combat tag / skill instance / relation 声明
-> BATTLE_STARTED 前初始化 ammo_current / ammo_max
-> root preflight 解析关系、技能anchor、AP/CD/Ammo与正增量候选
-> root reserve 只扣一次 AP、主动CD和本次Ammo spend
-> staged Reload operations 计算 before/after/delta
-> 原子 commit
-> 按稳定顺序发布 AMMO_RELOADED applications
```

- 使用 Ammo 技能时，root 预留阶段只扣一次弹药；Multicast 子 packet 不再扣。
- Reload 计算 `delta=min(requested, max-current)`；只有 `delta>0` 才形成 `AMMO_RELOADED` application。
- 事件必须包含 `root_id/packet_id/operation_id/application_id/source_skill_instance/target_skill_instance/before/after/delta`。
- `RELOAD_ATTEMPTED` 与 `AMMO_RELOADED` 分离；clamp=0 不是成功 no-op，不能触发 Ramrod 成长。
- Ramrod 每消费一个真实 application，就给该 target skill 一次成长。同 root 两目标各成功、或同目标被两个独立 operation 实际恢复，均是两次；只用唯一 event_id 保证回放/回撤幂等。
- 任一 operation 或强制下游效果失败，Ammo、AP、CD、modifier 和待发布事件整 root 回撤。
- 跨回合保留；同战复活原 skill instance 恢复原账本，新召唤实例重新初始化；战斗结束丢弃。save/stateHash/replay/rollback 必须包含账本和事件序号。
- 自动技能条必须识别“目标满弹导致零恢复”的依赖等待，不能每帧或每轮无意义重试。

### Crit、Sextant 与本战参数成长

- HUD 和 Oni 消费的是“一个技能 root 内至少一个 critical application”的汇总事实，每个消费者每 root 一次；不是按伤害段、格子、目标或 packet 触发。
- Ramrod 是明确例外：它消费 Reload application，而非 Crit root，因此按实际正增量次数成长。
- Sextant 允许同一 root 的合法两步链：`CRIT_OCCURRED -> HASTE_APPLIED -> FIGHT_CRIT_GROWTH`。限次键为 `(consumer_instance_id,event_kind,root_id)`，不是“一整个 root 只能发生一种效果”。
- Sextant 第一步没有合法 Haste 目标或 Haste 未实际应用时，不产生第二步成长。Crit modifier 只影响后续 root，不重新掷本次 Crit，也不发布新的 Crit/Haste 事件，反馈链在第二步终止。
- Oni 的批量成长只写 `burn_capable_skill_ids` 的 `BurnApplyAmount`，包括自身 A；不写 pet ATK、元素层或所有技能。来源死亡/退出后停止新触发，已提交的本战 modifier 保留到战斗结束。

### Shipwreck 连发合同与明确反对项

本地资格：

```text
source_alive
AND owner.combat_tags contains Aquatic
AND skill.cooldown_max > 0
AND skill.multicast_eligible = true
```

前两项来源于当前 Deep，`multicast_eligible` 是本地安全裁剪，必须放在 `local_adaptation` 而非来源事实列。只有 repeat-safe 的主动核心效果包才能标记；死亡、Destroy、生成、局外奖励、永久成长、再次排队技能或新的 skill-use root 默认禁止。

一次施放预留一次 AP/CD/Ammo，冻结 `1+bonus` 个 packet；每 packet 独立记录 operation/application，但不新增 root 或 SKILL_USED。直接形状目标默认在 root 冻结；随机 support 目标可用 `packet_index` 派生确定性子种。Shipwreck 执行中死亡不回滚已经入队的 packet，只影响后续 root。

`REJECTED`：Shipwreck 因名称获得 Destroy、自爆、沉船、残骸召唤、幽灵船、死亡奖励、战后奖励、Property 经济或 Relic 效果。来源没有这些机制，身份美术也不得用碎裂/退场演出暗示它们。

### 成长轴和生产分档

- HUD：本地品质只增长右邻 Crit aura；Slow 目标数、持续和触发次数固定。
- Lighter：只增长 BurnApplyAmount；CD、范围和 packet 结构固定。
- Oni：来源同时有基础 Burn 与 Crit 后成长两轴；若本地保留双轴，就不能再缩 CD、扩范围或增触发次数。
- Powder Horn：只增长 ReloadAmount；目标固定正右一个。
- Ramrod：只增长每个成功 Reload 的本战 Crit；Reload 目标固定左右两个，不能再加 Multicast/目标数。
- Rowboat：只让品质改变自身冷却；Charge量和两侧目标数固定，删除 unique-types 条件。
- Sextant：只增长 HasteAmount；每次 Crit 成长量、目标数与触发次数固定。
- Shipwreck：额外 packet 固定 `+1`；本地品质不能继续增加层数。低品质阶段是否不开机制，由成长阶段另行裁决。

阶段分档：

- 可作低依赖无数值纵切：Lighter，但仍需 Leader/Burn 权威层；“低依赖”不等于低数值风险。
- 带硬门禁后进入骨架：Integrated HUD、Oni Mask、Rowboat、Sextant、Shipwreck。
- 暂停正式机制：Powder Horn、Ramrod，等待 Ammo/Reload 权威服务和事件合同。

### 第 14 轮通用代码模块补充

P0：

1. 继续扩 `BattleEventEnvelope`：正式支持 root/packet/operation/application 四级 ID、因果路径、提交后发布和回撤丢弃。
2. 继续扩 `SupportSkillExecutionPolicy` 与 staged atomic bundle：无 attack option 的 support/support_bundle 正式入口；预检、预留、提交、失败回撤统一。
3. `PassiveOnlyCombatantPolicy`：被动单位仍是完整棋盘实体，但不生成技能条项目或隐藏主动。
4. `RelationSnapshot`：同排左右即时关系、root prepare 冻结、死亡/移动/UnitExit 断链；与技能队列顺序完全解耦。
5. `SkillCooldownService`：Charge/Haste/Slow 对 remaining cooldown 的唯一写者，负责 clamp、富结果、日志、回撤和最低行动出口。

P1：

6. `AmmoResourceService / BattleAmmoLedger`：按 skill instance 管理初始化、spend、reload、查询、存档和回放。
7. `ReloadOperation`：只在正增量时发布 application 级事件；不与 skill use、Haste 或 AP 混用。
8. `CriticalOutcomeAggregator`：扩展当前 `critical_damage_consumer` 输出，汇总 root 事实；不复制第二套 Crit 判定器。
9. `SkillParameterModifierLedger`：按 source operation 保存本战 Crit/Burn 参数成长、有效起始 root 与清理时点；接现有 modifier collector/hook pipeline。
10. `BurnLedger / BurnResolver`：leader Burn 的唯一账本、结算、净化、上限、Trace 与 Snapshot；通用 status duration 不能替代它。
11. `MulticastExecutionPolicy`：扩现有 SkillExecutionService/SkillEffectPort，重复完整 packet，不旁建第二条攻击链；强制技能声明 `multicast_eligible`。

P2：

12. `CombatTagSnapshot + SkillEligibilityResolver`：分开来源类型、战斗标签、身份分类和技能资格；禁止从美术主类自动派生战斗标签。
13. `DeterministicReactiveTargetSampler`：以 battle seed/root/source/passive/packet 派生稳定目标，支撑 HUD/Sextant 与回放。
14. `SourceIdentityEvidenceRegistry`：记录 observed card ID、alias、patch页头、抓取时间、内容签名与冲突状态，供导入迁移和来源审计；不进入战斗权威。

推荐实现顺序：事件信封+support事务 → Passive/Relation → Cooldown → Crit聚合+参数账本 → Ammo/Reload → Leader/Burn → Multicast → 八项内容。全部做成可复用模块，不给单宠写平行服务。

### 非战斗策划与验收补充

- **商店/图鉴**：来源 `Apparel/Tech/Aquatic/Vehicle/Property/Relic`、本地 `identity_family`、元素和战斗标签分列；迁类不自动改掉落池或稀有度。被动宠也按完整宠物槽估价。
- **UI**：选中时高亮棋盘左右链接；HUD/Oni/Sextant 共用 `root_response_consumed` 小标记；Ramrod 先显示 Ammo 实际增量再显示 Crit 成长；Shipwreck 的“双水醒”挂在合格技能入口而非宠物头像。
- **表现**：support 不显示攻击格、受击抖动或即时伤害数字；passive-only 只在真实事件后短响应。两 operation、两 packet、多目标和多身体使用不同视觉语法。
- **AI**：估算链接有效率、满弹空转、Reload 后可兑现的技能次数、Crit/Burn 长局复利、Sextant 闭环和 Shipwreck 复合包峰值；不能只看单次面板。
- **教程**：分别解释弹药/装填、催动/阻滞、连发、被动宠槽位机会成本；明确 Multicast 不新增 AP、冷却或技能条项目。
- **存档/回放**：保存 Ammo ledger、event_id、关系快照、root消费者去重、本战参数 modifier、packet 数和 source alias 审计版本；回撤与读档不得重复成长。
- **QA**：固定种子覆盖 1/5/12 回合、多段 Crit、Multicast、左右链断开、0/1/2 Reload 目标、clamp0、外部 Reload、Crit上限、来源中途退出、Leader缺失、复合包全重复及 stateHash 一致。

### 第 14 轮阶段闭环与进度

八项最终暂名：光瞳耳狐、燧牙鼩、鬼面角蝉、硝角蟾、填膛啄木鸟、桨尾鸭嘴兽、星纬蛇颈兽、残桅海百足。

累计已有 66/138 个 Vanessa 原生对象完成逐项身份、事件骨架、来源证据、代码依赖、成长轴和风险审阅。主类计数更新为海兽24 / 舰炮55 / 器械23 / 船体13 / 奇物11 / 自然12；Pontoon 跨英雄候选另计时器械24、草案总数139。

下一批建议用 7 项收束剩余器械载具：Stealth Glider、Submersible、Suppressor、Spyglass、Star Chart、Weather Glass、Wetware。Pontoon Skimmer 继续作为跨英雄第139草案单列，不挤占原生138，也不占已绑定 Alacrity 的 `pal_139`。

## 第 15 轮：剩余器械载具收束

本批七项：Spyglass、Star Chart、Stealth Glider、Submersible、Suppressor、Weather Glass、Wetware；旧 ID 锚点依次为 `pal_114`、`pal_115`、`pal_116`、`pal_118`、`pal_119`、`pal_135`、`pal_136`。三组只读核对当前来源、旧 CSV 与正式代码，不交换 ID、不写本地正式数值。

### 当前来源与三次纠错

| 对象 | 本轮 17.2 观察 ID / 当前循环 | 旧资料与分歧处理 |
|---|---|---|
| Spyglass | `v486y1hpmv9ny6qjx2ndc8fgnb`；开战随机增长一个敌方主动技能的本战冷却；每个成功 Slow root 后随机一个可暴击友方技能获本战 Crit | 旧 CSV public 循环一致；来源 Deep 含 stash，本地没有战斗 stash，明确裁剪为活动部署宠物 |
| Star Chart | `g72qhm78wwb9ml7lfgj1lhtj0s`，另观察到同内容 `5de...`；相邻对象获得 Crit 与百分比 CDR 两条 aura | 继续使用第14轮 alias 审计；本地二维相邻与叠加方式必须独立裁决 |
| Stealth Glider | `jq4h4x8mkkdhzc5qxjb9b3wxv4`；主动令随机未 Flying 对象开始 Flying；固定 player 减伤；Flying 对象获得 flat CDR | `REJECT_OLD`：旧“每个其他 Flying 提供10%减伤”已删除；当前是固定减伤并新增 Flying 全局冷却效率 |
| Submersible | `c47mkck7q7n1l37vcm4xskk7m9`；使用时分别强化左右极值 Aquatic Weapon 与 Aquatic Shield；另有 Vehicle/Large 时自身 CDR | public 一句话不能表达 Deep 四个独立 operation；本地不能合并成一次宠物级成长 |
| Suppressor | `g0cqnc4fzgb8y9c01d030skqq`；纯被动，左侧 Weapon 加 Damage；活动棋盘恰一 Weapon 时该对象获 CDR | `Silencer -> Suppressor` 是13.0历史改名，只记 alias，不算两件物品 |
| Weather Glass | `cefxncqnvcah6u9pld87estcq`，另观察到同内容 `12v...`；主动每 packet 同时 Burn、Poison；其他对象每满足 Burn/Poison/Slow/Freeze 一类各 `+1 Multicast` | 四类是四个独立 aura；不是按同类宠物数量叠加 |
| Wetware | `14qsk77js2vg9jpsk9fsk37d8pt`；主动 Shield player；任意成功 Shield root 后随机活动 Weapon 本战成长 Damage | `REJECT_OLD`：旧 Weapon-use→自身Shield成长、另有Tech→自身CDR 的整套循环已废 |

本轮还留下了一次完整误归属纠错：主审从 Vanessa merchant 索引读到紧邻条目的“Deal 100 Damage；只有一把 Weapon 时伤害倍增”，一度怀疑 Suppressor 已从纯被动改成主动攻击。数值组重新对齐卡片边界，战斗组再查 Suppressor 直页和 Deep 后确认，这两句属于相邻的 **Sniper Rifle**。三组同步撤回“Suppressor 主动攻击”预留；该错误不进入当前机制列，但保留在讨论过程，提醒后续不得用长商人索引的相邻文本代替单卡 Deep。

身份组最初把 Stealth Glider 写成“让一个对象开战获得 Flying”，战斗组复核后修正为“其主动 A 使用时，让一个未 Flying 目标开始 Flying”；开战时只注册固定 DR/CDR 被动，不免费改变目标状态。

### 七只身份与表现边界

共同字段：`proper_name=false`、`body_count=1`、`unit_count=1`、`lifeform=biological_fantasy`、`source_friend=false`。来源尺寸、来源类型、本地品质、身体数量与身份主类继续分列。

| 来源 / pet_id | 最终暂名 | 单体构造与机制动作 | 旧底稿复用、防撞与禁止直译 | 主类 |
|---|---|---|---|---|
| Spyglass / `pal_114` | 远瞳变色龙 | 高冠、双炮塔眼、卷尾；开战一眼锁敌方主动，Slow成功后另一眼给友方技能落焦点 | 留红金鳞色与聚焦光，删龙角、长蛇身与雷环；禁望远镜长眼、攻击射线 | 器械载具 |
| Star Chart / `pal_115` | 星航鸾 | 长颈、双大翼、分叉长尾；同排左右以星线连接，只显示 Crit/CDR aura | 朱雀骨架可高复用，火焰改靛蓝星羽；与星仪天蛾以长颈/长尾/尖羽翼防撞；禁冰冻表现 | 奇物谋略 |
| Stealth Glider / `pal_116` | 隐幕鼯鼠 | 四肢撑开整片菱形滑翔膜与扁尾；A提交后给目标落 Flying 翼影，身体暗幕表达 player DR | 删青鸾鸟喙、羽翼、凤尾与净瓶；禁飞行器座舱、不可选/闪避/移动暗示 | 器械载具 |
| Submersible / `pal_118` | 潜舵鲟 | 钝吻装甲鲟、左右舵鳍与双侧线须；两鳍向全盘左右极值发水平声呐 | 只留水带和青白对称光，删鹿头、四蹄和花角；禁潜艇加眼、邻接误导 | 器械载具 |
| Suppressor / `pal_119` | 噤响针鼹 | 低伏针鼹，长吻与中空吸音棘；棘阵只朝同排正左一格合拢，唯一Weapon时闭合静音环 | 留黑蓝月色，删九尾狐；与光瞳耳狐彻底拆种。禁消音管加腿、普攻读条 | 器械载具 |
| Weather Glass / `pal_135` | 四候虹蝎 | 单只宽钳弓尾蝎，四段变色尾节是四类标签状态灯；A一次甩出灼热与毒雾 | 蝎形高复用，金属装备改甲壳色素/气象纹；禁玻璃球加眼、把四尾节画成四次固定攻击 | 自然异象 |
| Wetware / `pal_136` | 脉盾沧熊 | 单头双足海熊，半透明神经活膜附着前臂；A形成盾，成功Shield后背脊脉冲跳向一把Weapon | 熊体与直立姿态可复用，机械拳套改活膜；禁湿衣服/脑罐加眼，零值Shield不得播成长成功 | 器械载具 |

Star Chart 迁奇物谋略、Weather Glass 迁自然异象只改变身份/图鉴/美术分类，不自动生成 Relic、元素、自然标签或掉落池。迁类后的原生138主类计数：海兽24 / 舰炮55 / 器械21 / 船体13 / 奇物12 / 自然13；Pontoon 草案另计时器械22、总草案139。

### 七项最终战斗骨架

| 对象 | execution_mode 与本地骨架 | 精确粒度、空间和停止线 | 阶段风险 |
|---|---|---|---|
| Spyglass | `passive_only`；BATTLE_STARTED 随机敌方 tempo anchor 获本战冷却增长；一个 root 有至少一次成功 Slow 后，随机一个可暴击友方技能获本战 Crit | Slow消费者每Spyglass每root一次；Multicast/多目标不乘；开战目标与成长目标固定种子，死亡后不重选 | 红 |
| Star Chart | `passive_only`；同排左右一格友宠的可暴击技能获 Crit，tempo anchor 获百分比 CDR | `board_horizontal_round_snapshot`；回合开始建链，移动/死亡/exit立即断，本回合新移入不补。多来源本地 `max_by_stat` | 黄，高品质转红 |
| Stealth Glider | `support + passive`；A令一个随机未Flying友宠进入Flying；P给player固定DR，并给Flying宠节奏锚点flat CDR | Flying只在 `false->true` 发关键词事件；允许选自身；全员已Flying时 `NO_EFFECT_TARGET`，不启CD、不发SKILL_USED。来源退出撤光环但不清他人Flying | 深红 |
| Submersible | `support_bundle + passive`；A本战增长左右极值Aquatic Weapon伤害与Aquatic shield-capable技能护盾；P在另有Vehicle/Large时修饰自身未来CD | 一root/一packet/四operation：damage_right、damage_left、shield_right、shield_left。唯一全能目标保留Damage×2+Shield×2共4 applications | 深红 |
| Suppressor | `passive_only`；正左一格Weapon技能获Damage；活动棋盘恰一Weapon宠时其tempo anchor获百分比CDR | Weapon按宠物实例计数，一宠多Weapon技能仍算一来源对象；左邻用二维棋盘，不读技能条；CDR只影响之后启动的新冷却 | 黄红 |
| Weather Glass | `support_bundle + passive`；A每packet先Burn后Poison；其他活动宠物的四类标签各为A增加一个完整packet | root prepare冻结排除自身的唯一类别集合K=0..4；同宠可贡献多类，同类多宠只算一次；所有packet共享一个root/AP/CD | 深红 |
| Wetware | `support + passive`；A Shield allied player；任一成功Shield root后随机Weapon技能本战成长Damage | 自身A可触发，但每root一次；无Weapon时A仍成功，被动reaction `NO_EFFECT_TARGET`而不回滚A；目标死亡后成长不转移 | 深红，机制暂停 |

三个来源空间合同：

- Suppressor：`board_same_row_immediate_left`，目标宠物再绑定显式 Weapon operation；不允许技能条左邻。
- Star Chart：`board_horizontal_round_snapshot`，只含同排立即左右；不是上下左右全邻域。
- Submersible：`board_global_horizontal_extremes`，按 x 选最左/最右；同列再按可见 y、稳定 unit_id 定序。不是相邻关系。

### Flying、极值、CDR 与来源等价操作

- Flying 是战斗内动态关键词，进入 Trace/Snapshot/stateHash，战斗开始重置；不是永久宠物标签，也不代表移动、闪避、不可选、变形、元素、形状或多身体。
- `BattleKeywordStateService.set(Flying)` 幂等；只有 `false->true` 发布 `KEYWORD_CHANGED/FLIGHT_STARTED`。重复设置不能喂给 Marlon、Jetbike 等消费者。
- Flying 留在宠物实例上供来源监听，但 Stealth 的 flat CDR **只作用每宠声明的 `tempo_anchor_skill_id`**。一件来源 item 对应一只宠物，不能因本地 A/B 双技能兑现两次来源冷却。
- flat/percent CDR 都只修饰之后启动的新冷却，不即时改写正在倒计时的 remaining cooldown；设统一下限与同 root 禁重入。
- Submersible 四个 Deep ability 是四个 operation，不在 target_id 层去重。某个技能同时满足左右极值、Weapon与Shield条件时，得到4条独立 parameter applications；UI用左右两束声呐和Damage/Shield两个参数徽记表现，不能播四次施法。
- Submersible 的稳定 operation 顺序锁为 `DamageRight -> DamageLeft -> ShieldRight -> ShieldLeft`。某类无目标只记 `SKIPPED_NO_TARGET`，不回滚其他有效 operation；任何非预期校验或写入异常则整个 staged packet 回滚，不能留下半份成长、冷却或事件。
- Vehicle/Large 条件排除 Submersible 自身，读取来源标签/来源尺寸，不拿本地身体格数替代。Shield成长只增强已存在的 Shield operation，不能注入新Shield技能。
- 每只宠物需声明一个 `source_equivalent_operation_id`/`tempo_anchor_skill_id`；否则同一来源item会被本地A/B、多个Weapon/Shield效果重复计算，内容校验必须fail closed。

### Spyglass 的开战控制与 Slow 消费

Spyglass 的“开战增加敌方 cooldown”是对目标技能本战最大冷却/冷却效率的参数修饰，不是普通 Slow status，也不是每回合追加 remaining。它在双方静态标签、技能锚点与冷却 modifier registry 准备完成后，以确定性系统 root 选择敌方目标；修饰只影响之后启动的新冷却。由于本项目技能通常开局 ready，这一转译不会阻止对方第一次技能，属于来源体验裁剪，必须在本地偏离列公开；若产品要保留首轮延迟，需另行批准“初始剩余冷却”规则，不能实现层偷偷补锁。

精确开战顺序锁为：`roster/tag lock -> 自动站位/方向完成 -> skill instance与tempo anchor初始化 -> battle-start目标快照 -> 多Spyglass按source_instance_id稳定序写参数modifier -> 首个可行动root`。它不是 SKILL_USED，不消耗 AP；多个 Spyglass 各自选择，目标死亡后不重选。

Slow 被动只消费 `net_delta>0` 的成功 Slow root；全免疫、全clamp或没有合法目标不成长。一个 root 内多个 Slow operation/application 仍只触发一次，下一 root 可以再次触发。来源 Deep 的 stash 域在本地裁剪为 deployed，RNG 结果进入 Result/Trace/replay。

### Star Chart 叠加裁剪

来源多个 Star Chart aura 通常可以自然叠加；本地为防四宠共享技能条下 Crit/CDR 阈值爆炸，采用 `max_by_stat`：同一目标同一 stat 只取最高 Star Chart 来源，不相加。必须分栏保存：

```text
source_stacking = additive_or_engine_aura
local_stacking = max_by_stat
deviation_reason = shared_skill_bar_crit_cdr_threshold_safety
```

这是一项明确本地安全裁剪，不得写成来源规则。Crit与CDR可随来源品质共同成长，但本地总预算必须合并审核，不能两轴各自吃满一次品质预算。

### Weather Glass 整包连发

`K_tag` 是其他活动宠物满足的唯一类别数，不是宠物数。root prepare 先冻结 Burn/Poison/Slow/Freeze 四个布尔条件，再产生 `1+K_tag` 个 packet；packet 内固定 `apply_burn` 后 `apply_poison` 两个 operation。标签在本次执行中变化不改变已冻结包数。

同一宠物可同时贡献多个不同类别，同一类别有多个宠物仍只贡献一次；自身的基础 Burn/Poison 标签不计。所有子包不新增 AP、冷却、Ammo或SKILL_USED，下游 Burn/Poison/Slow/Shield/Crit 等消费者仍按root默认一次。额外 Multicast 来源必须进入总包量门禁，不能在四类上限之外无限乘区。

### Wetware 与 Shield root

- 来源触发已经是成功 Shield，而不是 Weapon use；旧 CSV 两条机制全部撤回。
- A 写 allied player 的权威 Shield。`LeaderCombatantState` 未落地前，不得改成给Wetware自身或随机宠物护盾。
- 只有实际 Shield application 成功且 `net_delta>0` 才供 `RootApplicationAggregator` 汇总；满盾、免疫或clamp=0不成长。
- 自身 A 成功可在同 causal root 追加一次 reaction packet；Multicast或同root多个Shield application仍只成长一次。
- 随机目标仅限活动的来源等价 Weapon operation；无Weapon时只让被动reaction no-op，不能回滚已经成功的Shield主动，也不能延迟到未来补发。
- 随机成长写技能 `DamageAmount`，不写宠物基础ATK，不污染治疗、护盾或非Weapon技能；本战结束清除。

### 第 15 轮成长轴与准入

- Stealth：只让主动节奏随成长变化；固定player DR、Flying CDR和目标数不同时成长。
- Submersible：品质只增长Damage/Shield参数量；不增加operation数、目标数或标签创造。
- Suppressor：来源Damage与唯一Weapon CDR两轴交错成长；同一品质节点不能让两者同时吃满独立预算。
- Spyglass：来源主要成长开战冷却增长；每次Slow后的Crit成长量、目标数和触发次数保持结构常量。
- Star Chart：Crit/CDR双轴共用一个总预算；关系域、目标数和叠加方式不随品质改变。
- Weather：只缩短主动节奏；Burn、Poison、类别上限和operation数固定。
- Wetware：Shield基值与Weapon成长双轴共用预算；不增长随机目标数或每root触发数。

最终准入：

- 可进入无数值骨架：Suppressor、Star Chart。
- 带硬门禁后进入：Stealth Glider、Submersible、Spyglass、Weather Glass。
- 暂停来源忠实机制：Wetware，等待 LeaderCombatantState、Shield权威状态与root汇总。

### 第 15 轮通用模块补充

1. `BattleKeywordStateService`：Flying 等动态战斗关键词的幂等 set/has/clear、变更事件、清理和快照；与静态tag、status、位置分离。
2. `CooldownModifierRegistry`：flat/percent CDR、条件光环、来源退出回撤、后续启动冷却与统一下限；不直接写当前remaining。
3. `RootApplicationAggregator`：按root汇总成功的 Slow、Shield、Crit 等 applications，向消费者发布一次富结果。
4. `SourceEquivalentOperationContract`：一件来源item映射一宠时声明唯一Weapon/Shield/tempo anchor，阻止A/B重复兑现。
5. `BoardExtremeTargetResolver`：二维全局左右极值、同列tie-break、四operation冻结；不塞进普通相邻解析器。
6. `FightScopedModifierStore/SkillParameterModifierLedger`：保存Damage/Shield/Crit/CDR本战成长、有效期、来源operation与回撤。
7. `PassiveAuraRegistry`：被动宠占格/占阵容但不入技能条；安全注册、失效和来源退出撤销。
8. 继续复用/扩展 `RelationSnapshot`、`DeterministicTargetResolver`、`MulticastExecutionPolicy`、`LeaderCombatantState` 与 `BattleEventEnvelope`；不为单宠旁建服务。

### 非战斗策划与 QA

- **图鉴/导入**：显示 Suppressor 当前名，Silencer 仅用于搜索、旧存档迁移和审计；商人长索引必须按卡片边界解析，不能吞入相邻对象文本。
- **UI**：展示Flying关键词、DR/CDR光环、全局极值、唯一Weapon条件、Star Chart回合锁定线、Weather四类灯和Wetware随机成长目标。
- **AI**：评估被动宠槽位成本、极值站位、唯一Weapon构筑、Flying CDR、开战控制、长局成长和多packet总收益。
- **教程**：区分宠物静态tag、技能tag、战斗动态keyword；解释被动宠不占技能条却占宠物位，以及packet不等于新技能使用。
- **存档/回放**：保存Flying、随机目标、关系快照、本战参数modifier、root消费者去重与packet数；战后清除，回撤不重复消费。
- **固定种子QA**：1/5/12回合、0/1/2 Weapon、同一全能极值目标4application、Flying重复设置、来源死亡/exit、Slow/Shield全clamp、Weather 0..4类别、Multicast、冷却下限、镜像先后手和stateHash一致。

### 器械载具阶段闭环

本轮七只暂名：远瞳变色龙、星航鸾、隐幕鼯鼠、潜舵鲟、噤响针鼹、四候虹蝎、脉盾沧熊。

累计已有 73/138 个 Vanessa 原生对象完成逐项身份、机制、来源证据、代码依赖、成长轴和风险审阅。器械载具主类的21项均已完成；主类计数为海兽24 / 舰炮55 / 器械21 / 船体13 / 奇物12 / 自然13。Pontoon 跨英雄草案另计时器械22、草案总数139。

下一类进入自然异象剩余对象。先从未审对象中重建清单，排除已经在前轮完成的 Iceberg、Shipwreck 与 Weather Glass，再按触发族分批讨论，继续不填正式数值。

## 第 16 轮：自然异象批次 A

本批五项：Cannonball、Card Table、Chum、Clamera、Bonfire；旧 ID 锚点为 `pal_019`、`pal_022`、`pal_025`、`pal_026`、`pal_014`。批次名不强迫分类，身份组复审后 Cannonball 保持舰炮兵器、Card Table 保持奇物谋略，其余三项保持自然异象。

### 当前来源、版本和纠错链

| 对象 | 17.2 当前机制 | 旧表/别名纠错 |
|---|---|---|
| Cannonball | Silver、Small；纯被动，为全队已有 AmmoMax 的对象提高最大弹药 | 14.0 已从旧“相邻且更高增量”改成全盘；当前观察 ID 有 `51md...` 与同内容 `fc1y...`，按 typed alias 记录 |
| Card Table | Gold、Medium；主动随机令一个有冷却的 Friend 技能本战获得 Multicast | 旧“每个 non-Friend 令自身 CD 增长”已删除；当前无特殊经济机制 |
| Chum | Bronze、Small、Aquatic/Food；主动令全体 Aquatic OR Food 的可暴击技能本战成长 Crit；购买时获得 Piranha | 16.0 后 Food 纳入范围；Piranha 是固定内容赠品，不是随机池或召唤物 |
| Clamera | Silver、Small、Aquatic；主动 Slow；敌方前若干次正常使用后强制使用自身 | 旧“开战自动使用”已被当前战斗计数触发取代；观察到 `c2p...` 与 `46nx...` 同名页，继续按内容签名审计 |
| Bonfire | Silver、Medium；主动 Burn；成功 Burn 后 Haste 一个相邻可用对象 | `Flame Signal -> Bonfire` 是12.0历史改名，两个名字不得生成两个宠物或机制实例 |

本轮当前 ID 以 `Cannonball 51md... / Card Table tbqm... / Chum 117t... / Clamera c2p... / Bonfire zg4...` 作为首选观察值；同名旧/重复 ID 不自动合并，继续保存页头、抓取时间和 public/Deep 签名。只有 Bonfire 有已证实名称 alias，其余 `name_aliases=[]`。

### 五只身份与分类

| 来源 / pet_id | 最终暂名 | 身体结构与机制动作 | 复用、防撞和禁止直译 | 主类 |
|---|---|---|---|---|
| Cannonball / `pal_019` | 铁丸鼹 | 楔形低身、长吻、巨型铲爪和背部圆矿结；持续掘出矿丸化为全队弹仓容量刻度 | 高复用旧鼹骨架，雷电/战斗爪套改矿结；禁炮弹加眼、炮口、弹道、攻击读条或召唤矿丸 | 舰炮兵器 |
| Card Table / `pal_022` | 筹爪狐獴 | 直立细长狐獴，用前爪翻出一枚筹鳞，先描边候选再只落给随机单Friend | 只留赭石金纹与前爪力度，重画鼹鼠圆身；禁牌桌加眼、全队波纹与“越打越慢”动画 | 奇物谋略 |
| Chum / `pal_025` | 饵囊海鞘 | 梨形附着软囊与双虹吸口；A喷气味云覆盖Aquatic/Food；购买赠品走商店弹卡 | 删鲶头、鱼尾和长须；禁鱼饵桶加眼、鱼群、Piranha从身体钻出或增加body_count | 自然异象 |
| Clamera / `pal_026` | 闪瞳扇贝 | 一只真实双壳软体动物，壳缘天然外套膜眼点显示剩余强制使用额度 | 狼体全删，仅留冰蓝水波；与螺旋Sea Shell、圆核Pearl防撞。双壳仍是一体，禁相机快门装置和复制分身 | 自然异象 |
| Bonfire / `pal_014` | 篝尾浣熊 | 低伏浣熊以炭化环纹大尾卷地施加Burn；Burn成功后火星跳向一个锁定相邻目标 | 金钱狸骨架可高复用，删金币/首饰；禁篝火堆加眼、两侧同时受益或技能条邻位 | 自然异象 |

共同字段为 `unit_count=1/body_count=1/proper_name=false/source_friend=false`。Card Table 的 Friend 是受益者筛选，不会把自身标成 Friend；Clamera 的眼点是额度 UI，不是多身体；Cannonball 的矿丸是资源 VFX，不进入 summon 生命周期。

`RETRACTED_CLASS_COUNT`：本轮最初写“主类总数保持海兽24 / 舰炮55 / 器械21 / 船体13 / 奇物12 / 自然13”，漏记 Cannonball 从自然迁舰炮、Card Table 从自然迁奇物。正确的第16轮结束计数是海兽24 / 舰炮56 / 器械21 / 船体13 / 奇物13 / 自然11，共138。错误不静默删除，保留供分类账追溯。

### 五项最终机制骨架

| 对象 | execution_mode 与骨架 | 精确事务/门禁 | 阶段状态 |
|---|---|---|---|
| Cannonball | `passive_only`；全体宠物声明的 `ammo_anchor_skill_id` 获 AmmoMax aura | BATTLE_SETUP汇总skill-scope modifier后初始化current ammo；来源退出重算并clamp，不发Reload | 红，Ammo门禁 |
| Card Table | `support`；A随机一只合法Friend的`multicast_anchor_skill_id`本战+1 Multicast | 候选必须Friend/存活/有CD/显式eligible+repeat_safe；无目标提交前拒绝并退出自动候选 | 深红，等待包量上限 |
| Chum | `support + purchase_listener`；A全体Aquatic OR Food的可暴击锚点本战成长；购买成功原子获得Piranha | 双标签去重；购买、赠品、容量和支付同bundle提交，非购买获得不触发 | 战斗红、经济深红 |
| Clamera | `support + reactive_forced_use`；A Slow一个随机敌方tempo anchor；敌方前N次正常主动后强制A | 只监听scheduled active root；反应绕过ready/AP，成功后冷却重置max；forced reaction互不触发 | 深红，ForcedUse完成前暂停 |
| Bonfire | `support + passive`；A对敌leader Burn；每个成功Burn root后随机催动一个同排左右锚点 | Burn消费者once/root；Haste改remaining cooldown而非speed；无相邻或delta0不回滚Burn | 深红，带门禁 |

### Cannonball 的 AmmoMax 光环

权威顺序：`roster/tag/anchor校验 -> 汇总AmmoMax modifiers -> 计算有效上限 -> 初始化current ammo -> 首个行动`。战中来源死亡/UnitExit 后在安全点移除来源、回落到下一有效上限并向下 clamp 当前弹药；不退款、不免费Reload、不发布 `AMMO_RELOADED`。

一件来源item映射一宠，每宠只修饰显式 `ammo_anchor_skill_id`，不因本地A/B复制为两个弹药对象。空间是 `board_global_allied_ammo_anchors`，不再使用旧Adjacent，换位和技能条重排均无影响。

来源多副本可加法；本地暂采用 `max_by_stat/strongest_source_only` 防止全局MaxAmmo与Reload复乘，并明确记录：

```text
source_stacking = additive_aura
local_stacking = max_by_stat
deviation_reason = global_ammo_reload_multiplicative_safety
```

最高来源退出时回落到次高并clamp。若未来重复宠规则保证战场不可能存在多Cannonball，可复审撤掉该裁剪，但实现层不得先静默相加。

### Card Table 的本战 Multicast 成长

合法目标同时满足：本场阵容标签含Friend、当前存活未退出、有冷却主动、声明唯一`multicast_anchor_skill_id`、该锚点`multicast_eligible=true/repeat_safe=true`。Card Table自身不是Friend，不能选自己。

root prepare 从稳定排序候选集用战斗RNG选择唯一目标并写Result/Trace；无候选时 readiness 阶段直接标不可释放，从共享自动技能候选移除。手动尝试返回 `NO_EFFECT_TARGET`，不耗AP、不启CD、不发SKILL_USED；目标状态变化后才重新进入候选，不能同tick反复重试。

每次成功只修改目标以后使用的packet数，不立即额外use。同一Friend可在不同Card Table root中再次被选并继续叠层，这是来源真实风险；必须先冻结总packet cap、每技能Multicast cap与同root反应链cap。旧non-Friend冷却惩罚不得用来抵消预算。

### Chum 的战斗与购买两条权威轨

战斗A作用于全部 `(Aquatic OR Food) AND crit_anchor can crit` 的活动宠物；不是随机或单目标。每宠只认一个显式`crit_anchor_skill_id`，双标签只命中一次；无可暴击operation就不凭空创建Crit。目标集合在prepare冻结，Multicast子包不重复参数成长。

购买Piranha只认成功提交的`BUY_OFFER`：

```text
预检Chum与Piranha内容/容量/支付
-> 原子提交支付 + Chum实例 + Piranha实例
-> acquisition_lots/provenance/transaction_id
-> 发布一次购买结果
```

Piranha用正式内容ID定向生成，不经过随机池、不进8×7棋盘、不发SUMMON_CREATED。copy、free grant、merge、读档重放均不得触发；满容量在reward inbox未完成前整笔fail closed。折扣购买后两件可兑现售价、赠品品质、立即合成/出售与退款套利必须先通过经济门禁。

### Clamera 的 ForcedUsePolicy

主审接受 `ForcedUsePolicy.BYPASS_READY_RESTART_ON_SUCCESS`：

1. 敌方 `execution_origin=scheduled_active` 的正常root完整提交并通过死亡安全点。
2. 存活且未退出的Clamera按稳定source_id检查剩余额度，预留一次计数。
3. 在同一causal root下建立`reaction_skill_invocation` packet；它不是共享技能条新root，不耗AP，忽略自身A当前remaining cooldown。
4. 执行与正常A相同的Slow operation；至少一项`delta>0/APPLIED`后，把A剩余冷却**替换**为完整最大冷却。
5. 语义性无目标仍消耗本次额度，但不启动/重置冷却；技术失败回滚反应packet与额度，绝不回滚已提交的敌方root。

只监听scheduled active；Multicast、reaction、passive、system packet均不计敌方使用。forced reaction带独立invocation ID和原root因果链，可记录子级SKILL_USED供表现，但不能喂另一方Clamera；每来源每root一次并设`forced_depth`硬上限。`REQUIRE_READY`与`BYPASS_READY_KEEP_COOLDOWN`均拒绝：前者背离前N次触发，后者把反应变成无代价免费动作。

源宠在安全点前死亡/exit则不执行。主审随后冻结控制边界：冷却中允许强制use；Freeze/硬锁若定义为禁止use，则本次不执行但仍消耗反应额度，避免解冻后补发隐藏队列。技术失败才回滚额度预约。Clamera仍需统一ForcedUsePolicy落地后才进正式运行时。

### Bonfire 的 Burn→相邻催动

Bonfire A或其他合法Burn root出现至少一个正增量Burn application后，由RootApplicationAggregator为每个Bonfire每root发布一次消费机会。多段、范围和Multicast子包只催动一次，这是本地防乘法裁剪；下一独立root可再次触发。

相邻沿统一 `board_horizontal_round_snapshot`：回合开始锁定同排x±1，来源移动/死亡/exit立即断链，本回合新移入者下回合才接。两侧都合法时确定性随机一个`tempo_anchor_skill_id`；无目标或已ready导致delta0只让被动reaction no-op，不回滚原Burn。Haste只减少remaining cooldown，不改speed、不创建新root，也不得同root重入。

### 成长、模块与配套

- Cannonball只成长AmmoMax数值，范围永远全局；Card Table只成长自身使用节奏，赠予层/目标数固定。
- Chum只成长Crit幅度，标签域、目标数、Piranha数量固定；Clamera只在冷却与额度之间分配成长预算；Bonfire的Burn与Haste共用一个总预算。
- P0：继续扩SupportSkillExecutionPolicy、BattleEventEnvelope、RootApplicationAggregator、SkillCooldownService、PassiveOnly、DeterministicTargetResolver。
- P1：AmmoMax skill-scope modifier、Multicast ledger/cap、ForcedUsePolicy/ReactionQueue、MechanismRuntimeStateService、PurchaseRewardGrantBundle、ContentDependencyValidator、acquisition lot幂等。
- 非战斗：商店显示Chum双物品奖励/容量/套利提示；图鉴用Bonfire现名并支持Flame Signal搜索；UI显示Ammo上限来源、Multicast层、Clamera额度和Bonfire关系线。
- AI：评估Ammo×Reload、把Multicast给高价值Friend、Chum双物品价值、Clamera剩余额度与Bonfire相邻Burn循环。
- QA：固定种子1/5/12回合，覆盖0/1/多Ammo、无Friend、同目标多层、双标签、容量0/1/2、折扣买卖、敌方Multicast、双方Clamera、死亡/exit、Burn免疫、冷却下限与stateHash。

### 第 16 轮进度

五只最终暂名：铁丸鼹、筹爪狐獴、饵囊海鞘、闪瞳扇贝、篝尾浣熊。

累计已有 78/138 个 Vanessa 原生对象完成逐项审阅。可进入带门禁骨架：Cannonball、Card Table、Chum、Bonfire；Clamera 等统一ForcedUse/控制交互矩阵后实施。下一批自然异象 B：Incendiary Rounds、Piano、Seaweed、Volcanic Vents、Wanted Poster；完成后自然异象13项闭环。

## 第 17 轮：原自然异象批次 B 与分类账复算

本批五项：Incendiary Rounds、Piano、Seaweed、Volcanic Vents、Wanted Poster；旧 ID 锚点为 `pal_060`、`pal_086`、`pal_103`、`pal_132`、`pal_133`。逐项机制说明显示三件更适合舰炮/奇物，不能让批次名称反向决定身份主类。

### 来源页分歧与17.2裁决

数值组普通公开抓取最初仍命中16.1/16.2页头，因而明确警告“不能把缓存冒充17.2”。战斗组与身份组随后实时打开非global直达页，五页均显示 `17.2 (Aug 13)`，且 public/Deep 当前循环一致。主审采用第14轮证据模型：

- 保存搜索摘要/地区缓存的旧页头，状态为 `cache_version_mismatch`，不抹掉数值组异议。
- 保存实时直达 URL、观察时间、17.2页头与public/Deep内容签名，作为本轮首选证据。
- Incendiary 同日观察到 `37db...` 与 `1841...` 两个相同17.2内容 ID，记 `ID_ALIAS_CONFLICT_CONTENT_EQUIVALENT`，不生成两条宠物。
- 未来若同patch内容真正分叉则 `SOURCE_CONFLICT_STOP`，不能继续靠名称合并。

| 对象 | 本轮首选观察 ID / 当前17.2循环 | 旧CSV差异 |
|---|---|---|
| Incendiary Rounds | `37db8t5n2q5k09y7xhyd3jypsv`；相邻对象使用后Burn | 当前基础无Ammo/Reload；历史AmmoReference和旧Burn档只进历史列 |
| Piano | `e83o1y8e041zv5j4novhkn620`；相邻对象获Friend，任一Friend使用后催动该触发者 | 当前明确有Instrument来源类型；系统成本在动态标签和post-cooldown时序 |
| Seaweed | `pg95ktn9cwqhgd1qyst4fktbs3`；主动Heal player；Aquatic使用后自身Heal本战成长 | 旧CSV漏Food来源标签，后段成长档已变化；来源未证明同优先级ability顺序 |
| Volcanic Vents | `124y339kxsdtjqg4w1yn27qvtq0`；Aquatic主动，固定Multicast，连续Burn | 旧CSV漏冷却与固定多播，严重低估包量 |
| Wanted Poster | `px07x9cwsds8p47dpzh67w3v69`；全队Crit aura；PVP胜利基础XP与参战额外XP | Deep为两个独立战后永久XP operation，不能合成金币或宠物经验 |

### 五只身份、复用与迁类

| 来源 / pet_id | 最终暂名 | 单体结构与机制动作 | 复用、防撞与禁止直译 | 主类 |
|---|---|---|---|---|
| Incendiary Rounds / `pal_060` | 燧鬃战獒 | 低伏四足、燧石额甲与火鬃；邻宠成功使用后鬃毛点燃并向敌leader吐余烬 | 犬型旧图高复用，删雷纹和弹药暗示；禁子弹加眼、开炮、召唤或主动读条 | 舰炮兵器 |
| Piano / `pal_086` | 和鸣琴鸟 | 地栖琴鸟，巨大U形琴弦尾与键带羽；尾弦向同排左右建立两条音桥 | 龙形旧图只留红金节拍色，整体重画；禁钢琴加眼、全队鼓舞波和自然场地 | 奇物谋略 |
| Seaweed / `pal_103` | 藻冠海鬣蜥 | 低宽海鬣蜥、叶状背冠与扁泳尾；Aquatic使用后背冠增长一段藻纹，A吐绿潮治疗 | 巨猿体块全弃，仅留苔绿与水疗光；禁海草团加眼或因Food写成耗材 | 自然异象 |
| Volcanic Vents / `pal_132` | 熔泉巨管虫 | 单一盘卷足、单一矿管与羽状红冠；一次A从同一身体连续喷出多次热泉脉冲 | 隼形只留冷热泉VFX；禁火山口加眼、三只虫、三座火山或三次技能提交 | 自然异象 |
| Wanted Poster / `pal_133` | 缉印蜜獾 | 低矮宽背蜜獾，以嗅迹/印爪给可暴击友方发细线，胜利后在小悬赏册盖章 | 旧图只留挎包/执法道具布局，重画浣熊脸尾；禁海报加眼、主动攻击或海报召唤 | 奇物谋略 |

全部是 `unit_count=1/body_count=1/proper_name=false`。Incendiary与Wanted是passive-only活宠，需有待机响应但不能伪造普攻；Volcanic多个packet来自同一身体。

### 分类账错误与三组复算

第15轮基线为：海兽24 / 舰炮55 / 器械21 / 船体13 / 奇物12 / 自然13，共138。

第16轮实际迁移：Cannonball 自然→舰炮，Card Table 自然→奇物，应变为 `24/56/21/13/13/11`。当时日志误写“计数不变”。

第17轮迁移：Incendiary 自然→舰炮，Piano与Wanted自然→奇物；Seaweed/Volcanic保留。三组独立复算一致：

```text
海兽24 / 舰炮57 / 器械21 / 船体13 / 奇物15 / 自然8 = 138
```

Pontoon Skimmer 仍是跨英雄草案，若另加器械则为 `24/57/22/13/15/8=139`。正式旧映射CSV另核得138条item、编号1..138连续无缺号；目标文字中的139不能靠改分类数字凑出，仍必须坚持“138 Vanessa原生 + 1跨英雄草案”的来源口径。

### 五项最终机制骨架

| 对象 | execution_mode 与本地骨架 | 粒度与停止线 | 状态 |
|---|---|---|---|
| Incendiary Rounds | `passive_only`；相邻宠物成功使用主动后，对敌leader施加Burn | 每来源每root一次；Multicast子包不乘；forced-use可算use但passive/system不算；当前无Ammo | 红，可进门禁骨架 |
| Piano | `passive_only`；相邻宠物获派生Friend；任一Friend主动成功后，催动触发者自己的tempo anchor | 标签按来源引用计数；Haste必须在触发者正常冷却启动后；多Piano每来源一次 | 深红，动态标签前暂停 |
| Seaweed | `support + passive`；A Heal leader；任一Aquatic主动后增长自身A后续Heal | 每Seaweed每root一次；自身A先按旧值Heal，post-use再成长；满血仍可因真实后续成长提交 | 深红，Leader Heal前暂停 |
| Volcanic Vents | `support_bundle`；A一次root固定多个packet，每包对敌leader Burn | 一次AP/CD/root；每包独立application；下游消费者once/root；无持续地形 | 深红，可进packet门禁骨架 |
| Wanted Poster | `passive_only + post_battle_progression_listener`；战斗Crit aura；PVP胜利两笔XP | Crit骨架可进；XP等待EncounterKind/玩家经验账本/幂等事务，缺字段fail closed | Crit红，XP深红暂停 |

### Incendiary 的相邻使用反应

来源当前无Ammo类型、Ammo消费或Reload；`source_theme=ammunition`只影响身份分类，绝不能反推战斗机制。

相邻使用统一 `board_horizontal_round_snapshot`：回合开始绑定同排x±1，移动/死亡/exit立即断，本回合新移入下回合接。相邻宠的scheduled active或合法forced-use完整提交并通过死亡安全点后，为每个仍存活来源建立一个Burn reaction packet。每来源每root一次；Multicast、passive和system不算新的使用。

反应只向enemy leader写Burn，不创建火地块、弹道、Ammo变更或新技能root。来源在安全点前死亡则取消；Burn统一走LeaderCombatantState/Burn ledger。

### Piano 的派生Friend与post-cooldown催动

- 自然Friend来自base tags；Piano只写 `derived_tags_by_source[piano_instance_id] += Friend`，不污染图鉴、商店或基础存档。
- 相邻域沿同排左右回合快照；来源/关系断开时只移除该Piano引用，其他Piano或自然Friend仍有效。
- 任一全场Friend成功主动后，每个存活Piano都可响应；不要求触发Friend相邻，因为来源第二条能力读取所有Friend。
- 触发者正常技能冷却必须先启动，然后Piano在 `SKILL_COOLDOWN_STARTED` 后减少该宠物的 `tempo_anchor_skill_id` remaining。提前催动会被后续启动冷却覆盖，明确禁止。
- 每Piano每root一次，Multicast不乘；Haste不是新SKILL_USED。多个Piano可分别生效，但统一受CD下限和同root禁重入。

Piano自身不是Friend；若其他来源赋予它Friend，才按派生标签参与。动态标签必须有来源引用计数、生命周期和Trace，不能只塞一个无法回撤的布尔值。

### Seaweed 的先治疗、后成长

来源Deep显示两个独立ability，但没有稳定证明同优先级执行先后。主审采用更保守、玩家更易理解的本地顺序并记录偏离：root prepare冻结当前HealAmount，A先用旧值治疗leader，正常提交/启冷却，然后因自身Aquatic use在post-use packet增长未来HealAmount；新成长不追溯本次治疗。

每个Seaweed每个Aquatic root最多成长一次；Multicast和Aquatic/Food双标签不乘。Food-only不触发，来源死亡后自身本战成长随实例失效。

通用support fail-closed在此有显式例外：leader满血导致Heal delta=0时，Seaweed A仍可提交，因为自身Aquatic use会产生真实后续成长；必须通过 `downstream_effect_preflight=true` 证明，不允许其他空技能借此空放。

### Volcanic 的固定Burn连发

一次A预留一次AP和冷却，按来源固定Multicast生成有序packet；每packet恰有一个`apply_burn_to_enemy_leader` operation。所有packet共享root，Bonfire、Incendiary、Seaweed等下游消费者仍按root一次。

准备阶段冻结leader与全部packet；技术失败整bundle回滚。目标进入终局状态时可停止剩余packet并记录`TERMINAL_TARGET`，不当技术失败。子包之间不插入AP行动、关系重算或新SKILL_USED。禁止把名字转成持续地形、每回合喷发、三个技能root或扩大攻击形状。

### Wanted Poster 的Crit与PVP经验

战斗开始为每只友宠声明的唯一 `crit_anchor_skill_id` 提供Crit aura；这是“一来源item→一宠→一来源等价技能”的本地预算合同。战斗组曾提议覆盖所有crit-capable技能，主审为防A/B双兑现采用单锚点，并在来源偏离列记录；一个锚技能内部的多段/多operation仍共享该Crit参数。来源死亡/exit后光环移除。

开战冻结 `owned_wanted_poster_instance_ids`、`active_roster_wanted_poster_instance_ids`、`encounter_kind` 与 `battle_id`。战后只在 `win && encounter_kind=PVP_HERO` 建 progression bundle：

1. 合法拥有实例产生基础XP operation。
2. 开战四宠阵容内实例另产生参战XP operation。
3. 以 `battle_id + source_instance_id + reward_kind` 幂等，两个operation原子提交。

参战实例中途死亡不取消额外XP；背包未出战实例只得基础XP。PVE、Boss、平局、失败或EncounterKind缺失均无XP并fail closed记录审计。当前没有玩家XP权威账本和可靠PVP分类，XP不得替成金币、宠物经验、战利品或所有胜利奖励。

### 成长、模块与非战斗配套

- Incendiary只成长Burn标量；Piano只成长Haste强度，Friend授予恒定；Seaweed只成长每Aquatic root的Heal增量；Volcanic只成长单包Burn；Wanted只成长Crit aura，两笔XP固定。
- 新增/扩展：`DerivedTagModifierLedger`、post-cooldown hook、Leader Heal/Burn applications、固定包Multicast、`PlayerRunProgressionLedger`、`EncounterKind`、`BattleRosterLockSnapshot`、战后奖励幂等。
- 继续复用 `RelationSnapshot`、RootApplicationAggregator、SkillCooldownService、SkillParameterModifierLedger、PassiveOnly与BattleEventEnvelope。
- UI：Piano音桥/派生Friend来源、Seaweed本场Heal成长、Volcanic同root包序、Wanted基础/参战XP预览；被动宠不占技能条但占阵容位。
- AI：评估相邻使用频率、Friend标签图、Seaweed时序成长、固定多播和PVP经验机会成本。
- QA：固定种子1/5/12回合，覆盖移动/死亡、Multicast、forced-use、full-health例外、多Piano引用、Burn终局、PVP/PVE/平负、战中死亡、重放幂等与stateHash。

### 第 17 轮进度与自然异象闭环

五只最终暂名：燧鬃战獒、和鸣琴鸟、藻冠海鬣蜥、熔泉巨管虫、缉印蜜獾。

累计已有 83/138 个 Vanessa 原生对象完成逐项审阅。自然异象当前8项均已审完：Chum、Clamera、Bonfire、Seaweed、Volcanic Vents、Iceberg、Shipwreck、Weather Glass。

下一类进入舰炮兵器57项，建议先做8项代表批次：Anchor、Arbalest、Ballista、Bayonet、Bladed Hoverboard、Blowgun、Blunderbuss、Bolas；继续先身份、机制、模块与风险，不填正式数值。

## 第 18 轮：舰炮兵器批次 A——百分比伤害、弹药连发与强制使用

本批八项为 Anchor、Arbalest、Ballista、Bayonet、Bladed Hoverboard、Blowgun、Blunderbuss、Bolas，对应旧锚点 `pal_002`、`pal_003`、`pal_005`、`pal_007`、`pal_010`、`pal_011`、`pal_012`、`pal_013`。三组均只读审阅，没有写正式数值、CSV、生成 JSON 或运行时代码。

### 来源版本停止线

本轮不能诚实写成“17.2 已核”。2026-08-17 主审直接打开八个 BazaarDB URL 均超时；搜索索引和当前可抓取直页只能证明 Anchor、Arbalest、Ballista、Bayonet、Bladed Hoverboard、Blowgun、Blunderbuss 的 16.2 内容，Bolas 的可核直页更旧。身份组曾把 Anchor 标成17.2，但没有留下可重复读取的直页正文；主审因此不采纳版本升级，只保留为观察异议。

所有八行统一写：

```text
mechanism_evidence = current_public_content_signature
last_repeatably_verified_patch = 16.2（Bolas 更旧）
current_17_2_status = change_unverified
formal_value_status = blocked
```

这不否定当前公开循环的参考价值，只阻止把旧缓存数值当正式17.2真相源。未来重新抓到17.2时，必须比对 public、Deep、card ID、页头与内容签名；机制有实质差异则逐行 `SOURCE_CONFLICT_STOP`。

| 对象 | 本轮首选观察 ID | 当前可核公开循环 | 旧快照处理 |
|---|---|---|---|
| Anchor | `54kfsq8n7m4qvqxlp1y9bd5939` | 按敌方最大生命造成比例伤害；邻接对象使用后催动自身 | 循环可参考；旧品质、冷却和比例不进正式数值 |
| Arbalest | `1yz8ahd7zyvftmaf9ig721w07` | Ammo 单发；成功 Haste 后本战增伤 | 旧固定伤害与成长档撤回 |
| Ballista | `1gcjtjpfqt7gdt4p3yvpxsqf5v` | Ammo 重击；另一 Ammo 对象使用后本战增加 Multicast | 来源未显式给成长上限，不能假造来源上限 |
| Bayonet | `h7tnjd964n9jm3411h5mcdy138` | 左侧 Weapon 使用后追加伤害 | 核心循环可参考 |
| Bladed Hoverboard | `n4z59z0q0y048z9svtd4y6zm2k` | 邻接对象使用后追加伤害并让触发者开始 Flying | 两条 Deep ability 必须同一反应包表达 |
| Blowgun | `8bdl5cbnzmg33gy004ddsvy6wl` | 同次使用造成 Damage 与等同面板 Damage 的 Poison | Poison 不读取暴击后或实际扣血量 |
| Blunderbuss | `13n6kw1nnp2h1jd6d69jhkdyn6g` | Ammo 武器；成功 Burn 后强制使用自身 | 历史 Charge 版本不回填 |
| Bolas | `yytskm9bdxg5hk0pjw0v4c1bbg` | Ammo；一次使用包含 Damage 与 Slow | 17.2 最需优先复核 |

### 三组分歧、撤回与主审裁决

数值组初版把 Bayonet 的“左侧”译成共享技能条左邻，并让 Anchor/Hoverboard 每个 root 即时重查邻接。这与前几轮已冻结的玩家可见空间词典冲突。主审要求交叉复审后，数值组正式 `RETRACT`：

- 撤回 Bayonet 的共享技能条左邻；
- 撤回 Anchor、Hoverboard 的 root 即时动态邻接；
- 撤回据此计算的技能条高频预算；
- `ACCEPT` 三者统一采用 `board_horizontal_round_snapshot`。

最终空间合同：回合开始建立关系；Anchor/Hoverboard 锁同排直接左右一格，Bayonet 只锁同排正左一格且目标锚技能有 Weapon 标签。来源或已锁邻居移动、死亡、撤回、非死亡退出时立即断边；当回合移回也不恢复；新移入者下一回合才接入。已经在某 root 开始时合法入队的 operation 按原子事务继续，不因结算中途断边回滚。

第二处分歧是 Blowgun 的 Damage 致死后是否仍施 Poison：

- 战斗组提议把死亡安全点推迟到整个 packet 末，以保留两个 operation；
- 数值组提议 Damage 先结算，目标已败北则 Poison 返回 `TARGET_DEFEATED`，不改投新目标；
- 主审实查 `skill_effect_port.gd`：当前 `apply_physical_damage()` 在该伤害 effect 内收集并立即 `_resolve_damage_deaths()`，后续 effect 才执行；`StatusService.apply()` 本身没有死亡过滤。

主审采用数值组方案，以匹配现有权威链并禁止给尸体挂状态：`Damage -> death safe point -> if alive then Poison; else TARGET_DEFEATED`。这属于 Blowgun 的显式本地 operation policy；技术失败仍走事务回滚，语义性目标败北不回滚已完成 Damage。战斗组“整包末死亡”保留为被否决提案，未来实现 `EffectPacketTransaction` 时不得偷偷改回。

### 八只宠物身份与美术边界

| 来源 / pet_id | 最终暂名 | 单体结构与动作表达 | 旧底稿复用、防撞和禁止项 | 主类 |
|---|---|---|---|---|
| Anchor / `pal_002` | 沉锚海象 | 双下弯獠牙承担锚定意象；A以钩地急刹与冲击表现比例重击；邻位水纹汇入獠牙表示自身催动 | 只留灰蓝、珠饰和旋流色；狸脸、环尾、幼体比例全弃；不把铁锚加眼 | 舰炮兵器 |
| Arbalest / `pal_003` | 蓄弦角羚 | 外展回弯角与胸背肌腱形成活体弩臂；Ammo 由角根锁扣显示；Haste 成长让肌腱逐步绷紧 | 只参考灰白金；鸡冠、翅尾全弃；不能平白长出手持弩 | 舰炮兵器 |
| Ballista / `pal_005` | 重弩鹿角虫 | 巨颚像弩臂，背甲两枚鞘节表示弹仓；Multicast 是同一身体连续咬合/气刃回声 | 狐体全弃；与水甲虫以高肩巨颚黑甲对低扁桨足区分；连发不生成甲虫分身 | 舰炮兵器 |
| Bayonet / `pal_007` | 侧锋螳螂 | 正左 Weapon 使用后，螳螂侧转沿同一目标轨迹补刺 | 猫体全弃；细高六足和折叠镰臂区别拳螯类；无普攻读条，不连接共享技能条 | 舰炮兵器 |
| Bladed Hoverboard / `pal_010` | 滑刃鲂鮄 | 扇形胸鳍边缘是天然滑刃；邻宠行动后滑切并以翼流托起该触发宠物 | 可参考蓝白水珠；鹭颈、鸟腿、鸟喙全弃；不是滑板加眼，也不是自己起飞 | **器械载具** |
| Blowgun / `pal_011` | 毒息眼镜蛇 | 颈兜为蓄压囊、管状毒牙为吹管；一次吐息表达点伤与毒雾 | 水獭四足和冰晶全弃；与环形保护海蛇以直立兜颈和攻击姿态区分 | 舰炮兵器 |
| Blunderbuss / `pal_012` | 轰腮河马 | 圆桶躯干、巨口与膨胀双颊表达喇叭口散射；腮囊刻度显示弹药 | 鼠头、长尾、针毛全弃；不能把每个火粒画成一次独立触发 | 舰炮兵器 |
| Bolas / `pal_013` | 绊锤双尾狐猴 | 一只直立轻身狐猴，两条末端骨锤尾交叉缠住同一目标；双尾表示两发 Ammo | 龟壳与低伏体态全弃；`body_count=1, tail_count=2`，绝不是两只宠或两个召唤物 | 舰炮兵器 |

八只均为 `unit_count=1/body_count=1/proper_name=false`。禁止把锚、弩、弩炮、刺刀、滑板、吹管、火枪或流星锤本体直接加眼睛。器官只承担功能意象，不得反向推导来源没有的战斗机制。

身份组、数值组、战斗组最终一致 `ACCEPT` Bladed Hoverboard 迁入器械载具：Vehicle+Tech+Flying 支持循环比纯 Weapon 更能定义其体验。迁类只改 `identity_family` 和图鉴货架，保留全部 `source_types`，不自动增删 CombatTag。

分类账更新为：

```text
Vanessa 原生138：海兽24 / 舰炮56 / 器械22 / 船体13 / 奇物15 / 自然8
Pontoon 跨英雄草案另加器械：海兽24 / 舰炮56 / 器械23 / 船体13 / 奇物15 / 自然8 = 139
```

### 八项最终无数值机制骨架

| 对象 | execution_mode 与本地骨架 | root / packet / operation 粒度 | 门禁与状态 |
|---|---|---|---|
| Anchor | `attack + reactive_passive`；A对一个冻结敌宠按其最大生命计算物理伤害；邻接合法锚技能成功后催动自身A | 邻居每个 qualifying use root 各触发一次；Multicast子包不乘。A在prepare锁敌宠和MaxHP，再走标准Crit/防御/护盾/死亡链 | 红；必须有宠物/Boss百分比伤害上限、预计伤害UI与AI裁剪 |
| Arbalest | `attack + reactive_passive`；A为Ammo单发；成功Haste后写本战A伤害成长 | `once_per_haste_root`：至少一个Haste application实际推进冷却才成长一次；多目标、多包不乘 | 红；需Ammo、RootApplicationAggregator、战内参数账与成长上限 |
| Ballista | `attack + reactive_passive`；A读取root开始时冻结的当前Multicast；另一宠物Ammo锚技能成功使用后增长后续Multicast | `once_per_other_ammo_use_root`；自身use、Reload、空弹失败、child packet不计；一次root只耗一发Ammo | 深红；必须同时配置物品成长上限和全局packet熔断，缺任一继续阻断 |
| Bayonet | `passive_only`；正左冻结邻宠使用Weapon锚技能后，对该技能的TargetSnapshot追加伤害 | 每实例每qualifying neighbor use root一次；追加是child operation，不是新skill use，不重选目标 | 黄；可进无数值骨架 |
| Bladed Hoverboard | `passive_only`；冻结邻宠使用锚技能后，同一反应包先追加伤害，再让触发宠开始Flying | 每邻居每root一次；已Flying时关键词分支为幂等no-op但伤害仍结算 | 深红；等Flying关键词、反应包与状态事件 |
| Blowgun | `attack_bundle`；A按 `Damage -> death safe point -> Poison if target alive` 有序执行 | Poison读取prepare时解析的面板Damage；不读暴击后、护盾后或实际掉血量；Multicast重复完整packet | 红；可进无数值骨架，等Poison ledger/tick和包事务 |
| Blunderbuss | `attack + reactive_forced_use`；A为Ammo攻击；Burn成功后强制使用A | `once_per_burn_root`；forced child耗一发Ammo、绕过当前CD/AP，成功后CD替换为max；无Ammo不重试 | 深红；等ForcedUsePolicy、ReactionScheduler和因果链上限 |
| Bolas | `attack_bundle`；A一次耗一发Ammo，按 Damage 后 Slow 操作同一冻结敌宠 | 一root/一packet/两operation；Slow只改目标`tempo_anchor_skill_id`剩余冷却，不改speed | 红；等Ammo、冷却唯一写者、控制递减与软锁门禁 |

Anchor 的来源“opponent”在本地明确裁成敌方宠物而非 player leader，因为本项目普通 Weapon 攻击以8×7格子单位、形状和死亡链为核心。A只使用单落点/首个合法敌宠，不把 Medium/Large 翻成范围。该偏离必须写 `source_scope=opponent; local_scope=enemy_board_unit; reason=grid_combat_damage_authority`。

### Ammo、Multicast 与强制使用统一合同

Ammo：

1. `BATTLE_STARTED` 前按skill instance初始化 `current=max`；没有Reload文案就不自动回弹。
2. 正常主动在prepare检查并reserve 1 Ammo；`current=0` 返回 `NO_AMMO`，不耗AP、不启CD、不发SKILL_USED。
3. 一次use root只扣一次；Multicast child packets不重复扣。
4. Forced Use同样必须原子扣一发；无Ammo写 `FORCED_USE_SKIPPED_NO_AMMO`，不回滚父root也不进入自动重试。
5. Reload只在`delta_ammo>0`时成功；品质升级不得在战斗中隐式补满。

Ballista Multicast：

```text
effective_packet_count = min(base + qualifying_other_ammo_roots, item_packet_cap)
effective_packet_count = min(effective_packet_count, global_max_packets_per_skill_root)
```

来源没有公开显式上限，本地上限是12回合与反应链安全裁剪，必须在来源偏离列、UI“当前包数/上限”和 `MULTICAST_TRUNCATED` Trace中公开。packet数在root prepare冻结；结算途中新增层只影响下一次使用。达到上限后的Ammo use仍正常提交，但不再增长。

Blunderbuss：

1. RootApplicationAggregator把同一父root的多个成功Burn application聚合为一次机会。
2. 父packet完成并通过reaction safe point后，建立forced child invocation；不是共享技能条额外项目。
3. 预检来源存活、未exit、战斗未终局、目标合法且Ammo>0；再原子扣Ammo。
4. 绕过当前cooldown/AP执行完整A；成功后把A剩余冷却替换为max，不累加。
5. 技术失败只回滚forced child的Ammo/CD/伤害；不回滚父Burn root。语义性无Ammo/无目标不重试。
6. forced child继承causal root并带`counts_for_forced_consumers=false`；每来源每root一次，另有全局forced depth/event预算熔断。

若未来附魔让Blunderbuss自身造成Burn，也只能在同一causal root消费一次，绝不形成无限自触发。

### 空间关系与表现合同

三项共用字段：

```text
relation_domain = board_same_row
snapshot_timing = round_start
invalidate_on = [move, death, withdraw, unit_exit]
join_policy = next_round
dynamic_rebind_mid_round = false
skill_bar_neighbor = false
```

- Anchor：双牙根部向左右冻结邻宠脚圈画粗短潮痕线；触发脉冲方向为“邻宠 → 海象”，随后只缩海象自身冷却环。新移入者用灰色“下回合接入”虚线。
- Bayonet：只画“左Weapon → 螳螂”的单向刃线，左端有Weapon徽记；触发后螳螂独立补刺，不能从左宠身上冒出第二击，也不能高亮技能条邻位。
- Hoverboard：由鲂鮄向冻结邻宠画翼流线；触发时只有实际使用的一侧上扬并给该邻宠落Flying徽记，同时另走敌向刃波。已Flying只显示幂等徽记，不能伪造第二次Flying事件。

### 数值成长边界

- Anchor只允许比例伤害一轴成长；冷却、邻接数、目标数和Haste强度固定，并受Boss/英雄抗性或硬上限。
- Arbalest来源的基础与Haste成长均随品质变化，本地0/2/5/9必须把两轴视为同一总预算，不能每阶段同时满额增长；Ammo与冷却固定。
- Ballista只增长单包伤害；Multicast每次成长幅度、触发域、Ammo和上限固定。
- Bayonet、Hoverboard只增长追加伤害；关系域、目标数、Flying授予恒定。
- Blowgun主要走冷却/使用频率轴；Damage:Poison面板比例固定，不再叠旧反伤。
- Blunderbuss只允许AmmoMax成长；伤害、冷却、每Burn root强制次数固定。
- Bolas的Damage与Slow为双预算轴，需交替里程碑或共享总预算；Ammo、目标数和冷却固定。

继续禁止填写正式0/2/5/9数值。所有成长先过单回合、5回合、12回合、Reload循环、Forced Use循环与Boss血池六组压测。

### 新增或补齐的代码模块

P0：

1. `EffectPacketTransaction`：prepare/reserve/stage/commit/rollback与语义性skip，允许有序operation和显式死亡安全点策略。
2. `ReactionScheduler`：父root安全点后稳定调度child invocation，持有causal root、depth、budget和递归资格。
3. `AmmoResourceService`：skill-instance级Ammo初始化、消费、Reload和Trace的唯一写者。
4. `SkillCooldownService.advance/delay/reset`：催动、阻滞、forced reset和百分比冷却修饰的唯一写者。
5. `BoardRelationService`：回合关系快照、断边、下回合接入和UI edge ID。

P1：

6. `MulticastPacketExecutor`：同root完整packet复制、独立Crit seed、一次AP/CD/Ammo与双层包上限。
7. `CombatParameterLedger`：本战Damage/Poison/Slow/Multicast等参数成长与生效root序号。
8. `RootApplicationAggregator`：Haste/Burn/Crit/Shield等按root聚合与显式application例外。
9. `BattleKeywordStateService`：Flying幂等false→true事件和战斗生命周期；不附带移动/闪避等隐含语义。
10. `PercentHealthDamagePolicy`：按单位类型的比例伤害上限、抗性、预览与AI查询。
11. `PoisonLedger/PoisonResolver`：Poison application、回合tick、来源与终局清理；扩现有Status/RoundLifecycle，不另造平行战斗权威。
12. `ControlSaturationPolicy`：Slow递减、免疫、软锁阈值和AI可查询收益。

现有 `skill_execution_service.gd` 仍强制从攻击option进入并在效果后直接启CD；`skill_effect_port.gd` 的物理伤害会在单effect末立刻结算死亡；`status_service.gd` 没有死亡目标过滤，当前Haste/Slow状态又只改speed。因此以上模块必须扩展正式 `GameSession -> Command -> Result/Trace/Snapshot` 权威链，不能在单只宠物脚本里旁接。

### 非战斗策划配套

- UI：Ammo点、当前/上限packet数、Forced Use待处理标记、本战成长层、百分比伤害封顶预览、三种关系线、Flying状态来源。
- AI：按剩余Ammo、预计Reload、剩余回合、控制递减、Boss百分比裁剪和reaction budget估值；不得用卡面理论值假装可兑现。
- 教程：明确“Haste是推进剩余冷却，不是额外使用”“Multicast不多耗Ammo”“Forced Use仍需Ammo”“左侧/相邻看棋盘连线，不看技能条”。
- 文本：区分主动使用、child reaction、完整packet、operation、application、开始Flying与已经Flying。
- QA：固定种子1/5/12回合，覆盖左右关系断裂、回合中移入、空弹、Reload、Multicast击杀、Burn多application、forced递归、Poison致死边界、Slow免疫、Boss百分比封顶、存档/重放/stateHash。

### 第 18 轮进度

八只最终暂名：沉锚海象、蓄弦角羚、重弩鹿角虫、侧锋螳螂、滑刃鲂鮄、毒息眼镜蛇、轰腮河马、绊锤双尾狐猴。

累计已有 91/138 个 Vanessa 原生对象完成逐项身份、机制骨架、风险和模块审阅。Bayonet、Blowgun可先进入无数值骨架；Anchor、Arbalest、Hoverboard、Bolas带硬门禁；Ballista、Blunderbuss在动态Multicast上限和Forced Use/Ammo链落地前保持深红阻断。

下一批舰炮兵器 B 建议：Butterfly Swords、Cannon、Cannonade、Cauterizing Blade、Concealed Dagger、Cutlass、Cyber-Sai、Dart Launcher。继续先核来源版本，再做身份、事件骨架、模块和配套，不写正式数值。

### 第 18 轮来源刷新纠错（同日后续）

`RETRACTED`：上文“本批八项均无法核到17.2、Bolas更旧”的结论，只代表首次入口超时后的临时判断，不再作为当前来源状态。

主审随后改用 `global.bazaardb.gg` 的card直达入口，已重复读到以下7项页头 `As of patch 17.2 (Aug 13)`，并核对public/Deep内容签名：

- Anchor：`54kfsq8n7m4qvqxlp1y9bd5939`
- Arbalest：当前直达card内容签名已核17.2
- Ballista：`1gcjtjpfqt7gdt4p3yvpxsqf5v`
- Bayonet：`h7tnjd964n9jm3411h5mcdy138`
- Bladed Hoverboard：`n4z59z0q0y048z9svtd4y6zm2k`
- Blowgun：`8bdl5cbnzmg33gy004ddsvy6wl`
- Bolas：`yytskm9bdxg5hk0pjw0v4c1bbg`

因此这7项撤销 `17.2_change_unverified`，按当前17.2来源机制继续保留无数值骨架。Blunderbuss 的旧ID直达仍超时，继续单独标 `CURRENT_SOURCE_PENDING`；不得用“7项已确认”推定第8项，也不得回退搜索摘要或旧CSV补齐。

这次纠错同时形成来源采集规则：入口超时只说明本次抓取失败，不等于版本停留；必须尝试主站与global直达入口、记录card ID/页头/内容签名，再决定是否设置版本停止线。

## 第 19 轮：舰炮兵器 B（双刀、火炮、任务、经济、暴击与状态弹）

本批八项为 Butterfly Swords、Cannon、Cannonade、Cauterizing Blade、Concealed Dagger、Cutlass、Cyber-Sai、Dart Launcher，对应旧锚点 `pal_015`、`pal_017`、`pal_018`、`pal_024`、`pal_027`、`pal_033`、`pal_034`、`pal_037`。三组均只读审阅，没有写正式数值、CSV、生成JSON或运行时代码。

### 本轮来源刷新与版本撤回

战斗组和数值组的首轮独立报告都把Cyber-Sai之外的7项标成“只能重复读取16.2”。主审随后改用 `global.bazaardb.gg` 直达入口，八页均读到 `Database based on patch 17.2 (Aug 13)` 与卡内 `As of patch 17.2`，因此正式撤回该版本判断。

当前首选来源键：

| 来源 | 17.2首选card ID | 当前核心事实 | 旧表处理 |
|---|---|---|---|
| Butterfly Swords | `tvbb60wvfm5dwdql4jd552724f` | Weapon；一次伤害主动；品质改变Multicast | 旧CSV漏核心Multicast，REJECT“双刀=两个Damage operation” |
| Cannon | `117ss117l2p3zp5bn6dtnq6nts7` | Weapon、Ammo；Damage后Burn，Burn参数由面板Damage按固定比例派生 | 旧高品质伤害档过期；补Ammo与派生参数 |
| Cannonade | `10gwz40pnjk7clz1d63x917cfxn` | Weapon；固定Multicast；另一Weapon或Burn-tag对象使用后Charge自身 | 旧表漏固定Multicast及Burn标签资格 |
| Cauterizing Blade | `h99hpfsphyklf4wyjv9nkwhb8x` | Weapon+Tech；Damage与Burn；Slow Quest `OR` Haste Quest，Deep列出两块Quest/Reward | 旧`+0`占位作废；选择协议仍未由来源证明 |
| Concealed Dagger | `gqv5xbwph75s2m493qkffbp4sn` | Weapon；Damage、随机Haste；开战永久Gold | 保留经济链，但必须移出战斗临时属性 |
| Cutlass | `49tjxq7jsf0fl0zzxd22qw0yjk` | Weapon；固定Multicast；提高Crit Damage | `1ms...`只留alias；旧“敌方Slow时获得Crit Chance”整条删除 |
| Cyber-Sai | `8x4my442h0tv2zhtlj3tvjbp7l` | Weapon+Tech；任意己方board对象Crit后，board Weapons本战Damage成长 | 旧机制描述过粗、旧成长档过期 |
| Dart Launcher | `1334tn1pt2zwtyqym58bsf42h5d` | Tech、Ammo；Slow多个CD目标并Poison opponent；当前无Damage、无Weapon、无邻接 | 旧Damage/Weapon/邻接条件整条删除 |

来源页面：

- https://global.bazaardb.gg/card/tvbb60wvfm5dwdql4jd552724f/Butterfly-Swords
- https://global.bazaardb.gg/card/117ss117l2p3zp5bn6dtnq6nts7/Cannon
- https://global.bazaardb.gg/card/10gwz40pnjk7clz1d63x917cfxn/Cannonade
- https://global.bazaardb.gg/card/h99hpfsphyklf4wyjv9nkwhb8x/Cauterizing-Blade
- https://global.bazaardb.gg/card/gqv5xbwph75s2m493qkffbp4sn/Concealed-Dagger
- https://global.bazaardb.gg/card/49tjxq7jsf0fl0zzxd22qw0yjk/Cutlass
- https://global.bazaardb.gg/card/8x4my442h0tv2zhtlj3tvjbp7l/Cyber-Sai
- https://global.bazaardb.gg/card/1334tn1pt2zwtyqym58bsf42h5d/Dart-Launcher

本轮形成新的证据纪律：搜索摘要和地区缓存只能作为发现入口；只要直达页头、卡内版本、public与Deep内容签名一致，就以直达页为当前证据，同时保留旧ID为typed alias。抓取入口失败不得被写成“物品仍停留在旧版本”。

### 身份组独立提案与防撞

| 映射 | 暂定宠物 | 单体与动作语言 | 旧底稿复用边界 | 主类 |
|---|---|---|---|---|
| Butterfly Swords / `pal_015` | 双锋凤蝶 | 一只凤蝶以两对硬质刃鳞翼沿8字轨迹连续掠切；Multicast只增加同一身体的切痕段数 | 仅留黑甲蓝纹为翅面鳞纹；猪体、獠牙、甲片结构全弃 | 舰炮兵器 |
| Cannon / `pal_017` | 炮角黑犀 | 中空生物角腔先形成冲击、随后留下灼痕；两枚角根骨环表示Ammo | 黑犀体块、装甲、火纹与角可高复用；禁止鼻上安装炮管 | 舰炮兵器 |
| Cannonade / `pal_018` | 三响雷袋鼠 | 巨型袋鼠以单根粗尾连续三次震地；其他Weapon/Burn use时能量回流尾根推进自身冷却 | 仅取大耳、长尾、灰绿金配色；竹筒、背包与鼠脸全弃 | 舰炮兵器 |
| Cauterizing Blade / `pal_024` | 灼爪食蚁兽 | 镰形前爪切开后以高温爪缘封灼；任务进度显示在前臂环，不产生第二身体 | 只取紫橙热纹与火焰边缘；猫头和原四足比例重做 | 舰炮兵器 |
| Concealed Dagger / `pal_027` | 藏锋穿山甲 | 蜷缩后弹出天然腕鳞切击，再把速度流光送往实际Haste目标；开战挖金只走资源HUD | 暖棕色、跃起姿势、翼片层次可转鳞片；鸟体全弃 | 舰炮兵器 |
| Cutlass / `pal_033` | 弯盔鹤鸵 | 弯月盔突与内趾镰爪；一次A固定左右脚连续弧斩，Crit只加深裂光，不增hit | 黑绿金配色可留；熊体、袍服、手势全弃 | 舰炮兵器 |
| Cyber-Sai / `pal_034` | 脉叉三角龙 | 三角突进；友方Crit脉冲先回传颈盾，再向所有Weapon锚点发散 | 黑金、蜂巢甲纹、发光爪线可转赛博颈盾；蜜獾形全弃 | 舰炮兵器 |
| Dart Launcher / `pal_037` | 麻针海胆 | 一只管足海胆，三根主麻针表现Ammo；发射只显示阻滞环和毒雾，不显示伤害数字 | 月白浅绿与角的渐尖曲线可转主针；鹿身、枝角、四蹄全弃 | 迁器械载具 |

统一边界：八只都是单单位、单HP条。Butterfly/Cannonade的Multicast、Dart的多目标、Cyber的全队成长都不改变 `body_count=1`。禁止把双刀、火炮、烙刀、匕首、弯刀、三叉刺或发射器直接加眼睛。

Dart Launcher迁类正式接受：其17.2 `source_types=[Tech]`，基础无Weapon和Damage，状态发射/资源器械是当前体验主轴。迁类只改 `identity_family`，不能给它Vehicle标签。分类账从第18轮 `24/56/22/13/15/8` 更新为 **海兽24 / 舰炮55 / 器械23 / 船体13 / 奇物15 / 自然8 = 138**；Pontoon跨英雄draft另加器械时为 `24/55/24/13/15/8=139`。

### 三方机制矩阵与主审裁决

| 项 | 执行骨架 | root / packet / operation / application | 本地转译与门禁 | 风险 |
|---|---|---|---|---|
| Butterfly Swords | `attack_multicast`；A=Damage；B空 | 一次A一个root；品质决定完整Damage packet数；每包各一个Damage operation | 近距攻击形状；packet独立命中/Crit，但不产生新skill use、AP、CD或消费者root | 红，可进无数值骨架 |
| Cannon | `attack_bundle_ammo`；A=Damage→Burn；B空 | root预留一次Ammo；prepare快照面板Damage；Damage完成即时死亡安全点；存活目标再收Burn | 伤害与Burn落同一冻结命中单位；Burn不读Crit、护盾后或实际掉血；死亡不改投 | 红，Ammo/派生参数门禁 |
| Cannonade | `attack_multicast + passive_charge` | A固定多packet；其他成功主动root满足Weapon OR Burn-tag时，对自身tempo anchor一次Charge | 条件是技能/对象标签，不是成功Burn application；双标签仍一次；排除自身与child packet | 深红，动态使用频率阻断 |
| Cauterizing Blade | `attack_bundle + quest_reactive` | A=Damage→死亡安全点→Burn if alive；Quest进度按成功Haste/Slow root去重；解锁后成长包原子写Damage+Burn | 来源选择协议未知；本地候选为获取/首次部署前显式choose-one，完成root只解锁，下一合格root才成长 | 深红，任务/持久化阻断 |
| Concealed Dagger | `attack_support_bundle + battle_start_reward` | 17.2 Deep为Haste能力High、Damage能力Medium，本地固定Haste→Damage；父root完成后才派发Haste消费者 | Haste无目标只skip该operation，Damage仍提交；Gold走开战幂等经济事务，不是战斗临时Gold | 深红，经济事务阻断 |
| Cutlass | `attack_multicast`；A=Damage；固定Crit Damage修饰 | 一root固定多packet；每包独立Crit seed；Crit Damage进入独立modifier channel | 近距攻击形状；不恢复旧Slow条件，不把暴伤写成Crit Chance | 红，可进无数值骨架 |
| Cyber-Sai | `attack + crit_reactive_bundle` | 己方任意技能root出现至少一次Crit后，root-end冻结当前合法Weapon anchors，每anchor一成长application | once/root；当前root后续packet不追溯吃成长；新入场不继承旧成长，来源退出后停止生产 | 红，团队乘法阻断 |
| Dart Launcher | `support_bundle_ammo`；A=Slow→Poison；B空 | 一root一次Ammo；Slow operation可多application；Poison一个leader application；无Damage operation | Slow选有tempo anchor的敌方单位；无Slow目标仍可Poison；leader Poison基础设施未齐前暂停 | 深红，Leader/Poison门禁 |

### 交叉争议、撤回与最终理由

#### 1. Concealed Dagger的Haste与Damage顺序

战斗组最初认为public排版不能证明执行顺序，建议 `SOURCE_PRIORITY_PENDING`；数值组读取Deep后提出Haste能力为High、Damage能力为Medium。主审重新打开当前17.2 Deep，确认两项优先级仍在，因此最终锁定：

```text
prepare: freeze haste_target + damage_targets
operation_0: Haste
operation_1: Damage
root_commit
dispatch downstream Haste/Crit consumers
```

Arbalest等Haste消费者不得插进父技能两个operation之间。Haste clamp为0或没有合法目标时写语义skip，不能阻断Damage；技术故障才回滚整个父root。金币不是第三个战斗operation。

#### 2. Cannon与Cauterizing Blade的死亡安全点

战斗组首案曾建议把死亡推迟到整个packet结束，以便Damage后仍能写Burn。数值组反对。主审检查当前正式链：`skill_effect_port.gd` 每个Damage effect在返回前已经调用死亡解析。因此正式裁决服从现有权威，不为两件物品另改全局死亡时点：

```text
Damage operation
-> damage applications
-> current death resolution
-> Burn operation receives only still-alive frozen targets
```

Damage致死后写 `BURN_SKIPPED_TARGET_DEFEATED`，不改投、不产生成功Burn application，也不喂Blunderbuss等Burn消费者。非致死才正常Burn。外层技术失败仍由Command checkpoint处理，但“没给尸体挂Burn”不是技术失败。

#### 3. Cauterizing Blade双Quest是否互斥

来源事实只有：public显示Slow Quest `OR` Haste Quest；Deep同时列出两块Quest及Reward。页面没有证明“随机其一”“玩家选择”或“双任务同时有效”。因此撤回三组早期“来源已确认互斥”的说法。

本地候选暂定：

```text
quest_mode = choose_one
variant_assignment = acquisition_or_predeploy_explicit_choice
progress_scope = run_instance
progress_increment = once_per_successful_matching_root
reward_effective = next_matching_root_after_completion
```

这是 `local_safety_deviation`，不是来源事实。若未来决定双Quest并存，必须重新做触发产量、进度保存、合成、复制、出售与5/12回合双成长压测，当前保持红色阻断。

#### 4. Cyber-Sai按Crit application还是root成长

来源触发是任意己方board对象Crit；本地多播、多段和多格一次使用可产生多个Crit application。为避免一个大形状技能在一次发动内指数喂全队，最终采用公共默认 `once_per_skill_use_root`：root内至少一个有效Crit即可触发一次团队成长包。该包对当时存活、未exit且具有显式 `weapon_anchor_skill_id` 的宠物各写一次未来Damage modifier。

#### 5. Cannonade的Burn资格

`Weapon OR Burn`是使用对象/技能的来源标签资格，不是“这次成功施加了Burn”。同一触发者兼具两标签仍一次Charge；固定Multicast子包不构成三次use。Charge只推进Cannonade的 `tempo_anchor_skill_id` 剩余冷却，不插入当前冻结共享技能条。

### 八项成长预算方向（不填正式数值）

- Butterfly Swords：只沿Multicast档成长；Damage、冷却、形状固定。单回合看packet峰值，5/12回合看Crit与团队成长乘区。
- Cannon：只沿基础Damage成长，Burn保持固定面板比例派生；Ammo、比例、目标域、冷却固定。
- Cannonade：来源同时有Damage与冷却双轴，本地阶段交替兑现；固定Multicast、Charge量、标签域不增长。
- Cauterizing Blade：Quest结构和门槛固定；解锁后的Damage/Burn成长用共享预算或交替里程碑，禁止两条都自由叠满。
- Concealed Dagger：Damage与Haste可分阶段；永久Gold固定，不随本地成长放大。
- Cutlass：只增长基础Damage；Multicast与Crit Damage倍率固定。
- Cyber-Sai：自身基础Damage与团队成长量必须交替；受益目标数、Crit Chance、冷却不增长，并设置单场成长上限。
- Dart Launcher：Slow目标数与Poison是双轴，阶段交替；Slow时长、Ammo、冷却固定。

风险压测必须覆盖1回合峰值、5回合累计、12回合累计、全队Crit、Multicast、Reload、Haste循环、Quest完成前后与Boss/Leader状态。任何来源数值只进入 `source_*` 事实列，不进入正式本地0/2/5/9列。

### 需要新增或补齐的通用模块

沿用前轮P0/P1路线，并新增：

1. `DerivedEffectParameterResolver`：在prepare时从面板Damage派生Burn等参数，明确是否读取Crit、实际掉血与后续modifier。
2. `CritDamageModifierChannel`：把Crit Chance与Crit Damage彻底分开；Cutlass只写后者。
3. `BoardSkillAnchorIndex`：一宠一个 `weapon_anchor_skill_id` / `crit_anchor_skill_id` / `tempo_anchor_skill_id`，避免A/B双兑现来源一个item。
4. `QuestProgressService`：Run实例级variant、progress、complete、合成/复制/出售协议和幂等存档；不放进宠物战斗脚本。
5. `BattleStartRewardService`：在正式 `START_BATTLE` Command内冻结阵容、写幂等经济operation，再发布BATTLE_STARTED。
6. `LeaderStatusService`：统一Leader的Shield/Burn/Poison/Heal/DR；Dart的Poison在此模块完成前不得伪落到普通单位。

推荐开战事务：

```text
START_BATTLE command
-> validate encounter and roster
-> freeze battle_instance_id + roster instance ids
-> stage BattleStartRewardBatch
-> stage battle state creation
-> atomic commit
-> publish BATTLE_STARTED
```

Concealed Dagger奖励幂等键至少含 `run_id + battle_instance_id + source_instance_id + reward_id`。重载、回放、同一遭遇重试不能重复发钱；战中死亡不追回已经正式提交的奖励。

### UI、AI、经济、教程与QA配套

- UI：显示Ammo、当前packet数、Crit Damage倍率、Quest分支/进度/完成状态、Cyber本战团队成长、Concealed本场Gold已领取、Dart的Slow目标域与Leader Poison目标。
- AI：估算Ammo余量、未来Reload、Cannonade可获得的外部Charge、Quest完成剩余root、团队Weapon锚点数和本场剩余可兑现uses；不能只比较卡面伤害。
- 经济：Concealed奖励与战斗创建同一幂等事务；多副本按source instance分别审计，不能共用名字键；复制和回档要有明确防重复策略。
- 教程：双刀/双斩不等于两个operation；Multicast只重复完整packet；Crit Damage不是Crit Chance；任务分支必须在玩家可见处锁定；Dart当前没有直接伤害。
- QA：固定种子覆盖多packet独立Crit但root消费者一次、空Ammo、Reload、Damage致死后Burn skip、Haste无目标但Damage继续、开战奖励重放、Quest合成/复制/出售、Cyber源退出、Dart无Slow目标仍Poison、Leader缺失技术失败。

### 第 19 轮进度

八只最终暂名：双锋凤蝶、炮角黑犀、三响雷袋鼠、灼爪食蚁兽、藏锋穿山甲、弯盔鹤鸵、脉叉三角龙、麻针海胆。

累计已有 **99/138** 个Vanessa原生对象完成逐项身份、机制骨架、风险和模块审阅。Butterfly Swords与Cutlass可进入无数值骨架；Cannon带Ammo/派生参数门禁；Cannonade、Cauterizing Blade、Concealed Dagger、Cyber-Sai、Dart Launcher保持红色阻断，分别等待动态冷却、任务持久化、经济事务、团队成长上限与Leader Poison基础设施。

下一批舰炮兵器C：Dive Weights、Double Barrel、Elemental Depth Charge、Flagship、Grapeshot、Grappling Hook、Grenade、Handaxe。仍先做17.2来源、身份、事务骨架和配套，不填正式数值。

## 第 20 轮：舰炮兵器 C（弹药取样、动态连发、标签存在与装填反应）

本批八项为 Dive Weights、Double Barrel、Elemental Depth Charge、Flagship、Grapeshot、Grappling Hook、Grenade、Handaxe，对应旧锚点 `pal_039`、`pal_042`、`pal_044`、`pal_048`、`pal_050`、`pal_051`、`pal_052`、`pal_053`。三组继续只读审阅，没有写正式数值、CSV、生成JSON或运行时代码。

### 来源账本与版本停止线

主审于2026-08-17再次打开当前直达页。七项页头与卡内版本均明确为17.2；Grapeshot当前卡页仍停在17.1 Hotfix Aug 7，因此只确认其当前可读机制，不把数据库站点总版本冒充为该卡17.2版本。

| 来源 | 当前首选键 | 版本与机制事实 | 旧表处理 |
|---|---|---|---|
| Dive Weights | `12cdlp288b935dj9njzg224nqd3`；`c7w...`为alias | 17.2；Aquatic/Tool/Apparel，Ammo 4；主动Haste；左右Aquatic分别给自身固定冷却缩减；当前Ammo加到Multicast | 旧冷却档过时；相邻必须改写成可见棋盘关系 |
| Double Barrel | `9h9lh5cfccxc7hjbfvxf9yvnc9`；`3l7...`为alias | 17.2；Weapon、Ammo 2、固定Multicast 2、Damage | 旧表漏Ammo与固定连发 |
| Elemental Depth Charge | `xvmdl5k9184955xk080gc1lxlh`；`aif...`为alias | 17.2；Aquatic/Tech/Trap，Ammo 1；每次使用Burn opponent、Poison opponent、Freeze一个enemy item；每个其他Aquatic加Multicast | 旧表没有表达三operation、一次弹药消耗和整包连发 |
| Flagship | `p29lb7zh58cjqxx312j9jhc34k`；`7ycf...`为alias | 17.2；Aquatic/Vehicle/Weapon；Property、Tool、Friend、AmmoMax>0、Relic五个“至少存在一个”独立光环，各加1 Multicast | 禁止把“for each”误读为每个对象数量 |
| Grapeshot | `165f8d8cfp1938p158mf40cb73d`；`dnj...`为旧alias | 当前卡页17.1 Hotfix；Weapon、Ammo 1、Damage；另一Ammo对象使用后自身Reload | 机制可继续审阅，但标 `17.2_change_unverified` |
| Grappling Hook | `bq3dcd3btfn5t9clmn9jhtyd13`；`41v...`为alias | 17.2；Weapon/Tool；Damage并Slow固定两个有冷却的敌方item，品质成长Slow时长 | 旧表把目标数与时长写反；当前没有Pull、Destroy或位移 |
| Grenade | `7gzm05wdg3808j52q1c7cfq77p` | 17.2；Weapon、Ammo 1、固有Crit Chance、单次高Damage | 旧高阶伤害档过时，且漏Ammo/Crit；名称不提供AOE依据 |
| Handaxe | `xm32d2v1gd5xdqy0vmkdm7hl15` | 17.2；Weapon；主动Damage；Deep明确给board Weapons增加DamageAmount，包含自身 | public因图标抽取缺损只显示“Your items have +…”，不能解释成全体物品 |

当前页面：

- https://bazaardb.gg/card/12cdlp288b935dj9njzg224nqd3/Dive-Weights
- https://bazaardb.gg/card/9h9lh5cfccxc7hjbfvxf9yvnc9/Double-Barrel
- https://bazaardb.gg/card/xvmdl5k9184955xk080gc1lxlh/Elemental-Depth-Charge
- https://bazaardb.gg/card/p29lb7zh58cjqxx312j9jhc34k/Flagship
- https://bazaardb.gg/card/165f8d8cfp1938p158mf40cb73d/Grapeshot
- https://bazaardb.gg/card/bq3dcd3btfn5t9clmn9jhtyd13/Grappling-Hook
- https://bazaardb.gg/card/7gzm05wdg3808j52q1c7cfq77p/Grenade
- https://bazaardb.gg/card/xm32d2v1gd5xdqy0vmkdm7hl15/Handaxe

### 身份组独立提案与单体边界

| 映射 | 暂定宠物 | 本体动作与VFX | 旧底稿复用边界 | 主类 |
|---|---|---|---|---|
| Dive Weights / `pal_039` | 沉耳跃兔 | 钙化重耳贴背下潜，后腿蹬水释放加速尾流；四枚气泡耳环只表示Ammo；连发只是同一身体重复尾流 | 高复用巨兔身、长耳与银甲，删除泛雷电；以重耳压潜动作区分普通兔和飞鱼 | 迁器械载具 |
| Double Barrel / `pal_042` | 双响炎牛 | 两根中空角腔先后反冲；同一只牛、一次A、两个完整packet | 中高复用牛身和巨角；持续火鬃改短促琥珀膛焰，避免误读Burn | 舰炮兵器 |
| Elemental Depth Charge / `pal_044` | 三相爆鳍蓑鲉 | 放射鳍收拢下潜后释放毒、热、冷三相；三效果来自同一身体，不拆成三宠 | 旧鸦物种弃用，只保留冰蓝/炽橙并补毒绿的材质参考 | 舰炮兵器 |
| Flagship / `pal_048` | 舰帆棘龙 | 高背帆有五枚类别徽记，每类存在只亮一次；同一长吻重复齐射，不生成舰队 | 豪猪物种弃用，仅借背部节律；以高帆长吻与三角龙、Shipwreck区分 | 迁器械载具 |
| Grapeshot / `pal_050` | 散弹蜂后 | 单只装甲蜂后，蜂腹弹巢喷出锥形颗粒但只形成一个命中章；外部Ammo使用时只回装 | 仅保留中央金蜂，删除四只卫蜂；明确 `body_count=1`、禁swarm标签 | 舰炮兵器 |
| Grappling Hook / `pal_051` | 钩臂树懒 | 双长臂弯爪压住两个敌方技能框形成Slow；英雄Damage另走中央冲击；所有坐标不变 | 蜂翼花冠弃用，只借紫青配色；长臂倒V轮廓避开螳螂与猿猴 | 舰炮兵器 |
| Grenade / `pal_052` | 爆腺炮步甲 | 腹腺汇流后尾端单次爆喷；一个腹灯表示Ammo，临界闪星只表达Crit | 山猫物种弃用；低伏甲虫与鹿角虫、蜂后的轮廓和发射方向分开 | 舰炮兵器 |
| Handaxe / `pal_053` | 斧喙犀鸟 | 厚楔喙下劈主动攻击；被动只让全盘Weapon技能徽记出现锋芒，不表现追击 | 雪貂与冰色全部弃用，避免Freeze误读；以楔喙高冠区分其他鸟类 | 舰炮兵器 |

八项均为 `proper_name=false`、`lifeform=single_pet`、`body_count=1`。双角、三相、五徽记、散弹粒子、两条抓钩和多packet都不能创建额外unit、血条或占格。

身份主类迁移正式接受 Dive Weights 与 Flagship 从舰炮兵器进入器械载具。迁移只改变 `identity_family` 与图鉴/美术归类，不给Dive补Vehicle标签，也不把Flagship画成船体据点。原生138分类从第19轮 `24/55/23/13/15/8` 更新为 **海兽24 / 舰炮53 / 器械25 / 船体13 / 奇物15 / 自然8 = 138**；Pontoon跨英雄draft另加器械时为 `24/53/26/13/15/8=139`。

### 三方机制矩阵与主审裁决

| 项 | 执行骨架 | root / packet / operation / application | 本地转译与门禁 | 风险 |
|---|---|---|---|---|
| Dive Weights | `support_multicast_ammo`；A=催动其他友宠tempo anchor；B空 | prepare冻结 `ammo_before_spend`、packet目标序列和关系；`packet_count=1+ammo_before_spend`；root只扣1 Ammo、启1次CD，每包一个Haste op | 同排左右一格Aquatic采用回合开始快照；移动/死亡/exit立即断边，中途移入下回合接入。每包确定性抽目标、允许重复；首版排除自身A，避免效果结束前自身CD尚未启动导致假催动 | 深红 |
| Double Barrel | `attack_multicast_ammo`；A=Damage；B空 | 一个root、固定2个完整Damage packet；AP/Ammo/CD各一次 | 两包冻结同一目标。第一包致死后第二包写 `TARGET_DEFEATED` 并跳过，不改投 | 红 |
| Elemental Depth Charge | `support_bundle_multicast_ammo`；A=Burn→Poison→Freeze；B空 | prepare冻结其他在场Aquatic数量与三类目标；每packet三operation；一次Ammo | **保留来源双目标域**：Burn/Poison写敌方LeaderCombatant，Freeze写敌方宠物tempo anchor。拒绝为省模块改成同一普通单位；LeaderStatusService未齐前红色阻断。某一状态免疫只skip对应application，不撤销同包其他成功项 | 深红 |
| Flagship | `attack_dynamic_multicast`；A=Damage；B空 | prepare冻结五个布尔category flags；每个true贡献一个额外完整packet | 只看存活未exit的其他宠物；同类多个宠只算一次，同一宠同时满足不同类可贡献多类；最多+5。无邻接、无数量累加、无自身Ammo | 红 |
| Grapeshot | `attack_ammo + reactive_reload`；A=Damage；B空 | A普通Damage root；监听另一Ammo实体的已提交use root，每root至多给自身一个Reload operation | child packet不是新use；自身A不触发；满弹clamp0不发`AMMO_RELOADED`；Reload不产生skill-use所以两只Grapeshot不递归 | 红且来源门禁 |
| Grappling Hook | `attack_bundle`；A=Damage→Slow最多2个敌方tempo anchors；B空 | 一个root；Damage后对预冻结且无放回的两个敌方技能执行Slow application | Damage目标与Slow目标可不同。若Damage使某冻结Slow目标败北，则跳过且不补抽。禁止pull、forced move、Destroy；结算前后坐标不变 | 红 |
| Grenade | `attack_ammo_skill_crit`；A=Damage；B空 | 一root一次Ammo；外部Multicast时每packet独立确定性Crit，消费者仍once/root | 推荐单体/半径0；爆炸仅VFX，不凭名称增加AOE、自毁或Burn。固有Crit只属于其攻击锚点 | 黄红 |
| Handaxe | `attack_with_passive_aura`；A=Damage；B空 | A普通Damage root；被动在modifier收集阶段给每个合法Weapon anchor加Damage，不发伪skill-use | 覆盖自身与当前在场Weapon宠物，每宠只作用显式 `weapon_anchor_skill_id`。来源死亡/exit立即撤销；非Weapon、DOT、召唤和宠物第二技能不受益 | 黄 |

### 交叉争议、撤回与最终理由

#### 1. Handaxe是“全部物品”还是“仅Weapon”

身份组按public显示文本提出“全盘所有物品”；战斗组与数值组按Deep提出“仅board Weapons”。主审实时复核17.2页：public确实因图标抽取缺失只剩 `Your items have +…`，但Deep的Aura明确为“把Custom_0加到board上Weapons的DamageAmount”。最终采用Deep的结构化目标域：只强化Weapon锚点。身份组原提案中“全体卡边缘亮起”撤回，改为只点亮Weapon技能徽记。

#### 2. Elemental Depth Charge是否把Leader状态改投普通宠物

战斗组为适配当前代码提出 `leader_to_unit` 裁剪；身份组VFX和来源public/Deep都维持Burn/Poison对opponent、Freeze对item。主审反对静默改变反制层：玩家持续状态与单位状态在胜负、净化、死亡和目标选择上并不等价。最终保留敌Leader Burn/Poison与敌宠Freeze两个目标域，标记 `LeaderStatusService` 硬阻断。未来若产品明确不要英雄状态，必须作为玩法偏离重新会审，不在本轮偷改。

#### 3. Dive Weights先扣Ammo还是先读取连发

来源只写“当前Ammo加到Multicast”，本地必须冻结事务顺序。最终候选固定为：

```text
prepare: validate target and Ammo > 0
snapshot: ammo_before_spend
derive: packet_count = 1 + ammo_before_spend
reserve/commit: spend exactly 1 Ammo for the root
execute: packet[0..packet_count-1]
```

这样同一次使用的包数在prepare后不会被自己的Ammo消耗改写，Reload也不能在root中途追加包。此为本地明确顺序，不冒充来源隐藏实现；因为满弹时峰值很高，仍需全局packet cap、1/5/12回合模拟和Reload网络压测。

#### 4. Flagship按对象数量还是按类别存在

17.2 Deep是Property、Tool、Friend、AmmoMax>0、Relic五条独立“至少存在一个”Aura。故同类有两个宠仍只贡献1；同一只其他宠同时具Tool与Friend可贡献2个不同类别；来源自身不计。不得把五类变成一个按宠物数量求和的通用selector。

#### 5. Grappling Hook是否需要拉拽模块

三组一致反对按名字新增拉拽。当前来源只有Damage和Slow两个敌方冷却对象，本地应通过钩爪压住技能框表达阻滞，但单位坐标完全不变。本批明确不新增 `PullService`、`ForcedMoveService` 或Destroy链。如果未来另做拉拽宠物，应单独定义占格冲突、不可移动、满棋盘、路径、死亡和回放合同。

### 公共事务合同

1. root prepare统一冻结 `source_entity_id / skill_instance_id / target_unit_ids / target_skill_ids / relation_snapshot_id / ammo_before / multicast_basis / packet_count / category_flags / seed_cursor`。
2. 无合法目标或无Ammo在提交前返回 `NO_EFFECT_TARGET/NO_AMMO`；不扣AP、不启CD、不发`SKILL_USED`。
3. Ammo、AP、主动CD每root只预留/支付一次；packet不是新skill use，也不再次扣资源。
4. Damage继续沿正式 `SkillEffectPort.apply_physical_damage -> damage_death_service` 即时死亡链；后续operation/packet遇到已败北冻结目标只skip、不重定向。
5. Reload只监听已提交root；`delta=min(requested,max-current)`，只有正delta才发 `AMMO_RELOADED`。
6. Trace至少记录packet、operation、application、目标、before/after、成功/skip理由、Crit、Ammo快照/消耗/余量、Reload请求/实增与death event IDs。

### 成长预算方向（不填正式数值）

- Dive Weights：成长只放Haste效果或基础冷却中的一轴；Ammo上限、邻接减CD和当前Ammo转包数保持固定。压测满弹首root、双Aquatic邻接和Reload补弹。
- Double Barrel：只成长基础Damage；Ammo2、固定双packet和目标域不增长。
- Elemental Depth Charge：Burn/Poison/Freeze三轴必须交替或共享预算，禁止同阶段三项同步放大；Ammo和每个Aquatic加包固定。
- Flagship：只成长Damage或基础冷却；五类资格和每类+1固定，并用最多五类场景做峰值门禁。
- Grapeshot：只成长Damage；Ammo1、Reload量和触发域固定；在17.2卡级来源补证前不进正式数值。
- Grappling Hook：只成长Damage或Slow时长之一；目标数固定2，禁止引入位移作为额外预算。
- Grenade：只成长基础Damage；Ammo1、固有Crit和单体目标固定。
- Handaxe：主动Damage与团队Weapon光环交替成长；受益Weapon锚点数量不增长，多来源叠加策略须先定。

### 代码模块补充与归并

本批复用前轮的 `AmmoResourceService`、`MulticastPacketExecutor`、`SupportSkillExecutionPolicy`、`SkillCooldownService`、`BoardRelationService`、`LeaderCombatantState/LeaderStatusService`、`modifier_collector` 与 `damage_death_service`，新增或细化：

1. `DynamicPacketCountResolver`：统一从使用前Ammo、标签类别存在、外部光环等快照派生packet数，禁止执行中回写包数。
2. `TagCategoryPresenceResolver`：Flagship这类“每类至少存在一个”按类别布尔值解析，保留同一实体贡献多个不同类别的能力。
3. `AmmoUseCommittedConsumer`：Grapeshot等只监听外层已提交Ammo root，内建once/root、自身排除和reaction递归防护。
4. `SkillLocalCritModifierChannel`：Grenade固有Crit只附着一个skill instance，不污染宠物其他技能。
5. `AuraStackingPolicy`：Handaxe等团队静态光环显式记录来源叠加、本地max/add/cap规则；未裁决前不写正式数值。
6. `LeaderStatusService`：仍是EDC、Dart、Wetware等跨批次共同P0；必须接正式CombatantState、Result/Trace/Snapshot，不能用普通宠物状态代替。

本批明确不新增：Destroy、Pull、ForcedMove、技能条邻接解释器、按物品名称推导AOE的隐式规则。

### UI、AI、教程、经济与QA配套

- UI：显示Ammo当前/上限、本次预览packet数、Dive左右水族关系线、Flagship五类徽记、Grapeshot装填来源、Hook两个Slow目标、Grenade固有Crit、Handaxe实际Weapon受益技能。
- AI：按使用前Ammo估算Dive峰值；按五类布尔值而非宠数估算Flagship；把Ammo使用的Grapeshot回装价值计入行动评分；Hook不得把不存在的位移价值加入估值。
- 教程：解释“一次发动、多packet、只扣一发弹”；散弹与爆炸视觉不等于多目标；Hook名称不代表移动；Handaxe只强化Weapon。
- QA：固定种子覆盖Dive满弹包数/一次扣弹、双Aquatic邻接断链、Double首包击杀、EDC三operation与Leader缺失失败、Flagship一宠多标签/同类多宠、Grapeshot满弹no-op与双实例不递归、Hook坐标不变、Grenade单体Crit回放、Handaxe源退出即时撤光环。

### 第 20 轮进度

八只最终暂名：沉耳跃兔、双响炎牛、三相爆鳍蓑鲉、舰帆棘龙、散弹蜂后、钩臂树懒、爆腺炮步甲、斧喙犀鸟。

累计已有 **107/138** 个Vanessa原生对象完成逐项身份、机制骨架、风险与模块审阅。Handaxe可进入无数值骨架；Grenade为黄红门禁；Dive、Double Barrel、Elemental Depth Charge、Flagship、Grapeshot、Grappling Hook仍等待Ammo/Multicast/Cooldown/Leader状态等公共能力，其中Grapeshot还保留card-level 17.2来源停止线。

下一批舰炮兵器D：Harpoon、Ice Pick、Javelin、Jitte、Katana、Kusarigama、Langxian、Musket。继续先核当前来源、身份、事务骨架和配套，不填正式数值。

## 第 21 轮：舰炮兵器 D（非死亡封存、控制成长、胜场进度与燃烧装填）

本批八项为 Harpoon、Ice Pick、Javelin、Jitte、Katana、Kusarigama、Langxian、Musket，对应旧锚点 `pal_054`、`pal_057`、`pal_062`、`pal_065`、`pal_066`、`pal_068`、`pal_069`、`pal_077`。三组继续只读审阅；没有写正式数值、CSV、生成 JSON 或运行时代码。

### 来源账本、缓存分歧与旧表撤回

主审在 2026-08-17 重新打开八个当前直达页。Harpoon、Ice Pick、Javelin、Jitte、Katana、Kusarigama、Langxian 均核到当前 17.2 内容；Musket 较早抓取一度显示卡级 17.1 Hotfix，稍后刷新同一 `gtmq...` 页面时，数据库页头与卡片 `As of` 均明确变为 17.2，且 public/Deep 内容签名一致。日志保留这次缓存时序纠错，不再把早期 17.1 结果当停止线。

| 来源 | 当前首选键 | 当前来源事实 | 旧表/旧方案处理 |
|---|---|---|---|
| Harpoon | `pkm710pjqsw7bqsfqq016bhlg0` | 17.2；Aquatic、Medium、Silver+、Ammo 2；使用时随机 Destroy 一个敌方 Small item 至战末 | 禁止从名称派生拉拽；旧 `mech_death_explosion` 整条撤回 |
| Ice Pick | `wdjp7q7gyhv1lsmzskhygpbbmz` | 17.2；Weapon/Tool；Damage+Freeze；任意己方成功Freeze后自身本战增伤 | 旧成长档过时；旧反伤机制撤回 |
| Javelin | `6mykdnnhbmzvz10x99yk7vmnvx` | 17.2；Weapon、Ammo 2；Deep优先级 High Haste所有其他有冷却对象，再Medium Damage | 旧表漏Ammo与效果顺序；不得把“其他”包含自身 |
| Jitte | `155f5m272x60fhz5q3fd8924s1y` | 17.2；Weapon；Damage+Slow；任意己方成功Slow后自身本战增伤 | 旧成长档过时；旧反伤机制撤回 |
| Katana | `513qroz76xl1kpbo6yvqwk31o`；另见同内容alias `f9x...` | 17.2；Weapon；短冷却纯Damage | 旧每回合成长撤回；无来源Crit/Haste/多段被动 |
| Kusarigama | `c0fucfgrlkbq2ym4bwv72bh9g` | 17.2；Weapon/Tech；主动Damage；Slow与Crit是两条独立成长能力，均强化自身及相邻Weapons | 不合并成未经声明的单一OR能力；旧反伤撤回 |
| Langxian | `f0t6yg4xnhssvjktvnqjb1p458`；`4wz...`保留alias审计 | 17.2；Weapon/Relic；基础Damage；随携带它赢得战斗的次数永久成长，Deep以胜场计数乘当前品质系数 | 删除旧每回合成长；必须转为Run实例进度与战后幂等事务 |
| Musket | `gtmqtl5hcvx4yv41v5dv15v64k` | **17.2刷新确认**；Weapon、Ammo 1；任意己方棋盘Burn后分别Reload自身并获得本战Damage成长 | `RETRACTED`：旧相邻Burn、旧伤害档、旧成长档；不再保留17.1停止线 |

当前页面：

- https://bazaardb.gg/card/pkm710pjqsw7bqsfqq016bhlg0/Harpoon
- https://bazaardb.gg/card/wdjp7q7gyhv1lsmzskhygpbbmz/Ice-Pick
- https://bazaardb.gg/card/6mykdnnhbmzvz10x99yk7vmnvx/Javelin
- https://bazaardb.gg/card/155f5m272x60fhz5q3fd8924s1y/Jitte
- https://bazaardb.gg/card/513qroz76xl1kpbo6yvqwk31o/Katana
- https://bazaardb.gg/card/c0fucfgrlkbq2ym4bwv72bh9g/Kusarigama
- https://bazaardb.gg/card/f0t6yg4xnhssvjktvnqjb1p458/Langxian
- https://bazaardb.gg/card/gtmqtl5hcvx4yv41v5dv15v64k/Musket

### 身份组独立方案与单体边界

| 映射 | 暂定宠物 | 本体动作与VFX | 旧底稿复用边界 |
|---|---|---|---|
| Harpoon / `pal_054` | 穿浪鲣鸟 | 针喙垂直俯冲，锁定轻量目标后使其淡出并显示封存徽记；不画绳索、位移、伤害数字或死亡爆炸 | 雪猿物种弃用，只留青白配色与水光 |
| Ice Pick / `pal_057` | 凿霜银狐 | 低伏银狐以前爪凿出单点冰裂；成功Freeze后爪部结晶逐层增亮 | 高复用银狐体态、冰色与单大尾，吹息动作改为爪凿 |
| Javelin / `pal_062` | 贯风雷猿 | 前臂贯击/投出单体风矢，随后雷纹尾流横扫其他合法友宠技能锚；两枚臂环表示Ammo | 高复用正式雷纹巨猿底稿，以重臂、蓝黑雷纹和鼓舞尾流避免与豪猪重复 |
| Jitte / `pal_065` | 迟锋棘蜥 | 贴地圆盘体、三叉鼻冠短顶；目标出现阻滞环，自身背棘因Slow成功逐层点亮 | 犀牛轮廓重做，只借暗紫甲片与三叉节奏 |
| Katana / `pal_066` | 刃鳞青蛇 | 单圈S形盘身与扁刃尾，只出一道窄月牙单点快斩 | 中高复用青金鳞、盘身与背鳍；不持刀，不画AOE或多段 |
| Kusarigama / `pal_068` | 环刃梦貘 | 长鼻卷出单点月弧；Slow/Crit触发后只点亮自身及已锁定的左右邻Weapon短弧线 | 高复用黑貘、云梦与月牙；删除实体锁链、拉拽和换位暗示 |
| Langxian / `pal_069` | 胜棘甲龙 | 战内单体顶刺；胜利结算后背棘增加一道可读刻痕 | 岩甲材质和厚重底盘可留，龟壳边界改为甲龙长体 |
| Musket / `pal_077` | 燧喉角鸮 | 单发喉囊压燃喷射；棋盘任意Burn后微火星汇入喉囊，表现装填与战内增亮 | 黑橙羽材质可留，乌鸦改为圆面角鸮；禁止邻接线 |

八项均为 `proper_name=false`、`lifeform=single_pet`、`body_count=1`，只有一个unit、一个HP条和一个占格。全部保留舰炮兵器主类，本轮分类账不变：原生138仍为 **海兽24 / 舰炮53 / 器械25 / 船体13 / 奇物15 / 自然8**；Pontoon跨英雄draft另加器械时为 `24/53/26/13/15/8=139`。

### 三组机制矩阵与主审裁决

| 项 | 执行骨架 | 事务语义 | 本地门禁 | 风险 |
|---|---|---|---|---|
| Harpoon | `support_destroy_ammo` | 一个root、一次Ammo、一个Destroy operation、一个非死亡UnitExit application | 只筛独立 `combat_weight_class=light` 且非Boss/英雄/DestroyImmune；无目标提交前拒绝 | 深红，暂停执行层 |
| Ice Pick | `attack_status_bundle + passive` | Damage后Freeze；Freeze消费者once/root，在root_end写未来Damage成长 | Damage致死则Freeze `TARGET_GONE`，不重抽；免疫/无效不成长 | 红 |
| Javelin | `attack_support_bundle_ammo` | 每packet固定 Haste其他合法tempo anchors → Damage；整个root只耗一次Ammo/AP/CD | 排除自身、被动和无冷却技能；一宠只认一个tempo anchor | 红 |
| Jitte | `attack_status_bundle + passive` | Damage后Slow；Slow消费者once/root，在root_end写未来Damage成长 | 目标败北不重抽；同root所有Damage读root_start快照 | 红 |
| Katana | `attack` | 一个root、一个单点Damage packet；外部Crit/Haste仍走公共系统 | 基础无Ammo、Multicast、Crit/Haste消费者或成长 | 黄，可进无数值骨架 |
| Kusarigama | `attack + two_passive_consumers` | 主动单点Damage；Slow、Crit两个通道各once/root，同root同时满足可提交两批成长 | 回合开始锁定同排x±1 Weapon；断链即时，新移入下回合接入 | 红 |
| Langxian | `attack + post_battle_progression` | 战内只有Damage；胜利后独立幂等事务增加实例 `wins_with_source` | 当前Damage由基础值+胜场数×当前品质系数派生，不双存变异Damage | 深红，暂停持久化层 |
| Musket | `attack_ammo + passive_reaction` | Burn来源root结束后一个reaction packet，内含 Reload self → AddBattleDamage 两个operation | board-global、once/root；满弹只让Reload clamp0，成长仍提交 | 红 |

### 关键对质、撤回与最后选择

#### 1. Harpoon的Destroy如何进入四宠棋盘

三组一致确认它不是拉拽、位移、伤害或死亡。数值组早期提出“只禁用目标tempo anchor”以降低四宠制中整宠退场的强度；身份组与战斗组认为这会留下身体、被动和另一技能，无法保持来源Destroy的核心体验。主审最终采用A案作为来源保真骨架，但保持红色暂停：

```text
eligible = enemy active unit
        && combat_weight_class == light
        && !boss && !hero && !destroy_immune
result = UnitExit(reason=destroy_banish, duration=battle)
```

`combat_weight_class` 是新的本地战斗资格，不等于来源Small、视觉大小、HP、品质、形状覆盖或棋盘占格。目标正在结算的原子root先完成，再在安全点退出；已排队但未开始的行动取消。退出时注销技能条、被动订阅和关系边，释放格位，并重算胜负；不调用死亡服务，不发DEATH/KILL/CORPSE/LOOT，不触发旧死亡爆炸、死亡召唤或击杀收益。战末恢复、回撤、重放和存档必须幂等。

“只封锁tempo anchor至战末”保留为强度压测失败后的明确安全偏离，不静默替换。正式数值前还要冻结每root/每战最大封存数、Multicast上限和轻量单位池。

#### 2. Ice Pick与Jitte何时成长

只有成功的Freeze/Slow application进入对应root成功集合；免疫、目标消失或clamp0不算。同root即使有Multicast、多目标或重复application也各通道至多触发一次；成长统一在root_end提交，当前root全部packet使用root_start属性快照，避免第一包控制即时放大后续包。

#### 3. Javelin为什么先催动再伤害

public排版不足以确定顺序，Deep明确把Haste列为High、Damage列为Medium。故每packet先催动所有其他合法友宠的 `tempo_anchor_skill_id`，再结算单体Damage。某目标已ready导致Haste clamp0，不影响后续Damage；下游“当你Haste”消费者等父root完整结束后处理，不能在Haste与Damage之间插入额外技能。

#### 4. Kusarigama是一条OR还是两个消费者

Deep确实是Slow与Crit两条独立ability。最终保留：

```text
dedupe_key = (consumer_id, root_id, slow_channel)
dedupe_key = (consumer_id, root_id, crit_channel)
```

因此Slow-only或Crit-only各成长一次，同一root两类都发生时最多两次。“Slow OR Crit联合once/root”只保留为超预算时的显式安全裁剪。关系沿已冻结词典使用玩家可见棋盘回合快照：同排正左/正右一格、只认Weapon锚；移动、死亡、撤回或UnitExit立即断链，本回合新移入者下回合才接入。已经获得的本战成长不追回。

#### 5. Langxian的“with this”如何记胜

本地采用开战阵容锁定作为资格基线：普通战斗死亡不取消，未出手/未尾刀也可计；明确被Destroy/UnitExit封存则取消本场成长，以保留封存的反制价值。该项是本地规则补全，不冒充来源隐藏实现。

权威字段只保存 `wins_with_source`、最后提交battle_id与必要cap；面板Damage每次读取时由 `base + wins_with_source * coefficient(current_quality)`派生。升级因此会追溯放大旧胜场，符合当前Deep结构；若改成逐场按当时品质固化，必须标来源偏离。BATTLE_ENDED事务以 `run_id + battle_id + source_instance_id + progression_id` 幂等，失败、投降、回撤、回放和重复读档不能重复累计。

#### 6. Musket的版本与触发域

身份组和数值组较早抓到卡级17.1，战斗组与主审随后重开同一 `gtmq...` 页面，页头及卡内 `As of` 均已变为17.2；Deep明确两条独立Lowest ability：任意己方board item施加Burn后Reload自身，并增加自身本战Damage。最终撤销来源停止线和所有adjacent方案。

每个Burn来源root共同去重一次，随后固定执行Reload→成长。满弹时Reload为clamped no-op且不发 `RELOAD_SUCCEEDED`，但成长不依赖装填成功，仍正常提交；多packet、多目标Burn不会在同root重复喂养。

### 成长预算方向（不填正式数值）

- Harpoon：q0锁定；解锁后只改善冷却，不增加Ammo、目标数、轻量等级或退出cap。对四宠编队影响巨大，必须压测1/5/12回合与Reload/Multicast。
- Ice Pick：只提高基础Damage或每次Freeze成长中的一轴；Freeze结构、目标数与消费者频率固定。
- Javelin：Damage与Haste效果进入共享预算或交替阶段；Ammo、其他宠数量与目标域不增长。
- Jitte：Slow时长与成长量交替；目标数固定，同root不因多包多次成长。
- Katana：只成长Damage，保持高速单点基准，不增加额外机制。
- Kusarigama：基础Damage与每批团队成长交替；邻接半径、受益锚点数与双通道上限固定。
- Langxian：真正预算轴是整局胜场上限与品质系数回算；必须有run成长cap、升级跳变、合成/复制/出售压测。
- Musket：主动Damage与每次Burn成长共享预算；Ammo上限、Reload量和once/root固定，重点压测燃烧网络带来的装填—成长耦合。

### 代码模块补充与归并

继续优先扩展正式 `GameSession -> Command -> Result/Trace/Snapshot` 链，不给单只宠物旁造服务：

1. `CombatWeightClassRegistry`：独立声明轻/中/重战斗资格；与来源尺寸、占格、HP、形状和品质解耦。
2. `UnitExitService` 扩展 `destroy_banish`：非死亡退出、注销订阅/技能/关系、释放格位、胜负重算、战末幂等恢复；消费者按exit reason白名单订阅。
3. `RootOutcomeAggregator`：把Freeze/Slow/Burn/Crit成功结果按 `root_id + event_kind` 聚合，统一once/root与root_end提交。
4. `SkillCooldownService` + `BoardSkillAnchorIndex`：Haste/Slow/Freeze只写明确tempo anchor，不改speed或共享技能条顺序。
5. `PersistentInstanceProgressService`：保存Langxian等实例胜场/任务进度，并处理合成、复制、升级、出售与跨Run清零协议。
6. `BattleResultIdempotencyLedger`：统一战后经验、奖励、胜场成长的battle_id幂等键和恢复。
7. `DerivedEffectParameterResolver`：由胜场计数与当前品质读取Langxian面板，不同时保存易漂移的派生Damage。
8. 复用已有路线中的 `AmmoResourceService`、`ReloadOperation`、`BoardRelationService`、`SkillParameterModifierLedger`、`CriticalOutcomeAggregator` 与四级事件信封。

本批明确不需要Pull/ForcedMove模块。Harpoon的纯support仍受当前 `SkillEffectPort.begin_skill` 强制攻击槽/方向/目标限制；正式实现前必须先有统一support入口和原子packet/bundle事务。

### UI、AI、经济、教程与QA配套

- UI：Harpoon展示“轻量可封存”与非死亡封存徽记；Ice Pick/Jitte显示本战成长；Javelin明确“催动其他宠”；Kusarigama画回合锁定短弧关系线与两个触发通道；Langxian显示胜场刻痕、当前品质系数和本次结算资格；Musket显示任意Burn来源、弹药与本战成长。
- AI：评分需纳入封存导致的整宠份额、Javelin全队tempo、控制成长剩余可兑现uses、Kusarigama邻接存续、Langxian局外长期价值和Musket未来Burn/Reload网络；不能只比较当次Damage。
- 存档/经济：Langxian进度必须绑定inventory instance，不以名字作键；复制、合成、升级、出售和回购分别定继承策略。Harpoon封存只属于battle state，绝不能污染永久库存。
- 教程：Destroy不是击杀或拉拽；控制成长只在本root结束后生效；Javelin催动不等于插入技能；Kusarigama两通道可各触发一次；Musket已经不要求相邻。
- QA：固定种子覆盖Harpoon无目标/免疫/最后单位/战末恢复，Ice Pick/Jitte状态免疫与同root多包，Javelin顺序/排除自身/一次Ammo，Katana无隐藏被动，Kusarigama单通道/双通道/断链/新移入，Langxian胜负/死亡/封存/回放/升级，Musket非相邻Burn/满弹/多Burn同root，以及全批12回合、镜像先后手和Trace幂等。

### 第 21 轮进度

八只最终暂名：穿浪鲣鸟、凿霜银狐、贯风雷猿、迟锋棘蜥、刃鳞青蛇、环刃梦貘、胜棘甲龙、燧喉角鸮。

累计已有 **115/138** 个Vanessa原生对象完成逐项身份、机制骨架、风险与模块审阅。Katana可进入无数值骨架；Ice Pick、Javelin、Jitte、Kusarigama带硬门禁；Harpoon等待轻量资格/非死亡封存上限，Langxian等待持久实例进度与幂等结算，Musket虽已解除17.2来源停止线，仍等待Ammo/Reload/本战成长权威模块。

下一批舰炮兵器E：Nesting Doll、Pistol Sword、Pop Snappers、Powder Keg、Repeater、Revolver、Rifle、Scimitar of the Deep。继续只讨论当前来源、宠物身份、事件骨架、代码模块和配套策划，不填正式数值。

## 第 22 轮：舰炮兵器 E（弹药反应、强制使用、自我退场与跨日成长）

本批八项为 Nesting Doll、Pistol Sword、Pop Snappers、Powder Keg、Repeater、Revolver、Rifle、Scimitar of the Deep。三组继续只读审阅，没有写正式数值、CSV、生成JSON或运行时代码。

### 正式映射与审计方法纠错

正式 `34_bazaar_objects.csv` 锚点为：

```text
Nesting Doll          bz_van_079 -> pal_079
Pistol Sword          bz_van_088 -> pal_088
Pop Snappers          bz_van_089 -> pal_089
Powder Keg            bz_van_092 -> pal_092
Repeater              bz_van_095 -> pal_095
Revolver              bz_van_096 -> pal_096
Rifle                 bz_van_097 -> pal_097
Scimitar of the Deep  bz_van_099 -> pal_099
```

身份组阶段消息曾沿用题面暂写序号，在未先读CSV `source_name` 列的情况下误报 `Pistol=087 / Pop=088`，并一度把原因归给生成JSON错位。主审用正式CSV复核后，三组均撤回该结论；生成JSON本身没有偏移，正式数据无需修复。该过程记为 `AUDIT_METHOD_ERROR`，不是内容数据缺陷。

### 17.2来源账本与旧表撤回

| 来源 | 当前首选键 / alias | 当前来源事实 | 旧表/旧方案处理 |
|---|---|---|---|
| Nesting Doll | `113kp5b01qpk3h12bmjyfcdnn1f` | Toy、Silver、Small、Ammo 8；使用时Shield=当前Ammo×品质倍率；每日开始永久+1 MaxAmmo | 无层数、变形、拆分或召唤；旧“随品质+1/2/3 MaxAmmo”过时 |
| Pistol Sword | `hwvx1qkljxn8wvt6dh9bw8xyvp`；`5zy...`历史alias | Weapon、Gold、Medium、Ammo 3；主动Damage；任意己方Ammo对象使用后再造成同额Damage | Deep的Ammo对象包含自身；自身root会同时兑现主动与反应Damage |
| Pop Snappers | `33zl8gh869n0xcyk79dw6vdflj` | Toy、Bronze、Small、Ammo 4；主动只施加Burn | 复数名称不是多体、多段或散射Damage；旧表漏Ammo/冷却 |
| Powder Keg | `g9qk9n6x4f6l9mthnhp486gt6y`；`5em...`旧alias | Weapon、Gold、Medium；Burn后Charge；按opponent MaxHealth造成固定比例Damage；自身成功apply Damage后Destroy self | 17.2已从“使用后Destroy”改为“成功Damage后Destroy”；早期“自毁走死亡钩子”撤回 |
| Repeater | `h4ssc5g0h1w16ngqzpt8x2ppb8` | Weapon、Silver、Medium；Ammo随品质；主动Damage；另一Ammo对象使用后强制Use自身 | 不是Multicast、Charge或普通追加伤害，必须进入真实forced-use事务 |
| Revolver | `8p3h8rlj3dubi1isq5q5b5gt3` | Weapon、Bronze、Small、Ammo 6；短冷却纯Damage | 六发只表示容量，不是一次六连发；旧表漏Ammo/冷却 |
| Rifle | `4n7b5szh36wgklvjq8k07c2fvc`；`1ric...`旧alias | Weapon、Bronze、Medium、Ammo 1；Damage后自身获得本战Damage成长 | 旧基础/成长档过时；不是每回合成长或自动Reload |
| Scimitar of the Deep | `5szlp8k6d461vn0sqr32e4jqt`；`hcg.../15k...`留alias审计 | Weapon/Relic/Aquatic、Silver、Medium；任意己方Crit后按自身Damage的25% Poison；自身获Haste后强化board Poison对象 | 旧50%毒比例、旧基础Damage和旧反击全部撤回 |

当前页面：

- https://bazaardb.gg/card/113kp5b01qpk3h12bmjyfcdnn1f/Nesting-Doll
- https://bazaardb.gg/card/hwvx1qkljxn8wvt6dh9bw8xyvp/Pistol-Sword
- https://bazaardb.gg/card/33zl8gh869n0xcyk79dw6vdflj/Pop-Snappers
- https://bazaardb.gg/card/g9qk9n6x4f6l9mthnhp486gt6y/Powder-Keg
- https://bazaardb.gg/card/h4ssc5g0h1w16ngqzpt8x2ppb8/Repeater
- https://bazaardb.gg/card/8p3h8rlj3dubi1isq5q5b5gt3/Revolver
- https://bazaardb.gg/card/4n7b5szh36wgklvjq8k07c2fvc/Rifle
- https://bazaardb.gg/card/5szlp8k6d461vn0sqr32e4jqt/Scimitar-of-the-Deep

### 身份组最终方案与单体边界

| 映射 | 暂定宠物 | 身体、动作与VFX | 旧底稿复用与防撞 | 主类 |
|---|---|---|---|---|
| Nesting Doll / `pal_079` | 层尾山狐 | 一只赤狐、一条巨尾；尾毛同心环显示Ammo/MaxAmmo，每日只多一圈刻纹。禁止开壳出现小狐、分身或第二HP条 | 高复用焰尾山狐体态/巨尾/甲片，雷火裂纹改为护盾环；与小体银狐靠大红甲与尾环区分 | 迁奇物谋略 |
| Pistol Sword / `pal_088` | 双响刃豪猪 | 自身root先弹出主动刃棘，再因Ammo身份产生一次reaction刃棘；仍是一只豪猪、一个root和一次资源支付 | 高复用冰棘豪猪低矮体与扇形长棘，冰紫改为金属棘与膛光 | 舰炮兵器 |
| Pop Snappers / `pal_089` | 爆响炎獒 | 一只獒完成一次爆吠Burn；颈圈/四爪火珠只显示Ammo。复数名只代表连续爆响 | 高复用狱火凶獒硕大犬体、火鬃与爆口；删除紫电 | 舰炮兵器 |
| Powder Keg / `pal_092` | 爆壳寄居蟹 | Burn火星汇入螺壳；重爆后软蟹从裂壳钻入烟幕并非死亡退场。空壳仅瞬时VFX，不留单位 | 青蛟物种与旧治疗职责全部弃用，只参考青绿金色；以巨大单螺壳构成独特轮廓 | 舰炮兵器 |
| Repeater / `pal_095` | 应鸣花鹿 | 另一Ammo root先在鹿角形成声环，再由本体做一次单体角鸣追击；不出现镜像鹿或回声分身 | 高复用纤细跃鹿与花角，把花雷改成共鸣膛光 | 舰炮兵器 |
| Revolver / `pal_096` | 六晶熔灵 | 一个矮壮熔灵，背部六颗膛晶轮转表示Ammo；每次只熄一晶、打一发 | 高复用黑橙熔岩体与晶簇；用矮圆暖色轮盘区分Rifle | 舰炮兵器 |
| Rifle / `pal_097` | 叠晶岩獒 | 一只四足岩獒以中央口晶单发；命中后背脊新增一层亮纹，供未来root成长 | 中高复用冷灰岩甲与紫晶背峰；四足长体/冷色纵晶区别Revolver | 舰炮兵器 |
| Scimitar / `pal_099` | 毒潮刃驼 | 主动一道弯月潮刃；Crit root点亮驼峰后向敌Leader送毒滴；自身受Haste时双峰向合法Poison技能徽记放出成长潮 | 中高复用双峰骆驼和高颈轮廓，山峰改半透明毒潮囊；旧反击撤回 | 舰炮兵器 |

八项均为一个unit、一个HP条、`body_count=1`、`proper_name=false`。Ammo格、同心层、复数名称、强制使用、自我Destroy和团队成长都不能创建额外单位。

Nesting Doll正式从舰炮兵器迁入奇物谋略：它当前无Weapon，核心是Toy、Shield与Run内跨日成长。迁类后原生138分类更新为 **海兽24 / 舰炮52 / 器械25 / 船体13 / 奇物16 / 自然8 = 138**；Pontoon跨英雄draft另加器械时为 `24/52/26/13/16/8=139`。

### Round21身份名的独立修正

正确映射下，`pal_088 Pistol Sword` 的正式豪猪底稿最适合“双响刃豪猪”。为保持139只宠的物种与轮廓唯一性，三组另行接受 `pal_062 Javelin` 从“掷风豪猪”更名为“贯风雷猿”，高复用其正式雷纹巨猿底稿。该项记为 `REVISED_NAME(reason=SPECIES_COLLISION_WITH_FORMAL_PAL_088)`，与前述ID审计错误无关；只改身份名、图鉴/本地化与动作语言，不改ID、品质、池、预算或战斗合同。Javelin仍是每packet先Haste其他友宠tempo anchor，再对冻结单体目标Damage，禁止范围伤害、Charge或位移暗示。

### 三组机制矩阵与主审裁决

| 项 | execution_mode | root / packet / operation / application | 本地转译与硬门禁 | 风险 |
|---|---|---|---|---|
| Nesting Doll | `support_shield_ammo + day_progression` | A消耗Ammo后按快照给己方Leader Shield；DAY_STARTED独立增加实例MaxAmmo | 本地顺序显式为consume→读`ammo_after_spend`→Shield；末弹可0 Shield但root成功。每日只增Max不补current；每战current=max初始化 | 红 |
| Pistol Sword | `attack_ammo + passive_ammo_use_damage` | 自身root含 `M`个主动Damage packet，再加一个once/root reaction Damage packet；AP/Ammo/CD各一次 | reaction可独立Crit，但不发ITEM_USED、不耗资源、不再触发Pistol/Repeater；两类包共享root-start目标 | 红 |
| Pop Snappers | `support_burn_ammo` | 一个root、一Ammo、一个Burn packet/op/application | 来源opponent保留为敌Leader Burn；抵抗/免疫不喂Burn消费者；无直接Damage、多段或Reload | 黄 |
| Powder Keg | `attack_percent_health + burn_charge + self_destroy` | 首个accepted Damage→即时死亡安全点→终局候选锁→self UnitExit→余包SOURCE_EXITED | 沿Anchor既定偏离把opponent伤害落敌方棋盘单位并设Boss上限；Destroy非死亡，不发亡语/尸体/死亡收益 | 深红 |
| Repeater | `attack_ammo + passive_forced_use` | 另一Ammo use后，在同causal root强制完整use一次；耗自身Ammo，绕CD/AP，resolve后CD重置max | 来源须在场、未硬锁/Freeze、有Ammo；visited source集合保证每个Repeater每因果根一次，A→B→A禁止 | 深红 |
| Revolver | `attack_ammo` | 一个root、一Ammo、一个Damage packet | 六Ammo不是六连发；纯弹药武器基准件 | 黄 |
| Rifle | `attack_ammo_growth` | 所有Multicast Damage包读root-start Damage；root_end聚合一次自身本战成长 | once/root是本地安全裁剪，避免同root阶梯；必须写translation deviation | 红 |
| Scimitar | `attack + crit_poison + haste_poison_growth` | 主动单点Damage；Crit消费者once/root给敌Leader Poison；Haste消费者once/root在root_end成长各Poison anchor | Crit毒读root-start Scimitar Damage，比例25%；同rootHaste不回溯放大本次毒；一宠只认一个Poison operation锚 | 深红 |

### 关键对质、撤回与最终理由

#### 1. Nesting Doll读取耗弹前还是耗弹后

来源Deep只证明Shield aura读取当前Ammo，没有公开证明Ammo消耗与aura采样的先后。两候选为：A读耗弹前，最后一弹仍有盾；B读耗弹后，与统一AmmoService的consume-before-effect一致。三组推荐B，并明确标 `local_order_policy=ammo_after_spend`：

```text
prevalidate ammo>0 and Leader handler
reserve/consume one Ammo
freeze ammo_after_spend
derive Shield amount
commit root
```

因此最后一弹可产生0 Shield，但仍是合法使用。每日+1只改Run实例的AmmoMax，不自动补当前战斗弹药；新战斗初始化 `ammo_current=ammo_max`。若玩家测试认为末弹0盾不可读，可回审A，但不能让表现层私自取不同快照。

#### 2. Pistol Sword自身是否触发自己的Ammo反应

Deep目标是board上任意 `AmmoMax>0` 的对象，明确包含自身。自身手动root因此有主动包与一个反应包，但反应不是第二次Use：不再发ITEM_USED，也不触发Pistol或Repeater。外部Multicast只增加主动完整包，不把once/root反应乘成同样包数。首包击败冻结目标后，后续包写TARGET_GONE且不改投。

#### 3. Powder Keg的Destroy到底是不是死亡

三组最终撤回第3轮早期“自毁走死亡钩子”。17.2 Deep已将触发改为自身成功apply Damage后Destroy self；在“一物品→一宠物”本地转译中，Destroy统一走 `UnitExit(reason=destroy_self)`：不发UNIT_DIED/KILL，不生成尸体、亡语、死亡召唤、击杀/遗物奖励或复活资格。护盾全吸收但accepted Damage application成立仍退出；目标免疫导致application被拒绝则不退出。首包触发退出后，其余Multicast包因SOURCE_EXITED取消。

#### 4. Powder Keg最后双方同时清空如何判

采用全局、非单宠特判的 `DECISIVE_DAMAGE_LATCH`：Damage packet内同步反伤、免死、替代和死亡安全点全部结算后，若敌方已无可战单位，先写己方胜利候选；再执行该root规定的mandatory self UnitExit，最后提交已锁结果。故Powder作为己方最后宠且同一伤害清空敌方时判使用方胜；若伤害未清空敌方而自身最后宠退出则判负。若同步子事务造成真正双清，仍按全局平局策略处理，不能在第一个HP=0时抢锁。Trace顺序为 `OUTCOME_CANDIDATE -> UNIT_EXIT -> OUTCOME_COMMITTED`。

#### 5. Repeater为何不能改成普通追加伤害

来源明确是Use self，必须真实消耗自身Ammo、产生完整主动包并在结束后把自身CD重置到max；只是绕过当前CD和AP。child的普通无弹/冻结/已退出失败不回滚已经提交的外层Ammo root；结构/handler故障则回滚整个causal事务。两个Repeater可各响应原始外部Ammo root一次，但 `forced_use_chain_id + visited_forced_use_source_ids` 阻止A→B→A递归和同tick重试。

#### 6. Rifle与Scimitar如何防同root阶梯

Rifle来源用后成长，Multicast下逐包成长语义可能导致同root阶梯。最终采用明确安全裁剪：全部Damage包读root-start快照，成长root_end once/root；Multicast只增加当根伤害包，不增加成长次数。

Scimitar的Crit→Poison与Haste→团队Poison成长是两个消费者，各once/root。同root两类都发生时，Crit毒读root-start，Haste成长root_end才生效；新成长只作用未来root。Crit触发来自任意己方board对象，不要求Scimitar自己Crit，也不按Aquatic数量或Aquatic触发者缩放。

### 成长预算方向（不填正式数值）

- Nesting Doll：本地品质只成长Shield倍率；每日AmmoMax固定+1。重点压测跨日上限、Reload、单次盾值与复制/出售套利。
- Pistol Sword：主动与反应共用Damage轴；Ammo、反应频率和目标域固定，按全队Ammo根数压测。
- Pop Snappers：只成长Burn；Ammo和冷却固定，风险主要来自Burn消费者网络。
- Powder Keg：比例、目标数与自退场固定，本地阶段只改善冷却；需Boss比例上限和最后单位胜负压测。
- Repeater：品质只增长AmmoMax；基础Damage固定，forced-use次数受Ammo、Reload与causal cap共同限制。
- Revolver：只成长Damage，保持高Ammo纯武器基准。
- Rifle：基础Damage与每root成长共享预算；Ammo1与once/root固定，压测Reload形成的等差累计。
- Scimitar：基础Damage与Haste后的团队Poison成长共享预算；25%派生比例、消费者频率与Poison锚点数固定。

### 经济、存档与代码模块补充

Nesting Doll的“永久”限定当前Run、当前inventory instance：`run_day_id + item_instance_id`每日幂等；同日购入不追领，升级保留已累计天数但不按新品质补历史，出售回购新实例不继承，复制/合成/拆分不能复制成长历史。至少保存 `instance_id / day_growth_count / last_applied_day_id / base_ammo_max`；战斗current Ammo属于battle ledger，不与Run持久值混写。

代码归并：

1. `AmmoResourceService`：root预验证、原子Spend、MaxAmmo派生、战斗初始化与Reload。
2. `ForcedUsePolicy` / `ReactionScheduler`：因果根、visited集合、child失败边界、CD reset与Trace。
3. `OutcomeResolver.DecisiveDamageLatch`：全局Damage同步子事务、候选结果、mandatory cleanup与平局策略。
4. `UnitExitService.destroy_self`：非死亡退出、注销技能/被动/关系、格位释放、战末恢复。
5. `RunInstanceProgressLedger`：每日事件幂等、实例成长、复制/合成/出售协议。
6. `LeaderCombatantState/LeaderStatusService`：Nesting的Shield、Pop/Scimitar的Burn/Poison权威目标。
7. 复用 `battle_hook_pipeline`、`modifier_collector`、`RootOutcomeAggregator`、`PercentHealthDamagePolicy` 与技能锚点注册表。

当前正式链仍缺Ammo、ForcedUse、非死亡UnitExit、终局候选锁、完整Leader Shield/Burn/Poison和Run实例每日成长；Powder、Repeater、Scimitar不得在模块未齐时写假效果。

### UI、AI、教程与QA

- UI：显示Nesting当前/最大Ammo与日成长次数、Pistol同root主动/反应两包、Pop/Revolver弹药、Powder退场预警与胜负候选、Repeater来源root/chain、Rifle当前与待成长Damage、Scimitar当前毒倍率/团队Poison锚点。
- AI：比较Nesting立即放盾与保留弹药；按整队Ammo根估Pistol/Repeater；Powder仅在致命或明确牺牲可接受时用；把Reload的Rifle长期收益、Crit/Haste/Poison密度纳入评分。
- 教程：套娃层数和复数名不等于多宠；Pistol反应不是第二次Use；Destroy self不是死亡；六发不是六连；Rifle当根不吃新成长；Scimitar任意己方Crit均可触发。
- QA：固定种子覆盖Nesting每日重放/末弹0盾/升级出售复制，Pistol自身两包/反应不递归/目标死亡，Pop单Burn，Powderaccepted/immune/护盾吸收/余包取消/双清，Repeater双实例/无弹/Freeze/结构失败，Revolver单包，Rifle多播快照，Scimitar多Crit与同rootHaste，以及全批1/5/12回合、镜像先后手、Boss、回档和Trace一致性。

### 第 22 轮进度

八只最终暂名：层尾山狐、双响刃豪猪、爆响炎獒、爆壳寄居蟹、应鸣花鹿、六晶熔灵、叠晶岩獒、毒潮刃驼。Round21 Javelin身份名同步修正为贯风雷猿。

累计已有 **123/138** 个Vanessa原生对象完成逐项身份、机制骨架、风险与模块审阅。Pop Snappers、Revolver可作为黄色无数值纵切；Nesting Doll、Pistol Sword、Rifle、Scimitar带红色硬门禁；Powder Keg与Repeater分别等待全局终局锁/非死亡退出和强制使用因果链。

下一批舰炮兵器F：Sharkclaws、Shoe Blade、Shot Glasses、Shovel、Shuriken、Sniper Rifle、Submarine、Switchblade。继续只讨论当前来源、身份、事件骨架、模块与配套，不填正式数值。

## 第 23 轮：舰炮兵器 F（Sharkclaws 至 Switchblade）

本轮继续执行“正式CSV先锁ID、17.2直达页再锁来源、三组独立提案、主审交叉裁决”的顺序。搜索索引一度返回16.x旧缓存，三组随后逐一重开正式直达页；八项的数据库页头与卡片 `As of` 均显示17.2。旧搜索入口只进入 `source_card_id_aliases[]`，不覆盖正式 `bz_van/pal` 锚点。

### 正式映射、来源证据与冲突

| 来源 | 正式映射 | 旧宠锚点 | 本轮首选17.2 ID | 来源状态 |
|---|---|---|---|---|
| Sharkclaws | `bz_van_105 -> pal_105` | 云海白鹿 | `179cvyk9yyngt38sj21ft1jpg02` | public写“Your items”，Deep明确筛Weapon；记录 `SOURCE_PUBLIC_DEEP_SCOPE_CONFLICT` |
| Shoe Blade | `bz_van_108 -> pal_108` | 焰羽赤雕 | `nm6h6kl7pswvfqvx8qfnhvny35` | 17.2高置信 |
| Shot Glasses | `bz_van_109 -> pal_109` | 冥羽黑乌 | `mmcttwzlktylg5vhvpddn4ygp2` | 17.2高置信；Deep明确High Slow、Medium Haste |
| Shovel | `bz_van_110 -> pal_110` | 渊鳞黑蛟 | `mmwc4f02vwml4py9sbplfqll4z` | 17.2高置信；战斗主动与DAY_STARTED奖励分属两条事务 |
| Shuriken | `bz_van_111 -> pal_111` | 毒甲蝎将 | `97fkzmjqmgwqh675yw0k5c97tt` | 17.2高置信；Multicast读取使用前Ammo |
| Sniper Rifle | `bz_van_113 -> pal_113` | 覆海蛟王 | `19lm48lq39dgq0q75kjd5hs8hdc` | 17.2高置信 |
| Submarine | `bz_van_117 -> pal_117` | 九霄熊王 | `h88whzq6f9fv30202mxwqpskt5` | `5rjdz4pm270eq3jliiz530kj5`同样显示17.2且内容签名一致，记 `ID_ALIAS_CONFLICT_CONTENT_EQUIVALENT` |
| Switchblade | `bz_van_121 -> pal_121` | 雷泽龙王 | `13mjkvbjx93w54gq9bm3753gbgk` | 17.2高置信 |

Submarine不以card ID作为唯一业务主键：本轮工作键采用 `source_name + patch + public_text_hash + deep_text_hash`，两个17.2内容等价ID全部留证。若未来两页内容发生实质分叉，则升级为 `SOURCE_CONFLICT_STOP`，不能多数表决。

来源直达页：

- `https://bazaardb.gg/card/179cvyk9yyngt38sj21ft1jpg02/Sharkclaws`
- `https://bazaardb.gg/card/nm6h6kl7pswvfqvx8qfnhvny35/Shoe-Blade`
- `https://bazaardb.gg/card/mmcttwzlktylg5vhvpddn4ygp2/Shot-Glasses`
- `https://bazaardb.gg/card/mmwc4f02vwml4py9sbplfqll4z/Shovel`
- `https://bazaardb.gg/card/97fkzmjqmgwqh675yw0k5c97tt/Shuriken`
- `https://bazaardb.gg/card/19lm48lq39dgq0q75kjd5hs8hdc/Sniper-Rifle`
- `https://bazaardb.gg/card/h88whzq6f9fv30202mxwqpskt5/Submarine`
- `https://bazaardb.gg/card/13mjkvbjx93w54gq9bm3753gbgk/Switchblade`

八项旧 `mechanism_id` 均只作历史审计，不继承到新骨架。本批没有任何基础Flying operation；鸟类身份、Vehicle标签和动画都不能自动派生Flying。

### 三组独立结论汇总

| 对象 | 宠物身份草案 | execution mode | 本地机制骨架 | 风险 |
|---|---|---|---|---|
| Sharkclaws | **鲨爪海狮**；一只桶状海狮，四肢为鲨鳍状短爪 | `attack_growth_bundle` | A先原子强化己方所有Weapon锚点一次，再以统一的新快照结算全部Damage包；B空 | 红，团队成长硬门禁 |
| Shoe Blade | **踏刃赤雕**；足爪俯冲承担首击 | `attack_first_use_crit` | A单体Damage；本战首次成功use的整个root获得额外Crit资格 | 黄，可做首次根纵切 |
| Shot Glasses | **双拍夜鸦**；同一只夜鸦以两次节拍调速 | `support_bundle_ammo` | A消耗一次Ammo；每个完整包按 `Slow己方 -> Haste己方`；B空 | 黄转红，事件密度门禁 |
| Shovel | **掘宝土豚**；战斗撞击与局外掘宝两套动作 | `attack + day_reward_passive` | A单体Damage；DAY_STARTED从跨英雄Small池生成一份局外奖励 | 战斗黄、经济深红 |
| Shuriken | **旋棘甲蝎**；尾环与背棘表现当前弹匣 | `attack_ammo_multicast` | 用前Ammo决定内生包数，叠加外部连发，一次清空Ammo后结算全部Damage包 | 深红 |
| Sniper Rifle | **孤准射水鱼**；高压水束与聚焦虹膜 | `attack_conditional_multiplier` | A单体Damage；root-start恰好只有自身一个Weapon来源实例时冻结倍率 | 红 |
| Submarine | **深潜铁鲸**；单一机械鲸舟、无乘员 | `attack_shield_bundle` | 每包 `Damage -> 死亡安全点 -> allied Leader Shield`；恰一Weapon时仅自身获得Freeze/Slow时长减免 | 深红，Leader盾门禁 |
| Switchblade | **弹冠雷蜥**；背冠弹开并向邻宠传力 | `attack + adjacent_weapon_growth_passive` | A单体Damage；回合关系快照中的左右相邻Weapon成功use后，在root-end强化真实触发者 | 黄转红，长局上限 |

八只均为 `body_count=1`、单单位、单HP条。复数爪、两拍节奏、多个手里剑包、机械舷窗都不增加身体数量。

### 关键对质、异议与最终裁决

#### 1. Sharkclaws到底强化所有宠物还是Weapon

public简写为“Your items gain”，Deep实际operation明确过滤board Weapons。身份组认为VFX也必须只描边Weapon，数值组指出若放宽到所有技能，四宠双技能会把预算从 `Weapon锚点数` 扩大为近乎全队技能数。最终本地以Deep为候选权威：每宠最多一个显式 `damage_anchor_skill_id`，来源Weapon标签成立才进入目标集合；包括鲨爪海狮自身。

事务顺序为：

```text
prepare root + freeze eligible Weapon anchors
stage one atomic growth batch (once/root)
commit growth batch
freeze post-growth Damage snapshot
execute all Multicast Damage packets with the same snapshot
```

禁止包内逐段成长。任何成长写入的结构失败回滚整root；已退出的冻结目标写 `SKIPPED_SOURCE_EXITED` 且不补选。表内同时保留public与Deep原文，未来若改采public必须重新做全队预算，不能静默放宽。

#### 2. Shoe Blade的“第一次”按包还是按root

Deep通过 `Custom_0==0` 光环与use后最低优先级累加计数实现。裁决为root-start冻结 `first_use_available`；首次root的全部Multicast包都享首击Crit资格，每包仍可独立掷Crit，但Crit下游消费者once/root。只有根成功提交才消耗标志；无目标、硬锁、Freeze、预验证拒绝或结构回滚都不消耗。本标志只存在本战，不写Run存档。

#### 3. Shot Glasses能否把Slow和Haste净额抵消

不能。Deep明确High先Slow、Medium再Haste；这两类成功application会分别喂给不同消费者。即使同一宠最终剩余冷却数值抵消，也必须保留完整事件：

```text
prepare packet: draw deterministic slow_targets[] and haste_targets[] independently
freeze both lists
apply Slow applications in stable order
apply Haste applications in stable order
then let TempoService project final cooldown
```

两组目标可重叠，目标退出不补选。外部Multicast可重复完整Slow/Haste包，但整个root只消耗一次Ammo；每包可有不同的确定性子种子目标列表。Slow与Haste消费者各自once/root，不能按application无限放大。每宠只暴露一个 `tempo_anchor_skill_id`。

#### 4. Shovel的每日奖励是不是召唤物

不是。战斗主动Damage与 `DAY_STARTED -> GrantRewardFromPool` 完全分离。奖励进入当前Run背包/待领奖队列，不进入棋盘、不占召唤格、不产生unit_id。完整机制在跨英雄Small奖励池manifest、生成品质、出售政策和背包满策略冻结前暂停。

最低幂等键为 `run_day_id + source_instance_id`。RNG结果先持久化，再尝试投递；背包满进入不可重抽的pending reward。同日开始后购入不追领；出售回购、复制、合成、拆分不能复制过去的领取资格。若允许多个Shovel各自产出，经济预算按实例数线性增长，必须明确防折扣购买/完整售价出售等既有套利链。

#### 5. Shuriken的Ammo、连发和清空顺序

admission冻结 `ammo_before=A`；来源内生总包数就是A，外部 `multicast_bonus=E` 另加，最终 `packet_count=A+E`。随后只执行一次原子清空当前Ammo，再按冻结包数结算Damage。零弹返回 `NO_AMMO`，不得进入共享技能条后反复尝试。

这里“permanently subtract AmmoMax from Ammo”只表示本场当前资源写入，不是永久降低AmmoMax。部分装填按实际Ammo决定包数；执行中Reload不增加已冻结包数；早包击败目标后余包写 `TARGET_GONE`，不改投。结构失败时Ammo清空和整root共同回滚。

#### 6. Sniper Rifle的“唯一Weapon”怎么计数

按可见棋盘上的来源实例计数，不按技能数、共享技能条项目数或Damage operation数。一宠即使A/B均为Weapon也只计一个来源；passive-only但来源带Weapon仍计数。root-start冻结 `weapon_source_count`，必须恰一且就是狙击自身；同root中其他Weapon退出只影响下一root。

倍率作用面板Damage快照，之后才进入Crit、护盾与减伤链。Deep里对Damage与派生字段的两条aura不能误实现为两次Damage连乘。名字不提供距离、后排、爆头、斩杀或Ammo依据。

#### 7. Submarine的盾取哪个Damage，抗控给谁

来源aura把自身 `DamageAmount` 投影到 `ShieldApplyAmount`，故盾读取本包开始时、战内modifier已经结算但暴击尚未掷出的面板Damage；不读取Crit后伤害、实际掉血、护盾吸收前数值或目标剩余生命。每包顺序固定：Damage、即时死亡安全点、若来源仍在场则给allied Leader盾。敌方被该Damage击败不自动取消Shield；来源在安全点死亡或退出则剩余operation取消。

唯一Weapon条件只让唯一Weapon自身，也就是潜艇，收到的新Freeze/Slow时长减半。它在control application时动态查询，另一Weapon退出后即可影响之后的新控制；不清除既有状态、不提供团队净化。`h88...`与`5rj...`两页本轮内容签名等价，先保留双ID审计。

#### 8. Switchblade的相邻与成长时机

关系域继续采用玩家可见棋盘：`board_horizontal_round_snapshot(x±1)`。回合开始冻结左右直接邻居；来源或目标移动离开、死亡、UnitExit立即断边；中途新移入者下回合才接入。相邻Weapon的一个成功use root，无论有多少packet，每个Switchblade来源最多消费一次。

成长写到真实触发者的 `damage_anchor_skill_id`，在root-end提交，只影响后续root，不反向放大当前包。一个Weapon可同时受左右两个Switchblade各一次，这是棋盘空间天然上限。禁止读取共享技能条邻接、全左/全右或给Switchblade自己成长。

### 成长与预算方向（不填正式数值）

- Sharkclaws：本地阶段同步提高自身Damage与团队Weapon成长槽；冷却、目标域和once/root不质变。压测 `使用根数 × Weapon锚点数 × 后续Weapon根数`。
- Shoe Blade：只提高Damage；首次Crit资格固定。重点是首根Multicast与Crit消费者，而非12回合成长。
- Shot Glasses：只让阶段影响AmmoMax；Slow/Haste目标数、时长和顺序固定，防品质同时扩事件面。
- Shovel：战斗Damage可成长；每日奖励数量、池范围和品质不得随阶段暗涨。
- Shuriken：Damage与AmmoMax形成乘法轴，必须连同Reload和外部Multicast压测。
- Sniper Rifle：基础Damage与冷却固定，后段只调整唯一Weapon倍率槽；Crit与Multicast仍是额外乘区。
- Submarine：Damage、等量Shield与冷却三轴耦合，需1/5/12回合攻守累计和控制覆盖率压力测试；抗控比例固定。
- Switchblade：自身Damage和相邻Weapon成长共享预算；邻接域与once/source/root固定，需与Sharkclaws团队成长叠加压测。

风险分层：Shoe Blade可先做黄色首次根样板；Switchblade为黄色带长局上限；Shot Glasses为黄转红事件样板；Sharkclaws、Shuriken、Sniper Rifle、Submarine均为红色硬门禁；Shovel战斗侧黄、经济侧深红。

### 身份、美术与分类裁决

- **鲨爪海狮**：云海白鹿仅保留白蓝配色与四足动势；改为厚胸低重心海狮。团队成长只点亮Weapon徽记，绝不画全体宠物发光。
- **踏刃赤雕**：可高复用pal108赤雕体、翼展和足爪；删除无来源雷电。首击准星只在首次成功use后熄灭，不派生Flying。
- **双拍夜鸦**：保留pal109紧凑黑紫鸟身；冷色收翼表示Slow、暖色展翼表示Haste。不是双头、四眼或两只鸟。
- **掘宝土豚**：pal110蛟龙轮廓弃用；长吻、隆背和宽前爪承担战斗撞击与局外掘宝。奖励弹窗只出现在局外。
- **旋棘甲蝎**：高复用pal111蝎身；删除无来源Poison暗示，背棘逐枚熄灭表现弹药清空，多包不复制本体。
- **孤准射水鱼**：pal113蛟龙形弃用，仅留水色；上翘口与聚焦眼表现高压水束。唯一Weapon用 `1/1` 聚焦环，不新增远距规则。
- **深潜铁鲸**：pal117熊形弃用，仅留重甲体量与盾板层次；单一机械鲸舟、无乘员。抗控只显示自身，不画团队光环。
- **弹冠雷蜥**：pal121大盘龙重做为低伏小角蜥；雷只作色彩，不增加雷伤。背冠只向真实相邻Weapon闪一次成长线。

工作分类接受三项迁移建议：Shot Glasses舰炮→奇物、Shovel舰炮→器械、Submarine舰炮→器械。本轮后原生138分类为 **海兽24 / 舰炮49 / 器械27 / 船体13 / 奇物17 / 自然8 = 138**；Pontoon跨英雄草案另加器械后为 **24/49/28/13/17/8 = 139**。身份主类与 `source_types/combat_tags/execution_mode` 必须继续拆耦。

### 代码模块补充与实现顺序

先扩现有权威链，不另造平行战斗：

1. P0 `EffectPacketTransaction` / `MulticastPacketExecutor`：prepare快照、整包重复、单root资源预约、结构回滚。
2. P0 `AmmoResourceService`：Shot Glasses与Shuriken的Ammo预验证、一次Spend/清空、Reload和Trace。
3. P0 `RootApplicationAggregator`：Crit、Slow、Haste、Weapon-use的once/root消费者。
4. P0 `FirstUseLedger`：战斗作用域首次成功root标志、拒绝/回滚不消耗。
5. P0 `BoardRelationService`：Switchblade的回合关系快照、断链和next-round join。
6. P1 `CombatTagProjection/BoardSkillAnchorIndex`：按来源实例统计Weapon，注册每宠唯一damage/tempo锚点。
7. P1 `LeaderCombatantState/LeaderShieldAuthority`：Submarine的Leader盾与统一胜负链。
8. P1 `GrantRewardFromPool + RunInstanceProgressLedger`：Shovel跨英雄池、持久化RNG、pending reward和幂等。
9. P1 `DeterministicTargetSelectionSnapshot`：Shot Glasses按packet派生可回放Slow/Haste列表。
10. 复用 `battle_hook_pipeline`、`modifier_collector`、`damage_death_service`、现有status投影和Command/Result/Trace/Snapshot，不新增第二条技能/状态/死亡服务。

当前 `SkillExecutionService` 仍是单次effect顺序执行后直接启动冷却；`SkillEffectPort.begin_skill`依赖攻击方向/option；现有Shield目标只覆盖宠物；冷却生命周期仍是回合固定减一。因此Shot Glasses纯support、Shuriken整包连发、Submarine Leader盾与Shovel局外奖励都不能用旧字段假装已实现。

### UI、AI、教程与最低QA

- UI：Sharkclaws显示实际Weapon锚点；Shoe显示可消耗的首次标记；Shot同时预览Slow/Haste两组；Shovel分离战斗与每日奖励轨；Shuriken预览当前总包数和清空弹药；Sniper显示唯一Weapon `1/1`；Submarine区分面板Damage与派生Shield；Switchblade绘制真实左右关系线。
- AI：按后续Weapon根估Shark/Switch价值；保护Shoe首根；理解Shot的事件链价值而非只看净冷却；评估Shuriken等装填与立即释放；构筑Sniper时惩罚第二Weapon；把Submarine攻守与控制覆盖一起估值；Shovel奖励只计Run经济。
- 教程：复数爪、双拍、多个飞棘都不等于多宠；鸟不自动Flying；先Slow后Haste不是无事发生；Shovel奖励不是召唤；Shuriken连发只清空一次Ammo；唯一Weapon按宠物来源实例计数。
- 固定种子QA：Shark自身/非Weapon/多播统一快照，Shoe首次root/拒绝/回滚，Shot目标重叠/退出/消费者去重，Shovel同日读档/背包满/多实例/跨池，Shuriken0/1/半满/满弹与外部连发，Sniper一件/两件/被动Weapon/同宠多技能，Submarine Crit不放大盾/敌死后盾/抗控动态切换，Switch左右双来源/移动断链/未来root成长。

### 第 23 轮进度

八只最终暂名：鲨爪海狮、踏刃赤雕、双拍夜鸦、掘宝土豚、旋棘甲蝎、孤准射水鱼、深潜铁鲸、弹冠雷蜥。

累计已有 **131/138** 个Vanessa原生对象完成逐项身份、来源、机制骨架、风险、模块与配套审阅。下一轮处理最后7个原生对象并复核全138覆盖；完成后再单列Pontoon Skimmer跨英雄第139草案，不用来源英雄冲突去篡改Vanessa原生ID。

## 第 24 轮：正式映射收尾（Bilge Worm、Jetbike、The Boulder 至 Trebuchet）

### 本轮范围、映射与来源停止线

正式项目锚点以 `34_bazaar_objects.csv` 为准，不以题面暂名、搜索摘要或历史别名改ID：

|正式映射|本轮首选来源页/ID|来源状态与审计说明|
|---|---|---|
|`bz_van_009 -> pal_009` Bilge Worm|`17c11sqz1xwq5nqj5g9ty98c8v1`|`RETRACTED_ALIAS_INPUT`：题面“Hate Leech”是历史中间名/历史分支，不能覆盖正式Bilge Worm。当前名称与项目锚点确认；同日卡级详情抓取存在跳转/历史展示不一致，记 `SOURCE_FETCH_INCONSISTENT`，机制置信度不冒充全链无争议。|
|`bz_van_064 -> pal_064` Jetbike|`3jyd1l07fb8qwvjxbn3yp89spm`|当前17.2直达页，public与Deep主循环一致。|
|`bz_van_122 -> pal_122` The Boulder|`ygnxt7ngs7ssqtx0j7nvmtsygt`|当前17.2；Damage等于opponent Max Health、Ammo1、长冷却。|
|`bz_van_123 -> pal_123` Throwing Knives|`15b21s88jys12k3dzsv11z10sy3`|当前17.2；另一对象Crit后是 `Use this`，旧Charge文本已删除。|
|`bz_van_124 -> pal_124` Tiny Cutlass|Deep首选`stmc0gy863kbqmj7gy4zpchnqn`；public别名`8zmj74npoleeahkg6vov3ijww`|当前内容固定Multicast2与双倍Crit Damage，但当前页面为Common/neutral对象，不可据此宣称它仍是凡妮莎原生。项目映射可作为兼容锚点继续审。|
|`bz_van_125 -> pal_125` Torpedo|Deep首选`8ytxdag9nopwo8n1wqcuovf0l`；current/public别名`sqwps2xyzng3jhs60pdf2pxy33`|当前17.2；public括号与Deep裸布尔优先级存在实质差异，记 `SOURCE_BOOLEAN_PRECEDENCE_CONFLICT`。|
|`bz_van_127 -> pal_127` Trebuchet|`l4yk4yz5c98njhl98s510qmq94`|当前17.2；public写“another Weapon or Haste”，Deep写any Weapon，记 `SOURCE_PUBLIC_DEEP_TRIGGER_CONFLICT`。|

本轮必须撤回旧Hate Leech的“自毒、全队Crit成长、己方Crit后催动”循环；它们不得混入Bilge Worm，也不得作为第009行的隐藏附加价值。`Hate Leech`只保留在 `source_name_aliases/history`，不能生成第二只宠物。

覆盖口径同时纠正：本轮完成的是**项目正式138条来源映射的逐项审阅**，不是证明这138件在当前17.2都属于凡妮莎。Tiny Cutlass当前英雄归属已经发生变化；Bilge Worm的别名/抓取链存在历史展示不一致；第139候选Pontoon还另有来源英雄冲突。后续总表必须同时保留 `formal_mapping_scope`、`current_source_owner`、`current_source_patch` 和 `scope_conflict`。

### 三组独立意见与主审裁决

#### 1. Bilge Worm：反应吸血不能翻成宠物自疗

身份组将其定为单体生物 **舱底血蛭**，主类由舰炮迁海兽。旧pal009只作ID/美术锚，不继承旧mechanism。名字中的虫和Lifesteal都由血蛭本体表达，不把“Hate Leech”旧暴击循环画回来。

战斗主案为 `passive_only`：回合开始冻结敌方可见棋盘最左的合格 `tempo_anchor`；该来源成功提交scheduled或合法forced use root后，Bilge生成一次反应Damage packet，目标用正常单体攻击选择规则冻结，不把敌方来源对象当成必然受击者。实际HP损失经统一LifestealResolver转为allied Leader回复；护盾吸收量不计吸血，过量伤害不计，来源死亡/UnitExit先注销后不再触发。

粒度为once/root；Multicast子包不是新use。冻结的最左关系在该敌宠移动、死亡或UnitExit时断链，本回合不递补新最左，下回合重建。若Leader治疗权威未完成，机制保持红色阻断，禁止临时改成给血蛭自己加HP。

#### 2. The Boulder：最大生命公式不是处决

身份定为 **崩岳岩团虫**，由舰炮迁自然异象。身份组曾提“崩岳岩犰狳”，因与Barrel的箍甲犰狳和Concealed Dagger穿山甲轮廓冲突，正式撤回；最终用一只大型球马陆/团子虫卷成岩球，`body_count=1`。

来源是对opponent Max Health造成等额Damage。本地当前没有敌Leader伤害权威，主案明确记录为本地转译偏离：用正常攻击/形状规则选择并冻结一个普通敌方战斗单位，以该目标root-start的MaxHP快照计算每个packet的面板Damage。它仍走标准Crit、护盾、减伤、免死和死亡安全点，绝不是Destroy、execute或无视防御。

Ammo只在root预约时消耗一次；外部Multicast允许重复完整Damage packet，但所有包共享同一目标和MaxHP快照。前包击败目标后余包写 `TARGET_GONE`，不换靶。不得因Boss难平衡而暗加不可暴击、隐藏上限或Boss免疫；若统一动态伤害/Leader目标/峰值门禁未完成，本项暂停正式内容。

#### 3. Throwing Knives：当前是强制使用，不是催动

身份定为 **飞牙白象**，单一白象、两根象牙可作为投刃器官，绝不生成第二只象或真实手持飞刀。来源当前循环为“另一己方对象Crit后Use this”。

强制使用绕过普通CD和AP，但必须尊重：来源仍在棋盘、未Freeze/硬锁、Ammo足够、目标合法。成功时原子扣Ammo并在结算后把自身CD重置到max；同一causal root对每个Throwing Knives来源至多一次，`visited_source_instance_ids`阻断双实例和反应链递归。自身Crit不触发自己的“another item”。

原Crit root已经提交后，子强制使用的无目标/Ammo不足只记录分支失败，不回滚父root；结构异常只回滚强制使用子事务。禁止退回旧Charge实现，也不能把“Use this”做成免费伤害光环。

#### 4. Tiny Cutlass：固定双包，不是双身体

身份定为 **双斩狨猴**；阶段名“双斩小猿”因与Orange Julian猩猩和Javelin贯风雷猿辨识度不足而撤回。小体耳簇、长卷尾和双前臂角质刃构成唯一轮廓。

一次root固定生成2个完整Damage packet，每包独立掷Crit；自身Crit Damage通道使用来源的双倍倍率。两个包共享冻结目标、AP、CD和use root；第二包不是第二次技能使用，也不重复触发Ammo/use消费者。Crit聚合消费者仍按root一次。

当前页面显示它是Common/neutral对象，因此本行只能写“项目正式兼容映射”，不能写成“当前凡妮莎专属来源事实”。

#### 5. Torpedo：公开括号优先，偏离必须留痕

身份定为 **蓄冲剑吻豚**，单一Aquatic/Tech生物；蓄冲只表示战内Damage成长，不自毁、不撞出棋盘、不生成鱼雷单位。

来源public可读为：另一 `(Aquatic OR Ammo)` 对象使用时基础成长；若该对象同时Large，再额外成长一次。Deep裸表达式却可按 `(Large AND Aquatic) OR Ammo` 解析，使非Large Ammo也落入额外通道。主案采用玩家可读括号：

- 基础通道：另一来源满足 `Aquatic OR AmmoMax>0`，once/root成长一次。
- 大型追加通道：同一来源同时满足 `Large AND (Aquatic OR AmmoMax>0)`，再成长一次。
- Aquatic+Ammo双标签不让基础通道重复；Large且合格时总计两次application。

成长root-end提交，只影响未来root；来源自身排除。Ammo资格看AmmoMax，不因当前0弹丢标签。这个选择必须标 `local_player_readable_deviation`，不能假装Deep没有布尔歧义。

#### 6. Trebuchet：public与Deep的自身Weapon冲突

身份定为 **投焰槌尾龙**，单只槌尾龙用尾槌蓄力投出燃烧冲击；禁止画攻城器械加眼、范围轰炸或多个投射单位。

A每packet固定为Damage→死亡安全点→若目标仍存在再Burn；Damage击败目标后Burn跳过且不改投。三组交叉复议后的最终裁决沿用此前统一政策：机制实现以Deep的 **any Weapon** 为主，因此自己的A也命中Weapon触发；public“another Weapon”保留为 `SOURCE_TEXT_CONFLICT`，排除自身只作为玩家文案优先备选。

自身A触发不能直接在effect中Charge，因为现有finish随后启动冷却会覆盖结果。执行顺序必须是：root内记录 `pending_charge` → A完整结算 → `start_skill_cooldown` → 同root提交一次pending Charge。任意成功Haste application仍可触发同一消费者；Weapon+Haste在同root最多一次。该最终裁决由战斗组提出、数值组复核接受，先前public优先主案正式降为备选，但保留讨论轨迹。

#### 7. Jetbike：Flying是关键词，不是棋盘位移

身份定为 **翠翼喷驹**，主类由舰炮迁器械载具。它是单一自主构装生物，无骑手、无车队、无分身。

A造成单体Damage并让自己开始Flying。回合开始冻结棋盘同排左右直接邻居；冻结邻宠成功use后，让该触发邻宠和Jetbike开始Flying。另一Flying对象成功use后，Charge Jetbike自身。

Flying资格在root-start冻结：同root里刚被Jetbike授予Flying的触发者，不能追溯触发“Flying use→Charge”；它下一次使用才合格。重复set Flying为幂等，不产生第二个KEYWORD_CHANGED。移动、死亡、UnitExit立即断邻边，新移入者下回合才接入。Flying绝不自动提供位移、闪避、不可选、额外占格或共享技能条重排。

### 数值与成长方向（不填正式值）

- Bilge Worm：预算由敌方最左锚的未来use根数、实际HP伤害和Leader可恢复缺口共同决定；吸血不得按面板Damage结算。
- Boulder：按1/5/12回合分别压测普通单位MaxHP、Crit、外部Multicast、Reload；动态公式与Boss/英雄目标是红色门禁，不先给隐形上限。
- Throwing Knives：上限由外部Crit root数、Ammo/Reload供给和forced-use链深度决定；双实例必须纳入确定性回放。
- Tiny Cutlass：固定2包与双倍Crit Damage是两个乘区；品质只能落明确Damage/冷却轴，禁止再偷偷增加包数。
- Torpedo：基础与Large追加两个成长通道、未来剩余use数和标签覆盖率形成长局乘区；标签双重不重复基础通道。
- Trebuchet：Damage、Burn、Weapon/Haste触发频率和Charge缩短的额外未来use共同计预算；public/Deep分支未选前不填成长曲线。
- Jetbike：Damage、双体Flying授予、Flying队友后续use数和自身Charge回转一起压测；同root不追溯是稳定峰值的硬规则。

风险分层：Tiny Cutlass为黄色执行样板；Bilge Worm身份黄但Leader/Lifesteal接口红；Throwing Knives、Torpedo、Jetbike为红色反应/关键词骨架；Trebuchet为来源冲突红；Boulder为深红并暂停正式数值。

### 身份、美术、分类与单体边界

七只最终暂名：**舱底血蛭、翠翼喷驹、崩岳岩团虫、飞牙白象、双斩狨猴、蓄冲剑吻豚、投焰槌尾龙**。

全部 `proper_name=false`、一个unit_id、一个HP条、`body_count=1`。双刃、象牙、分节岩甲、Multicast、Flying回声和蓄冲层数都不能生成额外身体。禁止：武器直接加眼；Boulder处决/骷髅；Throwing影分身；Tiny两只猴；Torpedo自毁；Trebuchet范围爆炸；Jetbike骑手或车队。

工作分类接受三项迁移：Bilge Worm舰炮→海兽、The Boulder舰炮→自然、Jetbike舰炮→器械。其余四项保留舰炮。本轮后正式138映射的工作分类为：

**海兽25 / 舰炮46 / 器械28 / 船体13 / 奇物17 / 自然9 = 138**。

若Pontoon跨英雄第139草案最终按器械计，则候选口径为：

**海兽25 / 舰炮46 / 器械29 / 船体13 / 奇物17 / 自然9 = 139**。

这只是 `identity_family` 账，不自动改 `source_types/combat_tags/execution_mode`。

### 新增/归并的代码模块

本轮不新增第二条战斗权威链，继续归并 `GameSession -> Command -> Result/Trace/Snapshot`：

1. P0 `EnemyRelationSnapshot`：敌方最左eligible、棋盘左右邻居的回合快照、断链与next-round join。
2. P0 `EffectPacketTransaction` + `MulticastPacketExecutor`：Tiny/Boulder的共享目标、包序、资源一次预约与结构回滚。
3. P0 `AmmoResourceService`：Throwing/Boulder/Tiny等root级Spend、Reload、forced-use扣弹和Trace。
4. P0 `ForcedUseCoordinator`：父root不回滚、子事务隔离、`visited_source_instance_ids`、Freeze/硬锁和CD重置。
5. P0 `RootApplicationAggregator`：Crit、Haste、Weapon-use、Flying-use的once/root消费者。
6. P1 `LeaderCombatantState` + `LifestealResolver`：实际HP伤害转Leader回复，统一过量、护盾和败北边界。
7. P1 `DynamicDamageFormulaResolver`：MaxHP快照、面板值、Crit/护盾/减伤顺序，禁止以Destroy伪装。
8. P1 `FlyingKeywordState`：幂等战斗关键词、root-start资格快照和持续光环注册；不含位移效果。
9. P1 `CritDamageModifierChannel`：Tiny的Crit Damage倍率与普通CritChance、DamageAmount分离。
10. P1 `CombatTagSnapshot` + `BattleStatLedger`：Torpedo按来源标签和Large条件写未来根成长。
11. P1 `CooldownService.pending_change_after_start`：仅在未来选择Trebuchet Deep自身触发分支时使用；不得旁路唯一冷却权威。

建议Trace至少包含：`root_action_id`、packet/operation/application id、trigger source/channel、relation snapshot、frozen target、ammo before/after、packet count/index、crit、max_hp_snapshot、actual_hp_damage、lifesteal_delta、keyword before/after、cooldown before/after、visited sources、result/skip reason。

### AI、UI、教程、经济与最低QA

- AI：识别敌方最左锚的触发频率；Boulder按目标MaxHP与存活价值选靶；Throwing按Crit源和剩余Ammo规划；Torpedo按标签覆盖和未来use估成长；Trebuchet分Weapon/Haste两类根；Jetbike不能把同root新Flying追溯成Charge。
- UI：Bilge画敌方最左锁定线和Leader吸血去向；Boulder显示“按目标最大生命计算”但不用处决骷髅；Throwing显示forced-use额度/Ammo；Tiny显示固定2包；Torpedo分别显示基础成长与Large追加；Trebuchet需明确显示“任意Weapon（包含自身）”并在自身使用后把催动画在冷却启动之后；Jetbike画回合邻接线与Flying徽记，不动画位移箭头。
- 教程：Hate Leech是历史别名；Lifesteal治疗Leader；最大生命伤害仍可被盾/减伤；Use this不是Charge；Multicast不是第二只宠；Ammo标签看MaxAmmo；Flying不等于移动；Trebuchet的“其他”必须与实现一致。
- 来源/本地化：别名、当前英雄、patch、public hash、Deep hash、抓取时间分栏。Tiny的Common归属和Bilge抓取不一致必须在工具UI显示警告。
- 固定种子QA：Bilge最左退出不递补/多播once/root/护盾不吸血；Boulder同目标多包/TARGET_GONE/Crit和免死；Throwing双实例递归/父子回滚/Freeze/0弹；Tiny两包独立Crit但use一次；Torpedo四类标签组合与Large追加；Trebuchet自身A启动冷却后pending Charge、Weapon+Haste去重和Damage致死跳Burn；Jetbike新旧Flying、邻接断链和同root不追溯。

### 正式138覆盖复核

按讨论轮次的原始集合复算：海兽批次24、船体/奇物批次26、器械批次23、自然批次10、舰炮批次55，合计138；各轮迁类只改变最终身份分类，不改变对象覆盖。

本轮收尾又直接读取正式来源目录 `/Users/ywh/Documents/ysbzs/data/csv/34_bazaar_objects.csv`：总计369行内容，明确拆为 `item=138 + skill=138 + merchant_package=93`；其中 `source_type=item` 的object ID与pet ID均各自唯一138个，`object_no=1..138` 连续无缺号。故本任务范围是138个item，不包含后续138个技能和93个商人包。

`SCOPE_AUDIT_WARNING`：`data/content/generated/006_economy.json` 当前包含全部369个商店宠物，并给它们写了连续 `bz_van_001..369` 生成备注；该文件只能用来查运行时映射/占位冲突，不能拿前缀计数证明“Vanessa有369件item”。正式来源数量必须按CSV的 `source_type` 分层统计。

因此本轮后是 **138/138项目正式映射已逐项审阅**。这里的“完成”限于身份、来源证据、机制骨架、风险、模块与配套讨论；正式数值、运行时代码、139跨英雄候选及整体实现路线尚未完成，不能标总目标完成。

## 第 25 轮：Pontoon Skimmer跨英雄第139候选与全案收口

### 当前17.2来源刷新与撤回

本轮主审与三组分别重开当前直达页：

- 来源页：`https://bazaardb.gg/card/jv7wlq4chk28sy4lwhntcj8zvt/Pontoon-Skimmer`
- card ID：`jv7wlq4chk28sy4lwhntcj8zvt`
- Database与card `As of`：17.2（Aug 13）
- 当前英雄：**Pygmalien**，不是Vanessa
- 起始品质/尺寸/类型：Silver / Large / Vehicle + Aquatic
- 当前循环：本体使用时自己与另一非Flying对象开始Flying；使用另一Flying对象时双方停止Flying；每个对象开始Flying后给player Shield，并Charge该对象。

据此写入两条最终来源裁决：

1. `RETRACTED_SOURCE_STOP`：撤回早期“只能确认推断Gold/D5、当前机制为空、Pontoon机制暂停”的BazaarWinner缓存判断。当前17.2机制与Deep已经足够进入草案讨论。
2. `SOURCE_SCOPE_CONFLICT_STOP`：来源机制已知不等于Vanessa资格成立。Pontoon当前明确属于Pygmalien，不进入138条正式映射，不重排任何 `bz_van_xxx/pal_xxx`，也不进入Vanessa商店、获取日或原生统计。

严谨总口径锁为：**本项目138条正式映射谱系 + 1个Pygmalien跨英雄灵感候选**。Tiny Cutlass当前也已迁Common/neutral，因此不得把“项目138映射”继续简称为“当前17.2 Vanessa原生138”。

### 第139候选身份、ID与分类

身份组三轮防撞后的最终候选：**双舟滑獭**。

|字段|裁决|
|---|---|
|策划键|`draft_van_pontoon_skimmer`|
|来源名|Pontoon Skimmer，仅留在source字段|
|宠物暂名|双舟滑獭；英文身份候选 Twin-Pontoon Otter|
|身份主类|器械载具|
|物种/生命类型|单体水獭，organism|
|body语义|`body_count=1`；双侧舟形浮囊/翼膜属于身体器官，一格、一个unit、一个HP条|
|轮廓键|`wide_low_otter_twin_flank_pontoons_fan_tail`|
|核心动作|鼓起双侧浮囊与一名伙伴升空；Flying伙伴使用时双方收囊落地；水膜回流Leader形成护盾并推进获得Flying者的节奏锚|
|明确禁止|攻击弹道、骑手/船员、双宠、召唤浮筒、永久Flying、全队Charge、坠毁/死亡表现|

旧候选“浮潮翼鳐”正式REJECT：IllusoRay和Sharkray已经占用两套鳐形轮廓，再增加第三个翼鳐会破坏黑剪影唯一性。双舟滑獭与Rowboat“桨尾鸭嘴兽”的区别必须落在剪影：前者横向超宽、两侧M形浮囊、低腹滑翔；后者纵向长身、四肢划桨、宽尾推进。

ID停止线：

- 策划期只使用draft键，不生成正式pet ID。
- `pal_139`已有正式对象，绝不可占用或重排。
- 只有主策未来明确批准“跨英雄额外宠物”，才执行全局ID/图鉴/存档/引用碰撞扫描，并候选预留 `pal_370`；批准前不得先写正式数据。
- 必填范围字段：`formal_mapping_scope=extra_candidate`、`current_source_owner=Pygmalien`、`candidate_scope=cross_hero_inspiration`、`scope_conflict=true`。

正式138分类仍为：**海兽25 / 舰炮46 / 器械28 / 船体13 / 奇物17 / 自然9 = 138**。另计双舟滑獭草案后为：**25 / 46 / 29 / 13 / 17 / 9 = 139**。

### Pontoon本地战斗骨架

执行模式：`support_bundle`；A有主动，B空，无攻击形状、无移动、无召唤。

#### A：结伴起航

prepare冻结自身Flying状态与当前存活己方其他非Flying候选；确定性随机选一个其他目标。若有Multicast，预生成稳定子种子、优先无放回的其他目标序列。

每个packet按稳定顺序：

1. `SET_FLYING(self,true)`；
2. `SET_FLYING(random_other,true)`；
3. 每个真实 `false -> true` application分别发布 `FLYING_STARTED`；
4. 每个 `FLYING_STARTED` 分别给allied Leader一次Shield application；
5. 若本次获得Flying的宠物声明 `tempo_anchor_skill_id`，对该锚提交一次Charge。

来源保真粒度是**每个成功application**，不是每root一次。因此正常让自身和一名伙伴同时起飞，会产生两个Flying transition、两次Leader Shield，并分别Charge两个节奏锚。重复set true是幂等no-op，不发第二个事件。

Pontoon自身在A里开始Flying时，对自身的Charge必须延迟到主动冷却启动后提交，避免现有 `finish_skill -> start cooldown` 覆盖推进结果。Leader护盾clamp为0只让Shield application无增量，不阻断对应目标的Charge；Charge目标已ready则只记录自身clamp，不伪造冷却变化。

#### 被动：结伴落地

其他宠物use admission时冻结其root-start Flying资格；在 `ITEM_USE_COMMITTED` 高优先反应安全点、资源预约后但普通效果包前：

1. 若触发者root-start已Flying，则 `SET_FLYING(trigger_source,false)`；
2. `SET_FLYING(Pontoon,false)`；
3. 原use继续按既定目标和资源结算。

这里采用“when used”而非已删除的历史before-use；又不能拖到下一个root。新授Flying不追溯让当前已经发生的use重新合格。`true -> false`不产生Shield/Charge，也不是Slow、Freeze、沉默、伤害、UnitExit或坠毁。

#### 无目标、失败和递归

- 自身未Flying、没有其他友军：仍可只让自己起飞，正常提交。
- 自身已Flying且没有其他非Flying目标：`NO_EFFECT_TARGET`，不耗AP、不启冷却、不发SKILL_USED。
- 目标在application前死亡/UnitExit：该application写 `TARGET_GONE`，其他合法operation保留，不补抽。
- 结构错误、RNG游标错误或关键词服务提交失败：整root回滚。
- 两个Pontoon或外部Flying链使用 `visited_source_ids + ability_id`；每个来源能力每causal root至多进入一次，并设反应深度上限。
- 一来源item转一pet后，Flying落在宠物实例，use/Charge只绑定每宠一个tempo anchor，不能把A/B当两件item重复兑现。

### Pontoon风险、成长方向与停止线

不填正式数值，只冻结预算轴：

|窗口|主要风险|裁决|
|---|---|---|
|单root|不同单位Flying transition数 × Shield × Charge；Multicast可扩候选|红；同一单位每root最多成功开始Flying一次，上限为prepare冻结的不同eligible单位数|
|5回合|起飞得盾/推进→Flying宠使用后双方落地→再次起飞的循环|红；必须测冷却回转、Leader有效护盾和反应链深度|
|12回合|护盾续航、Charge和Flying网络正反馈|深红；未通过事件、回合与控制上限前不填品质曲线|
|品质0/2/5/9|目标域、Charge量、Shield量可能同时膨胀|目标域、Charge量、开始/停止规则锁定；未来若做成长，只允许Shield轴作为首选候选|
|经济/存档|跨英雄获得池、draft误入图鉴/保底；Flying状态泄漏|未批准前不进任何正式池；Flying/Shield/CD/RNG均为单场状态，战后清理|

Pontoon当前判定：来源置信度高、机制置信度高、Vanessa原生资格不成立；技术/平衡均深红。只允许作为隔离测试fixture，不进入正式第139内容、数值、商店、图鉴完成率或存档。

正式停止线：主策批准跨英雄范围；候选ID与存档迁移批准；Flying幂等start/stop、Leader Shield、Cooldown延迟操作、确定性随机、多包与application消费者全部完成；无目标政策和双Pontoon排序通过固定种子QA。

### Pontoon最小QA矩阵

1. 自身与一名友方均非Flying：两transition、两Shield、分别Charge。
2. 自身非Flying、无其他友方：只自飞且只触发一组消费者。
3. 全体已Flying：提交前 `NO_EFFECT_TARGET`。
4. Leader护盾满：Shield clamp0但Charge独立结算。
5. Pontoon自飞：自身CD先启动，再提交pending Charge。
6. 非Flying友方use：不执行落地。
7. root-start已Flying友方use：提交时双方落地，原技能仍执行。
8. 本root刚获得Flying：不追溯触发落地消费者。
9. Multicast：目标序列固定、优先不同非Flying对象、无额外SKILL_USED。
10. 目标死亡/UnitExit：该application跳过，其他operation保留。
11. 双Pontoon：visited guard不递归，固定排序可回放。
12. 固定种子重复：Result、Trace、Snapshot、stateHash完全一致。

## 全138+1实现依赖总收口

### 风险字段不能再压成一个颜色

总表最终至少拆列：`source_risk`、`technical_risk`、`balance_1_round`、`balance_5_round`、`balance_12_round`、`economic_risk`、`save_migration_risk`、`qa_readiness`、`implementation_priority`、`formal_export_status`。技术容易不代表数值安全，来源可信也不代表本地可直接实现。

### P0：全内容共用的商用权威层

1. `SourceFactRegistry + ContentDecisionSchema`
   - 当前名/历史名、card ID/alias、英雄、patch、public/Deep签名、抓取时间、置信度、冲突、撤回、本地偏离和审批状态分栏。
   - 低置信、scope冲突和红色停止线必须fail closed，不能导出正式数据。
2. `BattleEventEnvelope + CombatTransactionCoordinator`
   - 统一root/packet/operation/application、父子因果、prepare/validate/commit、领域no-op、结构回滚、安全点、反应深度和Trace。
3. `ExecutionPolicyRegistry`
   - attack/support/support_bundle/passive_only/forced_use五种模式；空被动不注入basic_attack；support不依赖攻击方向和形状。
4. `BoardRelationService + CombatTagQueryService`
   - 可见棋盘即时/回合快照、左右极值、最左、唯一Weapon、移动/死亡/exit断链、next-round join；禁止读取共享技能条邻接。
5. `SkillCooldownService + BattleKeywordStateService`
   - Haste/Slow/Charge/Freeze的唯一冷却入口、post-cooldown延迟操作；Flying等关键词幂等transition与资格快照。
6. `EffectPacketExecutor + AmmoResourceService + ForcedUseCoordinator`
   - 整包Multicast、一次资源预约、Ammo/Reload、父子事务、visited source和包间死亡安全点。
7. `LeaderCombatantState + OutcomeResolver + UnitExitService`
   - Leader HP/Shield/Heal/Regen/Lifesteal；实际HP伤害；非死亡退场与死亡分离；decisive damage latch。
8. `BattleStatLedger + PersistentInstanceProgressService`
   - 本战成长、root-start快照/root-end生效、Quest/胜场/Run/永久scope和幂等。
9. `MetaRewardTransaction + AcquisitionLotLedger`
   - purchase/grant/copy/merge/sell/day reward分离，实际支付成本、pending reward、库存满、跨英雄池、回撤和旧档迁移。
10. `DeterministicBalanceHarness`
    - 固定种子1/5/12回合、镜像先后手、站位、Boss/Leader、经济环路、回放stateHash；UI预览必须与实战同源。

P0未完成前，只能写接口、测试夹具和内容声明，禁止为138只宠分别写专属handler，更不能批量导出正式数值。

### P1：最小纵切顺序

第一组公共核心纵切：

1. **Tiny Cutlass**：一次use、固定Multicast、逐包Crit、消费者once/root。
2. **Bayonet**：可见棋盘正左关系、回合建链、移动/死亡断链。
3. **Star Chart**：水平快照、光环聚合、来源失效与本地max安全裁剪。
4. **Mantis Shrimp**：Ammo原子扣除、Damage+Burn整包、Slow消费者、root-end成长。

这四项先覆盖主动/被动、关系、Multicast、Crit、Ammo、复合包、状态消费者、单场成长、Snapshot/Trace/回滚。

第二组Leader纵切：**Bilge Worm + Submarine**，验证实际HP伤害、Lifesteal、Leader Shield和死亡安全点。

第三组Flying纵切：先 **Jetbike** 验证单向 `false -> true` 与邻接资格；再用 **Pontoon fixture** 验证start/stop、每application消费者、确定性随机和Leader Shield；Flying Fish/Marlon最后接入，不能让单宠反向定义公共词典。

其后依次：

- Cooldown/控制：Captain's Wheel、Dock Lines、Iceberg。
- Forced use/Reload：Throwing Knives、Repeater、Musket。
- 本战账本：Torpedo、Cyber-Sai、Cauterizing Blade。
- UnitExit/胜负：Harpoon、Dam、Powder Keg。
- 召唤/变形/阵容被动。
- 最后才是跨Run奖励、购买出售、免费物、复制合成和全量品质/池/数值。

### P2：必须后置的高风险内容

- 动态MaxHP：The Boulder。
- 高频自反馈、强制使用与全队成长：Seashadow、Torpedo、Sharkclaws、Wetware、Honing、Throwing、Repeater、Trebuchet、Musket。
- 复杂Flying网络与Pontoon跨英雄正式化。
- 批量非死亡退场、胜负锁、强控制软锁。
- Tropical、Shovel、Fishing Net/Rod、Concealed、Langxian等Run/永久成长。
- Ambergris、Coral、Lockbox及所有购买/出售/Value/免费奖励套利链。
- 全138正式0/2/5/9成长、获取日、商店池、图鉴、AI、本地化和批量导出。

### 1/5/12回合、经济、存档共同门禁

|窗口|必须检查|结构性失败|
|---|---|---|
|1回合|Multicast×多operation×范围、Crit、forced use、动态MaxHP|资源重复消费、子包发新use、死亡后换靶、反应无上限、隐藏技能条邻接|
|5回合|Ammo/Reload、Charge/CDR、Haste/Slow、Flying、移动断链、Leader续航|same-root重入、clamp0仍成长、控制无最低行动出口、断链后增益残留|
|12回合|本战成长、团队成长、Regen/Shield/Lifesteal、自反馈|无显式上限、超线性自喂、来源退出后成长残留、battle状态泄漏到Run|
|经济|免费物、购买监听、折扣、完整售价、复制/合成/拆分|grant冒充purchase、lot缺实际成本、复制领取资格、库存满重抽、正金币闭环|
|存档|battle/run/permanent、RNG、回撤、旧ID迁移|读档重领、Ammo/Flying永久化、只回数值不回事务、重排旧pal ID|
|QA|固定种子、镜像、自动站位、Boss/Leader、UI预览|只测均值、AI专属捷径、UI与实战目标域不同、Trace无法解释skip/rollback|

### 身份、美术、图鉴与本地化量产门

策划唯一性已通过：138/138正式映射都有不同暂名与身份轮廓；但尚未形成可自动验重的量产manifest，不能宣称美术资产验重完成。

G0身份主表每行必填：ID/draft、来源与别名/版本/范围、中文英文名、proper-name政策、`species_key`、`lifeform_kind`、`body_count/body_semantics`、主类、角色、核心动词、`silhouette_key`、`signature_action`、旧图复用级、禁止表现、VFX合同、图鉴短句、解锁状态。

G1全局命名验重；复数来源名、双角/双尾、Multicast不等于多宠。G2先做138+1同尺度黑剪影墙，在真实卡面裁切与棋盘缩放下验外缘。G3动作/VFX只表达权威语义，passive-only不伪造普攻、UnitExit不画尸体、关系线必须落棋盘。G4图鉴分身份、核心动词、触发/断开条件和明确禁止项，并保留中英文搜索alias。G5 draft不得进入掉落池、图鉴完成率、成就或存档。

建议先选六类各两只共12只风格锚点，再按16–24只一批做剪影与动作草图；每批先防撞评审，机制合同冻结后才做VFX，最后联调图鉴/本地化/解锁。

### AI、UI、教程、来源刷新与上线门

- AI只消费与实战同源的目标快照、关系、冷却、Ammo、Flying、成长和经济预览；不得读取隐藏技能条邻接或绕资源。
- UI必须显示关系锁边/断边、packet数、Ammo、技能锚、关键词transition、Leader状态、非死亡UnitExit和失败原因；状态图标与颜色要有双编码。
- 教程词典统一“催动/阻滞/连发/弹药/飞行/退场”；禁止裸Adjacent/Destroy；逐项说明目标、时点、上限和断开条件。
- 来源工具按 `canonical_slug + patch + public/deep hash + alias + observed_at` 更新；内容签名相同的ID冲突保留alias，实质差异自动 `SOURCE_CONFLICT_STOP`。
- 经济/存档用同一事务ID做幂等，读档、回撤、背包满、跨英雄白名单和旧schema迁移必须有固定夹具。
- 上线门包括逐行完整性、无红色formal export、固定种子1/5/12、镜像先后手、经济套利、存档迁移、正式入口真实窗口、长文本/色盲/小尺寸关系线验收。

## 总结裁决

- 项目正式138条映射：身份、来源、机制骨架、风险、模块和配套策划讨论已完成逐项覆盖。
- 第139行：**双舟滑獭 ACCEPT，仅跨英雄draft**；Pontoon来源机制已知，但Pygmalien范围冲突继续阻断正式内容。
- `pal_139` REJECT；`pal_370`只在未来主策批准和全局扫描后成为候选。
- 正式138分类锁为 `25/46/28/13/17/9`；加draft为 `25/46/29/13/17/9`。
- 正式范围审计通过：369条来源目录=`138 item + 138 skill + 93 merchant_package`；本轮只覆盖138 item。生成经济JSON的369个 `bz_van_*` 占位备注不作为来源数量证据。
- 当前可以进入P0公共接口和无数值纵切设计；不能直接批量写正式数值、运行时专属handler或正式获取池。
- 讨论日志和任务卡是本轮本地策划交付；正式workbook/CSV/生成JSON/运行时代码保持未修改。
