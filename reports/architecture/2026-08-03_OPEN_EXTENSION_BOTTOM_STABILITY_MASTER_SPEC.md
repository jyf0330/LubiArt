# Open Extension / Stable Bottom 实施总规格

status: `REBASE_REQUIRED`

task: `2026-08-03_open-extension-bottom-stability`

architect: Codex

implementation owner: `gpt-5.6-sol` / `ultra`，按本文原子逐个领取；普通程序员不得在实现时重新决定架构。

## 0. 决议

本轮把“底层不能变，上层只做扩展”定义为可测试的工程契约，而不是“任何底层文件永远不准编辑”。

- 稳定底层是公开 `Command -> YsbzsState -> Result/Trace/Snapshot` 语义、唯一玩法权威、确定性顺序、stateHash、save/checkpoint/replay 和版本化 Port 契约。
- 同类内容扩展不得再修改中央 ID `match/if`、手工 preload/register 表或解析中文展示文案。
- 新同类内容只允许增加仓库自有 handler/operation 文件和结构化数据；脚本路径永远不能来自内容数据。
- 新 primitive 确实需要新能力时，可以新增窄 Port 版本与 handler；这属于显式协议演进，不是假装“底层一行不改”。
- Service 保留生命周期、排序、原子提交和错误边界；handler 无状态，只经窄 Port 请求权威 mutation。
- 未知 ID、重复 plugin ID、未知 operation、错误 Port 版本、错误参数全部在 mutation 前 fail closed。
- 中文 `name/description/effect/text` 只展示，禁止参与规则选择。

## 1. 冻结基线与并发门

### 1.1 live baseline

- checkout: `/Users/ywh/Documents/godot-latest`
- branch: `codex/full-project-structure-migration`
- frozen HEAD: `ff13778ef3976d6d8910ca7be72e5bddfb7c45fc`
- baseline source SHA256：
  - `core/state/game_state.gd`: `2407c9154f0655c79f61346df4a6dbbaf6cdc6cb9f2f48be1bbdb1c2a5b9a184`
  - `core/battle/mechanics/damage_mechanic_service.gd`: `dd70aa71bdd6b8321b247c88bd5c7e6209df724ad07658da6be2bb619238a5bf`
  - `core/battle/mechanics/element_mechanic_service.gd`: `0b831fd73adbd6e7b033ab793837c37a64c551e81d2d263488db07884ea78baf`
  - `core/battle/mechanics/unit_lifecycle_mechanic_service.gd`: `5f9c4bc3349260817777b0dfbbabca360090ef21f9c48afe575f15497f39dce7`
  - `core/battle/round_lifecycle_service.gd`: `f3510b28b119ab82b052ea08cb51b7312bc0db5262b1fd165be57309712be82a`
  - `core/battle/quality/quality_effect_registry.gd`: `f1bdb04262c4cdf0e9e59abc8bd4226dd3d5664bee7e1023dc181e435030c5b6`
  - `core/battle/quality/quality_effect_strategy.gd`: `894408832df80763949a68e4f039d0b240f629ea7d69c447985b7e3e8cc11eb9`
  - `core/shop/shop_effect_registry.gd`: `c9f7162dc3cdca555c046c24b7830c3b52a5c392cc0612390d0f39489d17a3b0`
  - `core/ports/shop_effect_port.gd`: `be712d4bb043c34fee989d6ae022ebee0552ffbe637da2cd0655b778aa8c0125`
  - `data/content/generated/013_route.json`: `bf19ac1b61f82399e8a489e880a5dfe17d7f151961b518a4d88b89428ff1d500`
  - `data/content/generated/014_quality.json`: `8fc466a2494beb4abc32de5d4f4136673cced388d6b05294dda2143f37f6ad14`
- frozen parity：normalized baseline `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562`；save checksum `875e3dbe`；replay checksum `c53db478`；initial stateHash `7a510a2137368fce`。
- Battle query six golden：route `085524b4005e6545541b98d1509af595b794143551f2aa577c768a87346715cb`；battle `f2450e2ce0ca211229b7301d62ef82f673df3aed7cd52289a87a4fd2134a488a`；configured `c1ec969a59429de2dcf14a4707c8b5c6a9ccfb2f0f7db9197a57d9b4f84cd011`；preview `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945`；player detail `9916f730f1de4281df5cc074bb3078ffc91bedbc21e92190e33ff9a9c8fd9dd3`；enemy detail `ca86d62ffc8eae2cdc4b477804321b0d66ed0e4954ab312081cb7c2344620a09`。

### 1.2 当前写租约

- `core/state/game_state.gd` 与 `core/commands/battle_query_projector.gd` 已被 `2026-08-03_game-state-c5b-battle-query-projection` 修改；Atom E/L 和任何 state caller closure 在该任务归档前禁止写入。
- `game_state.gd::_cell_detail_unit()` 仍属于 `2026-07-15_mouse-playtest-day1-day2`；本任务永不修改。
- `tasks/index.md` 与既有 `FACADE_*`、presentation 报告/任务均是他人 WIP；不得暂存。
- 实施每个 atom 前都执行：`git status --short`、活动任务检索、目标文件 SHA。目标文件非 clean、SHA 变化或租约重叠时停止并报告 `FILE_CONFLICT_STOP`；基线变化但无文件冲突时报告 `REBASE_REQUIRED`，由架构师更新本规格后才能继续。

## 2. 现状裁决：哪些代码违背开放扩展

| 边界 | live 证据 | 裁决 | 处理 |
|---|---|---|---|
| 机制 | `damage_mechanic_service.gd`、`element_mechanic_service.gd`、`unit_lifecycle_mechanic_service.gd`、`round_lifecycle_service.gd` 按 `mech_*` 分支 | 违背；每加同类机制都改稳定 Service | 迁移到仓库发现的 hook handler；Service 只保留顺序/事务 |
| 品质 | `quality_effect_registry.gd` 手工注册 S/G/D 68 项并 preload 特例；`quality_effect_strategy.gd` 中央 operation `match` | 违背；内容编号和 primitive 同时固化在底层 | 数据声明 runtime operation；operation handler 自动发现 |
| 商店 | `shop_effect_registry.gd` 手工 preload/register；party stat handler 与 Port 重复 type mapping | 违背；注册与权威键映射要双改 | handler 自动发现；Port 接收已验证的通用 descriptor |
| 路线/事件 | `game_state.gd` 的 `_battle_prep_effect_from_event`、`_outer_run_effect_from_event`、`choose_route`、`_apply_event_effect`、`apply_shop_event` 解析中文或写死奖励 | P0 违背；改文案即可改变规则 | `event_operations` + service + Port；旧包只按稳定 event ID 兼容 |
| Leader | `_leader_unit`、`_sync_leader_hp_from_target`、`_leader_guard_side` 固定 hero/boss ID、名称与 guard 机制 | 当前可维护性问题，尚无真实多 Leader 用例 | 本轮只冻结 catalog schema 和重开条件，不预建第二权威 |
| Plugin 基础设施 | `core/plugins/script_plugin_registry.gd` 排序扫描仓库脚本、校验 ID/方法/arity、重复即清空 | 已采用且正确 | 复用，不改为数据脚本路径 |
| Command/Port/Repository | 公开 Command、版本化窄 Port、Repository/Codec | 已采用且正确 | 保留；能力演进显式升版 |
| STS2 `ModelDb` 静态类型树 | 内建生成子类型 + mod 反射发现 | 拒绝照搬 | 只借鉴显式可发现契约；Godot 使用仓库目录注册表 |

## 3. 全局不可变约束

1. `YsbzsState` 是唯一玩法权威。registry/service/handler 不持有可变 authority，不保存 Node，不直接读写文件。
2. data 只选择逻辑 ID，禁止 `script_path`、`class_name` 或任意资源路径。
3. 扫描顺序是文件名排序；执行顺序是来源数组顺序，若一个来源有多 operation，则 `(priority, source_index, operation_index, operation_id)` 稳定排序。
4. 所有验证在第一次权威 mutation 前完成。一次 action 任一 operation 无效时，整次 action 不产生部分 mutation、日志、RNG 推进或持久化写入。
5. handler 返回普通 Dictionary/Array；Service 负责把成功结果变成既有日志/Trace。不得让返回结构进入 Snapshot/save/replay，除非单独协议迁移。
6. 旧存档/历史携带旧 content pack 时，经带版本和删除门的 compatibility adapter 读取；禁止回退到中文文案判断。
7. generated JSON 只读。新增 runtime 描述放 `data/content/extensions/*.json`；未回写策划上游时最终标记 `DATA_SYNC_PENDING`。
8. 每个 atom 单独提交、单独可回滚；前一 atom focused + boundary smoke 通过后才进入下一 atom。

## 4. 共用发现契约

直接复用 `ScriptPluginRegistry`，不修改其公共 API：

```gdscript
configure(
    directory: String,
    id_method: StringName = &"plugin_id",
    required_methods: Array[StringName] = [],
    required_method_arities: Dictionary = {}
) -> RefCounted
plugin(plugin_id: String) -> RefCounted
ids() -> Array[String]
is_valid() -> bool
validation_errors() -> Array[String]
```

每个领域的 wrapper 必须提供 `is_valid()` 与 `validation_errors()`。registry 无效时任何 `handler_for/execute` 返回空/失败，不可 assert 后继续。测试 fixture 放在 `tests/fixtures/plugins/<domain>/...`，生产目录不得混入故意无效脚本。

## 5. Atom S：商店纵向证明（第一实施原子，无 state 写入）

### S0 source/disposition

- 修改 `core/shop/shop_effect_registry.gd`：删除四个 preload 和 `_register`；改为发现 wrapper。
- 修改 `core/shop/handlers/*.gd`：一个 canonical type 一个 handler；删除 `effect_types()` 多值注册。
- 新增 `core/shop/shop_effect_compatibility_adapter.gd`：唯一允许识别旧 alias 的位置。
- 新增 `core/shop/shop_effect_dispatch_handler.gd`：保持现有 state caller 不变的无状态 normalize wrapper。
- 修改 `core/ports/shop_effect_port.gd`：删除 `_party_stat_keys(effect_type)`。
- 修改 `data/bazaar_day1_shop_catalog.json`：四种 party effect 改为 canonical `party_stat`。这是当前明确引用的补充 JSON；不改 generated pack。
- 修改 `tests/core/smoke_shop_effect_registry.gd` 并新增 discovery/failure fixture tests。
- 不修改 `game_state.gd`。其现有调用 `_shop_effect_registry.handler_for(effect_type)` 与 `handler.execute(ShopEffectPort.new(self), offer, effect)` 保持成立。

### S1 exact API

`ShopEffectRegistry`：

```gdscript
const HANDLER_DIRECTORY := "res://core/shop/handlers"
func _init(directory: String = HANDLER_DIRECTORY) -> void
func handler_for(effect_type: String) -> RefCounted
func registered_effects() -> Array[String]
func is_valid() -> bool
func validation_errors() -> Array[String]
```

它以 `plugin_id` 注册，要求 `execute(port, offer, effect)` arity=3。`handler_for` 先用 compatibility adapter 把 type 解析到 canonical plugin，再返回 `ShopEffectDispatchHandler.new(plugin, adapter)`；registry 无效或未知 type 返回 null。

每个 handler：

```gdscript
func plugin_id() -> String
func execute(port: RefCounted, offer: Dictionary, effect: Dictionary) -> Dictionary
```

`execute` 先校验 `ysbzs.shop-effect-port.v2`；失败返回 `{}`。生产 handler IDs 固定：`party_stat`、`hero_vitality`、`upgrade_pet`、`duplicate_pet`、`free_refresh`、`next_discount`。拆除目前把 4/2/2 个 type 合在一个脚本的中央分支；文件名与 ID 一一对应。

compatibility adapter：

```gdscript
func normalize(effect: Dictionary) -> Dictionary
```

dispatch wrapper 的精确契约：

```gdscript
func _init(handler: RefCounted, compatibility: RefCounted) -> void
func execute(port: RefCounted, offer: Dictionary, effect: Dictionary) -> Dictionary
```

`execute` 调用 `compatibility.normalize(effect)`，把 normalized effect 交给 canonical handler；成功后若原 type 是 legacy alias，把返回 Dictionary 的 `type` 改回原 alias。wrapper 和 adapter 都不得访问 authority。这样 `game_state.gd` 现有两行 dispatch 完全不改，handler 仍只拿 Port。

旧 alias 精确映射：

| old type | canonical effect |
|---|---|
| `party_attack` | `{type:"party_stat", stat:"atk", base_stat:"base_atk", modifier_stat:"atk", label:"攻击", value:n, legacy_source_id:"party_attack"}` |
| `party_defense` | `{type:"party_stat", stat:"def", base_stat:"base_def", modifier_stat:"def", label:"防御", value:n, legacy_source_id:"party_defense"}` |
| `party_vitality` | `{type:"party_stat", stat:"max_hp", base_stat:"base_max_hp", modifier_stat:"max_hp", label:"生命上限", value:n, legacy_source_id:"party_vitality"}` |
| `party_shield` | `{type:"party_stat", stat:"shield", base_stat:"base_shield", modifier_stat:"starting_shield", label:"护盾", value:n, legacy_source_id:"party_shield"}` |

canonical 输入必须显式提供上述 descriptor；只接受四组白名单组合，额外键可以保留但不得改变映射。`value = max(1, int(value))` 与旧结果相同。

`ShopEffectPort v2`：

```gdscript
const CONTRACT_ID := &"ysbzs.shop-effect-port.v2"
func apply_party_modifier(descriptor: Dictionary, value: int, source_id: String) -> bool
```

保留现有 `has_roster/increase_hero_vitality/upgrade_pet/duplicate_pet/add_free_refreshes/set_next_discount`。`apply_party_modifier` 在复制 roster 前验证 `(stat, base_stat, modifier_stat)` 白名单；之后完全复用旧 mutation 顺序、`_progressed_unit(pet, true)`、modifier 字段和 instance ID 算法。失败不得 set roster。source ID 对旧输入仍为旧 type，对 canonical 输入为 `party_stat:<stat>`，但这一字段若参与已冻结 hash，必须以 parity 测试结果为准：有漂移则 canonical catalog 仍显式提供原 `source_id`，禁止擅自改旧结果。

### S2 caller/lifecycle

`game_state._apply_non_pet_shop_item` 取原 effect type -> registry normalize/resolve -> handler 收到 normalized effect -> v2 Port 权威 mutation -> handler 返回既有 `{type,text}`。对旧 alias，返回 `type` 必须继续是旧 alias；对 canonical 返回 `party_stat`。购买扣费、offer 消耗和持久化顺序不在本 atom 改动。

### S3 validation

- 现有 `tests/core/smoke_shop_effect_registry.gd`：9 个旧 type、错误 Port、真实 state mutation 全通过。
- 新增 `tests/core/smoke_shop_effect_plugin_discovery.gd`：fixture 增加新 handler 后无需编辑 registry；稳定排序；duplicate/missing method/wrong arity 令 registry 整体 invalid，所有 lookup 返回 null。
- 四个旧 party alias 与 canonical descriptor 的 roster、永久 modifier、文本逐字段 parity。
- `smoke_sts2_guided_capability_boundaries.gd`、`smoke_architecture_boundaries.gd`。
- `git diff --check`。

提交：`refactor(shop): discover generic shop effect handlers`。回滚只回滚此提交，不要求回滚规范。

## 6. Atom M：机制 handler 发现（第二原子，无 state 写入部分）

### M0 boundary

本 atom 先迁四个 clean Service 中的机制分支；`game_state.gd` 内剩余机制分支进入 M2，等 C5b 释放。四个 Service 的 public 方法签名和调用顺序不变，现有 Damage/Element/UnitLifecycle/RoundLifecycle Port 版本不变；handler 只拿对应旧 Port。

新增：

- `core/battle/mechanics/mechanic_handler_registry.gd`
- `core/battle/mechanics/handlers/*.gd`，按真正 primitive/行为分文件；允许一个行为 handler 的 `plugin_id` 被多个机制通过数据 `runtime_handler` 复用。
- focused fixtures/tests。

`MechanicHandlerRegistry`：

```gdscript
const HANDLER_DIRECTORY := "res://core/battle/mechanics/handlers"
const ALLOWED_HOOKS := [
  &"on_battle_start", &"before_damage", &"after_damage", &"after_hit",
  &"after_cross_damage", &"attacker_after_hit", &"after_element",
  &"on_death", &"on_shield_break", &"after_ally_death", &"after_kill",
  &"after_action", &"battle_end", &"round_start", &"round_end"
]
func _init(directory: String = HANDLER_DIRECTORY) -> void
func handler_for(mechanism_id: String, mechanism: Dictionary) -> RefCounted
func supports(handler: RefCounted, hook: StringName) -> bool
func is_valid() -> bool
func validation_errors() -> Array[String]
```

handler ID 解析为 `String(mechanism.get("runtime_handler", mechanism_id))`。这保证旧 content/history 不需要改 hash；新同类机制可在 extension JSON 添加 `runtime_handler` 复用行为。每个 plugin 必须 `plugin_id() -> String`，并至少实现一个 ALLOWED_HOOK；零 hook、未知 hook 名不参与执行并令 wrapper invalid。每个 hook arity 在 wrapper 常量中固定并测试，不允许可变猜测。

### M1 hook contracts

hook 参数只使用当前 Service 已持有值；不新增完整 core 参数：

```gdscript
on_battle_start(port, unit, mechanism) -> Array
before_damage(port, target, source, amount, element, damage_props, mechanism) -> Dictionary
after_damage(port, target, source, amount, damage_props, mechanism) -> Array
after_hit(port, target, source, amount, damage_props, mechanism) -> Array
after_cross_damage(port, target, source, amount, element, damage_props, mechanism) -> Array
attacker_after_hit(port, attacker, target, amount, element, direction, mechanism) -> Array
after_element(port, caster, target, element, layers, cell, mechanism) -> Array
on_death(port, unit, source, mechanism) -> Array
on_shield_break(port, unit, source, mechanism) -> Array
after_ally_death(port, receiver, defeated, mechanism) -> Array
after_kill(port, killer, defeated, mechanism) -> Array
after_action(port, actor, mechanism) -> Array
battle_end(port, unit, win, reward_state, mechanism) -> Dictionary
round_start(port, unit, side, mechanism) -> Array
round_end(port, unit, side, mechanism) -> Array
```

其中 `damage_props` 必须是现有 `DamageProps`，不能退回松散 Dictionary，也禁止把 `element`、`direction`、`target` 或 `cell` 偷塞成 reserved context key；live Service 已有输入必须保持为显式参数。`reward_state` 是 `{gold:int, applied:Array}` 的本次局部 accumulator；handler 返回完整新 accumulator，Service 最后一次性提交既有 Port mutation。若当前 Port 不足，停下由架构师裁决是否升版；不得把 authority 传进 handler。

### M2 execution/order/failure

- Service 仍按 `port.mechanic_ids(unit)` 原数组顺序遍历；每个 ID 取 mechanism，再解析 handler；handler 无对应 hook 即跳过。
- 旧逻辑中的一击 flag 检查、pending death safe point、cross damage、召唤格选择、日志顺序必须搬进相应 handler 后保持逐项一致。
- registry 初始化失败时 Service 在 mutation 前返回失败形态：Array API `[]`，Dictionary API 包含 `ok:false/errors` 只有在现有 caller 能接受时才使用；若旧 caller 不接受，启动时构造失败并由 composition test 截获，运行期不做半套规则。
- 不为了减少文件数把所有旧 ID 换到一个新的 `match` 文件；那只是移动违例。相同行为但参数不同的 ID 可共享 handler，行为不同必须分开。
- M1 不修改 generated battle pack。新复用证明 fixture/extension 可用 `runtime_handler`；当前旧 ID 默认自解析。

### M3 migration inventory

迁移范围必须覆盖四个 Service 中全部 ID 比较，至少包括 damage 的 flat shield/armor/reduction/immunity/cap/barrier/last stand/rage/phase/counter/thorn/reflect/harden/soften/blast/summon/wind，element 的 heal/shield/summon/trap/dirty/wall/consume，unit lifecycle 的 death explosion/summon/revenge/kill summon/after action/reward，round lifecycle 的全部 round start/end IDs。验收以 `rg` 为准：四个 Service 中不得再出现业务 `"mech_` 字面量；允许测试 fixture 与 handler 的 `plugin_id`。

### M4 validation

- `tests/core/smoke_damage_mechanic_service.gd`
- `tests/core/smoke_mechanics_composition.gd`
- `tests/core/smoke_round_lifecycle_service.gd`
- `tests/core/smoke_sts2_damage_production.gd`
- 新 `smoke_mechanic_handler_discovery.gd`：新增 fixture plugin 无 registry 编辑、共享 runtime_handler、duplicate/zero-hook/wrong arity fail closed。
- 旧日志数组、DamageProps、one-shot flags、召唤/死亡顺序、reward math golden 完全相同。
- `rg -n '"mech_'` 四个 Service 结果为空；architecture boundaries 通过。

提交：`refactor(mechanics): discover lifecycle hook handlers`。若原有公开返回形态无法做到 registry fail closed，停止 `ARCHITECTURE_BLOCKED`，不得私改 caller。

### M5 M2 剩余查询/预览/结算闭包

M1 只清除了四个 lifecycle Service，不能把其余硬编码误报为完成。当前重冻范围包括：`game_state.gd` 的 ignite/multi-element/cross-detonate/trap-entry/guard-taunt，`battle_query_projector.gd` 的 ignite preview 与 taunt，`auto_position_evaluator.gd` 的三类 death explosion，`battle_trace_factory.gd` 的三类机制伤害中文标签，以及 `threat_target_policy.gd` 的 taunt ID。M2 完成后这些 consumer 不得出现具体 `"mech_` 字面量。

新增纯 `MechanicProjectionService`，由 Composition 注入与四个 M1 Service 相同的 `MechanicHandlerRegistry` 实例；不得另建 registry 或缓存第二份机制 catalog。Registry 的允许 hook 增加：

```gdscript
project_element_settlement(unit: Dictionary, mechanism: Dictionary, facts: Dictionary) -> Dictionary
project_trap_entry(unit: Dictionary, mechanism: Dictionary, facts: Dictionary) -> Dictionary
project_threat_redirect(unit: Dictionary, mechanism: Dictionary, facts: Dictionary) -> Dictionary
project_death_preview(unit: Dictionary, mechanism: Dictionary, facts: Dictionary) -> Dictionary
```

所有既有及新增 hook 必须从只校验 arity 升为同时校验参数 type/class 与返回类型；`plugin_id() -> String` 也必须校验 arity/返回类型。pure projection hook 不接 Port，不得修改传入 unit/mechanism/facts；测试在调用前后做 deep parity。handler 仍至少实现一个允许 hook，未知公开 hook/重复 ID/错型整体 fail closed。

`MechanicProjectionService` public API 冻结为：

```gdscript
configure(registry: RefCounted) -> RefCounted
element_settlement_plan(units: Array, mechanisms: Array, elements: Dictionary, element: String) -> Dictionary
trap_entry_allowed(unit: Dictionary, mechanisms: Array, default_enemy: bool) -> bool
threat_candidates(units: Array, mechanisms: Array, facts: Dictionary) -> Array
death_preview_effects(unit: Dictionary, mechanisms: Array, facts: Dictionary) -> Array
```

Service 只按 unit 原顺序、unit `mechanics` 原顺序解析 handler；mechanism catalog 由稳定 ID lookup，缺定义/缺 handler/registry invalid 全部在 consumer mutation 前 fail closed。settlement handler 返回 JSON-compatible contribution：`{exclusive_key:String, damage_add:int, source:Dictionary, target_pattern:String}`；`target_pattern` 只允许 `""/"single"/"cross"`。Service 对相同非空 `exclusive_key` 取第一条，按顺序累加 `damage_add`，最终返回 `{ok, base_damage, damage, source, target_pattern, contributions}`。这样 ignite 是 `layers * per_layer`，multi-element 是条件满足时 flat bonus，diamond fire cross 只选择 `cross`，而 state/query 不再认识其 ID。

M2 live rebase 后把投影输入再冻结一层，避免实现者自造 context：`element_settlement_plan` 用 `ElementBurstPolicy.damage(layers)` 生成 triangular `base_damage`，传给每个 hook 的 facts 精确为 `{element:String, layers:int, active_element_type_count:int, base_damage:int}`。`mech_fire_ignite_bonus` 仅在火结算返回 `damage_add=layers*per_layer`、`exclusive_key=fire_ignite_bonus`；`mech_multi_element_bonus` 仅在 active count `>=2` 返回 `damage_add=bonus`、`exclusive_key=multi_element_bonus`；`mech_fire_cross_detonate_diamond` 仅在火元素且 unit 自身 `element=火`、quality normalize 为钻石时返回 `target_pattern=cross`。第一个非空 target pattern 胜出，pattern contribution 的 source 优先于普通 damage-add source；没有 pattern 时才取第一条非空 add source，从而保持 live execution 中十字引爆者覆盖 ignite 来源的旧语义。query 只消费同一 plan 的 damage，不再自选 source。

`project_trap_entry` 的 facts 固定 `{default_enemy:bool}`，`mech_trap_stack_trigger` 返回 `{allow:true}`；Service 在 registry valid 时先采用 `default_enemy`，再允许 handler opt-in。`project_threat_redirect` 的 facts 固定 `{enemy:Dictionary}`，`mech_guard_taunt` 返回自身 `range/mechanic_id/mechanic_name`，Service 补上 `target`。`project_death_preview` 的 facts 固定 `{projected_dead:true}`；死亡爆炸、自爆、破盾爆炸三个既有 handler 都返回 `{radius:1, metric:"manhattan", damage:<resolved param>}`，严格保留 auto-position 当前把三者都计入 predicted death 的行为，不在架构迁移中顺便改规则。

trap hook 只返回 `{allow:bool}`；enemy 的旧默认触发由 caller 显式传 `default_enemy=true`，非 enemy 只能由 handler opt-in。threat hook 返回 `{range:int, mechanic_id:String, mechanic_name:String}`，Service 组装现有 candidate；`ThreatTargetPolicy` 只复制 candidate 的 ID/name，不得自行写死。death preview hook 返回 `{radius:int, metric:"manhattan", damage:int}`；auto-position 对返回列表做通用距离累计，不再维护 explosion ID 列表。

`BattleTraceFactory.damage_event` 优先读取调用方给出的 `trace_context.sourceLabel`，仅保留 action/skill/skill_combo/relic/element_settlement/element_trap 这些协议级 sourceType 默认标签；三种 mechanism handler 在原 damage Port 调用中显式给出各自旧中文 `sourceLabel`，因此 factory 不再含机制 ID 且 trace 文本/protocol 逐字节不变。禁止把 label 反向放进机制 catalog 后让底层解析中文。

Composition 新增唯一 `mechanic_handler_registry`，四个 M1 Service 新增 `configure_handler_registry(registry: RefCounted) -> RefCounted` 并与 `MechanicProjectionService.configure(registry)` 一起接收同一对象。各 Service 的 directory constructor 仅为独立 fixture/smoke 保留；production Composition 完成注入后不得残留五份各自发现的 registry，也不得复制 mechanism catalog。Composition ownership/complete smoke 必须锁同一 registry identity 与 service 数量变化。

Registry 的 typed gate 必须对 `plugin_id() -> String` 和全部 19 个 hook 同时验证参数 `Variant.Type`、对象 class_name 与返回 type；无类型注解、错 class、错返回、错 arity、未知公开 hook、duplicate、zero-hook 任一使整个 registry fail closed。pure hook 收到的 unit/mechanism/facts 都是深复制，返回值只允许上述 exact JSON-compatible keys/types；caller 输入在成功/失败后都必须 deep-equal。

M2 文件范围为 registry/projection service/对应 handlers、上述五个 consumer、Composition 单对象注入和 focused tests。必测 execution/query/auto-position 三路 parity、pure hook 不变性、handler fixture 无 consumer 编辑即可投影、duplicate/zero/unknown/wrong typed fail closed、trace 文本与 protocol exact，以及 production consumer `rg '"mech_'` 为空。提交：`refactor(mechanics): project typed mechanic capabilities`。

## 7. Atom C：content runtime schema 与装配门

### C0 files/API

新增 `core/content/runtime_extension_validator.gd`，由 `GameDataRepository` 在 assemble 完成、交给 state 前调用。它验证 `runtime_handler`、`runtime_operations`、`event_operations`，不把这些字段命名为 `effects`，避免误入 generic `EffectContentValidator`。

`CoreComposition` 的固定 API 为 `prepare_content_binding(content: Dictionary, source_kind: StringName) -> Dictionary` 与 `commit_content_binding(candidate: Dictionary) -> bool`。prepare 为每个 data-driven registry 生成 detached candidate，再只向 caller 返回 Composition 自己的一次性 opaque token；真实 domain candidates 留在 Composition 私有 pending table。commit 只消费该私有 bundle，并在所有 token 仍有效时对现有 registry 对象提交；禁止替换 registry 对象。返回 `{ok:bool, errors:Array}` 的兼容 `bind_content` 只能是上述 prepare+commit 的薄封装，不能形成第二路径。

调用集中到 `YsbzsState._replace_game_data(content: Dictionary, source_kind: StringName) -> bool`；初载、save embedded content、history resume 三个 production `game_data = ...` caller 全部改用它。顺序：assemble/shape validate -> prepare all registries -> commit registries -> 仅成功时替换 `game_data` 并记录 source kind -> invalidate content/hash cache -> caller 决定 reset/restore。prepare 失败不替换旧内容；不允许在 Composition 中缓存 content 副本成为第二权威。

Facade responsibility descent 已在 `e9fa797` 归档；2026-08-03 重冻 SHA-256：state `09906eea...`、Composition `65106cb4...`、SimulationFactory `6611c7b8...`、ReplayVerifier `c9b44c97...`、GameDataRepository `b15ea93c...`、assembler `195b5698...`。当前唯一旧 playtest 租约仅覆盖 `_cell_detail_unit()`，本 atom永不修改该函数；目标文件若再次出现新租约或 SHA 漂移，仍退回 `REBASE_REQUIRED`。

## 8. Atom Q：品质结构化 operation

当前 gate：`REBASE_REQUIRED`。原因不是 operation 方向变化，而是 C6 正在修改 `game_state.gd`、`core_composition.gd` 并新增 `quality_effect_registry` consumer；C6 归档后必须重新冻结所有 writer/consumer 的 live 行号与 SHA。以下数据、兼容、两阶段原子性和 primitive 分组已经定案，实现者不得再决定。

实施拆为两个可独立回滚的原子，避免连续 Facade 租约饿死 quality 内部迁移：

- `Q0_CORE_READY`：现在实施。只修改 `core/battle/quality/**` 和 quality focused tests/fixtures；建立 operation registry/handlers，把 registry/strategy/board/shape 的中央分派迁出。`QualityEffectRegistry._init()` 暂时从冻结 `legacy_quality_runtime_catalog` 编译 68 项作为 bootstrap，因此生产行为、hash/save/replay 不变。禁止修改 state、composition、repository、content JSON。提交 `refactor(quality): execute discovered runtime operations`。
- `Q1_REBASE_REQUIRED`：等待当前 C7 及后续已登记的 state/composition caller 租约释放。实现本节 Q0/Q1 数据包、source-kind、两阶段 content binding，并删除 `current_assembly` 的 bootstrap fallback；只允许真正 `persisted_snapshot` 使用 legacy。提交 `refactor(content): bind versioned quality runtime data`。

Q0 完成门额外要求：除 `legacy_quality_runtime_catalog.gd` 外，production quality source 不出现具体 S/G/D ID；新 operation registry/handlers 与现有 68 项逐 hook parity；未显式 configure 时 bootstrap 仍使用冻结 legacy candidate；坏 plugin/candidate 不可破坏 bootstrap last-good。Q0 不是任务最终完成，legacy bootstrap 删除门仍由 Q1 管理。

### Q0 现代内容包与精确 assembler 语义

新文件固定为 `data/content/extensions/quality_runtime_operations.json`：

```json
{
  "schema": "ysbzs.content-package.v1",
  "package_id": "extension.quality_runtime_operations.v1",
  "priority": 100,
  "order": 14,
  "operations": [
    {"op":"set","path":["quality","runtime_schema_version"],"value":1},
    {
      "op":"append_to",
      "path":["quality","upgrades"],
      "match_key":"id",
      "match_value":"S01",
      "field":"runtime_operations",
      "value":{
        "id":"S01.round_start.grant_shield",
        "hook":"round_start",
        "operation":"round_grant_shield",
        "priority":100,
        "params":{"amount":15}
      }
    }
  ]
}
```

- priority 100 保证它在 priority 0/order 14 的 `generated.quality` 后执行；同级排序继续服从 `(priority, order, package_id)`。
- 每个 runtime operation 必须是一条独立 `append_to`；禁止把 operations 数组作为一次 value，否则 assembler 会形成嵌套数组。
- 必填 `id/hook/operation/priority/params`；同一 upgrade 内 `id` 唯一；`params` 只允许 JSON-compatible scalar/Array/Dictionary，禁止 Object/Callable/脚本路径。
- 当前 assembled content 必须有 `quality.runtime_schema_version = 1`；版本达到 1 的内容中，任何 upgrade 缺 operation 或 operation 无效都令整包 bind 失败，绝不降级 legacy。
- extension 改变 current assembled content fingerprint 是预期行为；旧 golden 作为 legacy snapshot fixture 保留，现代 current content 生成单独批准的 fingerprint，不可把二者混成一个 golden。

### Q1 旧 history/save/replay 的唯一兼容规则

新增 `legacy_quality_runtime_catalog.gd`，只包含迁移前冻结的 68 个 ID（S01-S08、G01-G30、D01-D30）及迁移前 metadata/规则。source kind 必须由正式 loader 明确传入：

```gdscript
const CURRENT_ASSEMBLY := &"current_assembly"
const PERSISTED_SNAPSHOT := &"persisted_snapshot"
```

| source kind / runtime version | ID | 处理 |
|---|---|---|
| current assembly / 1+ | 任意 | 只用 `runtime_operations`；缺失/无效整包失败 |
| current assembly / 缺失或 <1 | 任意 | 失败；禁止伪装 legacy |
| persisted snapshot / 缺失或 <1 | 冻结 68 ID | 允许 legacy catalog |
| persisted snapshot / 缺失或 <1 | 新 ID | 失败；禁止进入 legacy catalog |
| persisted snapshot / 1+ | 任意 | 只用 snapshot 自带 operations |

`contentRevision`、save/replay/history 容器 schema 都不是 quality runtime 版本，不得拿来猜。compatibility 删除门：所有允许加载的 save/history/replay 最小内容版本均强制 `quality.runtime_schema_version >= 1`，并有迁移/拒绝测试；在此之前 legacy catalog 不得删除。新的 current 内容 ID 永远不能加入 legacy 表。

### Q2 两阶段配置与单对象引用

`QualityEffectRegistry` 精确 API：

```gdscript
func prepare_configuration(
    upgrades: Array,
    runtime_schema_version: int,
    source_kind: StringName
) -> Dictionary # {ok:bool, candidate:Dictionary, errors:Array[String]}
func commit_configuration(candidate: Dictionary) -> void
func is_configured() -> bool
func validation_errors() -> Array[String]
func effect_for_id(effect_id: String) -> QualityEffectStrategy
func effect_for_unit(unit: Dictionary) -> QualityEffectStrategy
```

- prepare 全量验证 68/新 IDs、operation/hook/plugin/arity/params、重复 operation ID，并构造 detached candidate；不修改 active table/errors。
- `candidate` 的公开形状仍是 `Dictionary`，但只能携带本 registry 生成的一次性 opaque token；detached normalized blueprint 保存在 registry 私有 pending table。`commit_configuration` 必须拒绝 foreign/empty/replayed token，消费有效 token 后重新构造 Strategy，调用方修改 prepare 返回值不得影响 active table。
- `CoreComposition.prepare_content_binding(content, source_kind) -> Dictionary` 收集所有 domain candidates；全部成功后 `commit_content_binding(candidate) -> void` 在现有 registry 实例内提交。
- 首次 prepare 失败：registry 保持 inert；已有 last-good 后重绑失败：active table 和旧 `game_data` 均保持 last-good，只返回稳定 errors。
- 禁止用新 registry 对象替换旧对象；quality runtime、battle query projector、C6 auto-position evaluator 以及 state callers 必须继续持有同一个 registry 引用。
- `_replace_game_data(content, source_kind) -> bool` 顺序固定：prepare all -> 全部成功 -> commit registries -> 替换 `game_data` -> invalidate content/hash cache -> reset/restore。prepare 失败不得修改上述任一项。

### Q3 typed operation plugin contract

新增 `quality_operation_registry.gd` 与 `core/battle/quality/operations/*.gd`。每个 plugin 必须 `plugin_id() -> String`，并至少实现一个下列允许 hook；wrapper 固定 arity、拒绝未知 hook/重复 ID/错误 arity，任一错误令整个 operation registry fail closed：

```gdscript
round_start(context, unit, params) -> Array
element_application_count(context, cell, current, params) -> int
element_layers(attacker, slot_element, current, params) -> int
before_attack(context, attacker, option, params) -> Array
modify_hit_damage(hit_context, current, params) -> int
before_hit(context, attacker, target, slot_element, params) -> Array
after_hit(context, attacker, target, params) -> Array
after_attack(context, attacker, option, targets, params) -> Array
mutate_shape(unit, direction, cells, width, height, source_id, params) -> Array
attack_option_for_target(attacker, target, option, params) -> Dictionary
sort_targets(targets, option, params) -> Array
trace_enter(context, unit, trace, params) -> String
trace_round_start(context, unit, traces, params) -> Array
trace_element_application_count(traces, current, params) -> int
profile(params) -> Dictionary
```

`QualityEffectStrategy` 只按 `(priority, source_index, operation_index, operation_id)` 调 typed hook，保留现有 public API；不得包含业务 operation `match`。`QualityBoardTrace` 与 `QualityShapeMutator` 也必须经 registry 调 handler，不能保留 trace-kind/shape-mutation 中央分支。现代 typed board trace value 只存 `handler_id/params/id/name/duration/persistent`，禁止脚本路径；但 Q0 的 D21-D30 legacy bootstrap 属于已进入 authority/hash/save/replay 的历史编码，必须逐键保留旧 `{kind,duration,id,name[,persistent=true]}`，不得写入空 `params`、冗余 `handler_id` 或 `persistent=false`。读取侧把 `kind` 兼容解析为 handler ID；同 handler 的 trace 只能按 `handler_id + canonical params` 分组，参数不同不得串用首条参数。

operation registry 除方法名和 arity 外，还要校验 `plugin_id() -> String` 以及每个 typed hook 的参数类型与返回类型；任一错型令整个 registry fail closed。每个 primitive 通过统一的私有参数验证合同声明 required/optional key、JSON 类型、取值范围和 unknown-key 策略；Effect Registry 只调用通用 validator，不得新增按 operation ID 的中央参数 `match`。

`QualityHitContextProjector` 保留为稳定、纯 value fact 投影；`when` 只允许 equality、`*_min`、`*_max`，这是冻结的组合条件 vocabulary。新增同类 quality 可以组合现有 fact；新增事实是新 primitive，需要显式 projector/test 演进。

### Q4 primitive 分组与 68 ID disposition

以下是迁移前 registry 的完整行为分组；同一行共享 handler+params，不得按 68 ID 重建中央注册表：

| primitive handler | IDs / params source |
|---|---|
| `round_grant_shield`、`round_heal`、`round_double_max_hp_once`、`round_guard_stance` | S01=15；S02=20；S03 cap30/once flag；G01 guard shield8 |
| `element_apply_count_add`、`element_layers_multiply_matching` | S04 +1；S08 x2 matching element |
| `damage_add_when` | G01/G02/G03/G06/G07/G09-G11/G13-G15/G17-G20/G21-G30、D07/D08/D12；逐项沿用现有 `when/value` |
| `damage_multiply_when`、`damage_scale_ceil_when`、`damage_chain_double` | S05、D16；D17 3/2 ceil；S06 |
| `shield_behind`、`formation_shield` | G08=10、G21=8；G28=5 |
| `permanent_attack_per_kills` | S07 threshold5/amount1 |
| `shield_core_ally`、`heal_core_ally`、`shield_marked_ally` | G04=8、G05=6、G22=8 |
| `incoming_bonus_all_targets`、`incoming_bonus_first_target` | G12=3、G23=3 |
| `kill_chase`、`chase_low_hp`、`repeat_core_if_covered`、`adjacent_splash` | G16=3/追击、D14=4/连锁；D13=5；D15 minimum3；D05=1 |
| `immediate_element_burst` | D18，沿用 3 层阈值与三角数伤害 |
| `narrow_to_target_mode`、`sort_lowest_hp` | G14 mode重；D19 |
| shape handlers | D01 extend_end；D02 back_sweep/-2；D03 mirror；D04 diagonal_copy；D06 double_ends/-2；D09 fill_corner/-2；D10 pierce_end/-1；D20 reverse |
| trace placement + trace behavior handlers | D21 fire/1；D22 water/1；D23 wind/1；D24 earth/1；D25 metal/1；D26 wood/2；D27 buddha/1；D28 sand/1；D29 demon/1；D30 talisman/1/persistent |
| `mode_profile` | G01 攻守；G02 稳爆；G14 稳重；G24 同/主副，沿用现有 aliases/default |
| `boolean_profile` | preview_damage: G01/G02/G03/G14/G17/G22/G24/G25/G26/G30；supports_mark: G17/G22/G30；changes_shape_name: D01/D02/D03/D04/D06/D09/D10/D20 |
| `actor_order_profile` | D11=-1；D12=1 |

S01/S02/S03/G01 四个专用 effect 脚本迁入上述真正 primitive 后删除；其余空行为 ID 也必须至少有 profile/operation，现代 schema 不能以“注册一个空 Strategy”假装已配置。

### Q5 caller closure（2026-08-03 live re-freeze）

production 直接 writer 现精确为三个：`_init` 接 `ContentLoadService` 结果、`_restore_and_validate_determinism` 接 save embedded content、`_resume_from_history_checkpoint` 接 immutable content revision。三处都迁到 `_replace_game_data`；迁移后 production `rg -n '\bgame_data\s*=' --glob '*.gd' --glob '!tests/**'` 只允许 `_replace_game_data` 内一处赋值。

state 增加私有 `_content_source_kind`，公开只读 `content_source_kind() -> StringName`。初始化 option 增加 `content_source_kind`，production 默认 `current_assembly`，simulation/test 默认仍是 current 但 factory 在处理 persisted snapshot 时必须显式传值；空值/未知值 fail closed。`SimulationAuthorityFactory.create` 的 options 增加 `contentSourceKind`，`fork` 继承 source；replay initial-hash clone 与 ReplayVerifier context 都传当前明确 source kind，禁止从 `contentRevision`、schema 或 ID 猜测。

save load 先完成 schema/checksum/contentHash 校验，再 bind embedded persisted content，之后才 restore authority；bind 失败不得改 state/registry/cache。history resume 在 bind/load 前捕获旧 authority codec payload、旧 content/source kind 与 history flags；检查点 hash、branch begin 或 branch checkpoint 任一步失败，都必须重绑旧 content、restore 旧 payload/flags 并恢复原 hash，不能留下半恢复状态。

测试不得再 `state.set("game_data", ...)` 或原地改 nested content。新增 `replace_game_data_for_test(content, source_kind) -> bool` 只允许初始化 mode 为 `test/simulation`，内部仍走唯一 `_replace_game_data`；production 调用返回 false。至少迁移 deterministic history、relic timeline、authoritative codec、effect content schema 与现有原地修改 `state.game_data[...]` 的 quality/stat/bazaar fixtures。

Q1 开工门现为 `IMPLEMENTATION_READY_AFTER_E0`：上述 source/caller/ownership 已重冻；E0 不触碰这些路径。开工时只需确认 SHA 与租约未再次漂移，不再重新发明 source-kind 或第二写路径。

### Q6 focused/golden/static gate

保留既有 full hooks、strategy、runtime service、runtime command、upgrade selection、battle service split、modular content、state init fail-closed、deterministic history、singleplayer persistence、composition complete/ownership 与 Node quality progression tests。

新增：

- `smoke_quality_runtime_operations.gd`：68-ID parity、稳定排序、discovery、unknown/duplicate/bad semantic params fail closed。
- 新增 quality authority parity：D21-D30 落痕逐键保持 legacy encoding，并覆盖含 board trace 状态的 stateHash/save/replay 基线；不能只验证未产生落痕的通用 P0 路径。
- `smoke_quality_registry_atomic_configure.gd`：首次失败 inert、last-good 后失败不变、candidate 无部分注册、所有 consumers 同一 registry。
- `smoke_quality_history_compatibility.gd`：旧 68 fallback、新 ID 禁 fallback、modern 缺 operations 必败、legacy/modern 各自可重现。
- `smoke_content_bind_lifecycle.gd`：initial/save/history/two replay clone 全走 bind，失败时 state/hash/registry/cache 不变。
- `smoke_quality_runtime_operation_static_contract.gd`：registry/strategy 无具体 S/G/D；strategy/board/shape 无业务中央 `match`。

现代 current fingerprint 变化必须获批；迁移前 legacy fixture 的 normalized/stateHash/save/replay 仍精确重现。提交：`refactor(quality): load structured runtime operations`。extension JSON 未回写策划上游时交付标记 `DATA_SYNC_PENDING`。

## 9. Atom E：事件/路线结构化 operation

当前 live 违例不只包括效果文案：`_parse_gold_cost` 仍从中文 `金币-N` 推断费用，`_post_battle_events_for_result` 仍硬编码 `evt_battle_fail/evt_battle_bonus`，`choose_route` 的 rest 仍固定 HP+4/coins+2。三者全部进入本 atom；只迁效果字符串而保留这些分支不算完成。

门禁拆为 `E0_CORE_READY / E1_REBASE_REQUIRED`。E0 不接 composition/state、不添加会改变 current content fingerprint 的 production extension JSON；E1 等 state/composition/content caller 租约释放后重冻并一次接通。

### E0 operation core

新增：

- `core/run/events/run_event_operation_registry.gd`
- `core/run/events/handlers/*.gd`
- `core/run/run_event_effect_service.gd`
- `core/ports/run_event_port.gd`
- discovery、typed contract、transaction、行为 parity focused tests。

每个 handler 必须 `plugin_id() -> String`、`_validate_params(params: Dictionary) -> Array[String]`、`execute(port: RefCounted, event: Dictionary, context: Dictionary, params: Dictionary) -> Dictionary`。Registry 复用 `ScriptPluginRegistry`，校验 ID、arity、参数/返回类型、private params validator、重复/零 execute/未知公开方法；任一错误整体 fail closed。生产 canonical operation 固定为：

```text
noop
spend_coins
add_coins
heal_hero
queue_battle_prep_shield
queue_trap_damage_bonus
queue_reward_gold_multiplier
add_free_refreshes
set_next_discount
upgrade_first_eligible_pet
duplicate_first_pet
refill_shop_pool
select_reward_pool
```

`RunEventEffectService.execute(port, event, context, operations) -> Dictionary` 先全量 normalize/resolve/validate，再按 `(priority, source_index, operation_index, id)` 执行。返回固定 transient envelope：

```gdscript
{
  "ok": bool,
  "code": String,
  "event_id": String,
  "coins_from": int,
  "coins_to": int,
  "operation_results": Array,
  "shop_effect": Dictionary,
  "battle_prep_effect": Dictionary,
  "outer_run_effect": Dictionary,
  "reward_pool_id": String,
  "logs": Array[String]
}
```

operation 除必填字段外允许可选 `contexts:Array[String]`，元素只允许 `shop_event/route_event/rest/post_battle`；缺失表示全部 context，空数组、错型、重复或未知值均 fail closed。`context.context_kind` 必须为上述之一。Service 必须先验证全部 operation（包括本 context 不执行的项），再过滤 contexts 并执行；不得用 contexts 隐藏坏 handler/坏 params，也不得从 `source/name/gain/option_text` 猜 context。

`RunEventPort` 合同 ID 为 `ysbzs.run-event-port.v1`，只暴露 transaction、coins/hero/roster/shop/pending 所需窄方法；不得返回 authority。`begin_transaction()` 捕获且只捕获本闭包可能修改的字段：coins、hero HP、roster、free rolls、next discount、offers、active pool/stall、shop/battle-prep/outer-run effects、shop roll/context counters、seen IDs、seed audit；`rollback_transaction()` 精确恢复，`commit_transaction()` 丢弃备份。Service 的固定顺序为 validate all -> begin -> spend -> typed operations -> append 固定旧 summary -> commit；handler 返回 `ok:false`、返回错型或抛出能力缺失均 rollback。日志只在 commit 成功后由 caller 按返回 `logs` 写入，因此失败不污染 log。

E0 冻结的 Port public surface 只能是以下签名；handler 不能调用 authority 私有方法，也不能通过 `get/set/call` 逃逸：

```gdscript
contract_id() -> StringName
begin_transaction() -> bool
commit_transaction() -> bool
rollback_transaction() -> bool
current_coins() -> int
spend_coins(amount: int) -> Dictionary
add_coins(amount: int) -> Dictionary
heal_hero(amount: int) -> Dictionary
queue_battle_prep(event: Dictionary, context: Dictionary, effect_type: String, value: int) -> Dictionary
queue_outer_run(event: Dictionary, context: Dictionary, effect_type: String, value: int) -> Dictionary
add_free_refreshes(amount: int) -> Dictionary
set_next_discount(percent: int) -> Dictionary
upgrade_first_eligible_pet(event: Dictionary) -> Dictionary
duplicate_first_pet(event: Dictionary) -> Dictionary
refill_shop_pool(pool_id: String, minimum_slots: int, context: Dictionary) -> Dictionary
select_reward_pool(pool_id: String) -> Dictionary
append_shop_event_summary(summary: Dictionary) -> Dictionary
```

所有 mutation 返回至少 `{ "ok": bool, "code": String }`；成功时再返回本操作的 `*_from/*_to` 或旧 effect/construction shape。`spend_coins` 对 `amount < 0` 返回 `invalid_amount`，余额不足返回 `insufficient_coins`；其他计数型 operation 的合法范围由 handler schema 先拦截，Port 再做 defensive check。`append_shop_event_summary` 是唯一可写 20 条 authority summary 的入口，发生在所有业务 operation 成功之后、transaction commit 之前；失败同样 rollback。`select_reward_pool` 只产生 transient selection result，不直接改 `reward_options` 或推进 phase。

事务禁止嵌套；无 active transaction 的 commit/rollback 返回 `false`。快照键精确冻结为 `coins`、`hero_hp`、`roster`、`shop_free_rolls`、`shop_next_discount`、`shop_offers`、`active_shop_pool`、`active_stall`、`shop_event_effects`、`battle_prep_effects`、`outer_run_effects`、`shop_roll_count`、`shop_context_roll_count`、`shop_seen_pet_ids_by_day`、`shop_seed_audit`。其中 Array/Dictionary 全部深复制；不得顺手捕获整个 authority、日志、phase、route、stateVersion、checkpoint 或 RNG 对象。E1 caller 仍负责 phase/ID/day 校验、成功日志、route advance 与 checkpoint，因此 E0 service 既不调用 `_log`，也不推进生命周期。

同一旧 shop event 只追加一个旧形状 summary：`event_id/name/source/node_id/free_rolls/next_discount/targeted_pool_id/construction`，最多 20 条；operation results 不进入 authority/Snapshot。新增行为若需要公开新结果字段，属于新协议轴，必须另行版本化，不能偷加到旧 summary。

### E1 versioned definitions/content bind

新增 `run_event_definition_registry.gd`、`legacy_run_event_catalog.gd` 与 `data/content/extensions/run_event_operations.json`。包固定 `package_id=extension.run_event_operations.v1`、`priority=100`，先 `set ["economy","runtime_schema_version"]=1`；之后每条 operation/trigger 都用独立 `append_to`，不能嵌套数组：

```json
{"op":"append_to","path":["economy","events"],"match_key":"id","match_value":"evt_discount","field":"event_operations","value":{"id":"evt_discount.cost","operation":"spend_coins","priority":0,"params":{"amount":1}}}
{"op":"append_to","path":["economy","events"],"match_key":"id","match_value":"evt_battle_fail","field":"event_triggers","value":{"id":"evt_battle_fail.lose","hook":"post_battle","priority":100,"conditions":{"result_codes":["LOSE"]},"condition_label":"battle_loss"}}
{"op":"append_to","path":["route","node_pool"],"match_key":"nodeId","match_value":"node_rest_gold","field":"event_operations","value":{"id":"node_rest_gold.heal","operation":"heal_hero","priority":100,"params":{"amount":4}}}
```

- event operation 必填 `id/operation/priority/params`；同 entity 内 ID 唯一；trigger 必填 `id/hook/priority/conditions/condition_label`。只允许 JSON-compatible values，拒绝脚本路径和 reserved `__*` 参数。
- 金币费用全部显式为 priority 0 的 `spend_coins`；`cost/gain/option_text/name/note` 从此只展示，core 不解析任何中文规则。
- 16 个现有 formal event 都显式声明 operation；当前未触发的 `evt_elite_reward` 使用 `noop`，不能靠缺字段猜。六个定向补货、free roll、discount、duplicate、upgrade、两种 battle prep、curse gold、两个 post-battle event 分别映射到上述 handler；`evt_curse_gold` 固定 add 4 后 queue 90% multiplier。
- 两个 post-battle trigger 用结构化 `result_codes` 选择；`_post_battle_events_for_result` 不再含具体 event ID。结果仍保持旧 `condition/reward_pool_from/reward_pool_to/gain/value` 形状。
- 当前所有 rest route node 都显式附加 `heal_hero amount=4`、`add_coins amount=2`，即使源 node 的 `value/note` 不同也保持迁移前真实行为；新 rest node 缺 operations 必败，不能默认套旧常量。

16 个 live event 的 disposition 冻结如下；每格按从左到右顺序生成独立 `append_to`，operation ID 固定为 `<event_id>.<verb>`，未列出的展示字段不参与规则：

| event IDs | operations / trigger |
|---|---|
| `evt_shop_fire/water/wind/earth` | `spend_coins amount=1`；`refill_shop_pool pool_id=elem_火/水/雷/地, minimum_slots=3, contexts=[shop_event]` |
| `evt_role_summon/tank` | `spend_coins amount=2`；`refill_shop_pool pool_id=role_召唤/坦克, minimum_slots=3, contexts=[shop_event]` |
| `evt_free_roll` | `add_free_refreshes amount=1` |
| `evt_discount` | `spend_coins amount=1`；`set_next_discount percent=50` |
| `evt_duplicate` | `spend_coins amount=4`；`duplicate_first_pet`；`refill_shop_pool pool_id=special_merchant, minimum_slots=3, contexts=[shop_event]` |
| `evt_upgrade_offer` | `spend_coins amount=6`；`upgrade_first_eligible_pet`；`refill_shop_pool pool_id=special_merchant, minimum_slots=3, contexts=[shop_event]` |
| `evt_battle_bonus` | `select_reward_pool pool_id=reward_fast_clear`；post-battle trigger `result_codes=["WIN_FAST"]`, `condition_label=fast_clear_win` |
| `evt_battle_fail` | `select_reward_pool pool_id=reward_none`；post-battle trigger `result_codes=["LOSE"]`, `condition_label=battle_loss` |
| `evt_trap_bonus` | `spend_coins amount=2`；`queue_trap_damage_bonus amount=1` |
| `evt_shield_bless` | `spend_coins amount=2`；`queue_battle_prep_shield amount=2` |
| `evt_curse_gold` | `add_coins amount=4`；`queue_reward_gold_multiplier percent=90` |
| `evt_elite_reward` | `noop`；本轮不新增未存在的触发条件 |

rest IDs 精确为 `node_rest_gold` 与 `node_d02_rest_gold` 至 `node_d10_rest_gold`；十个节点一律先 `heal_hero amount=4`、再 `add_coins amount=2`。这项刻意不采用源数据当前 `value=2/3/4/5`，因为迁移目标是保持 live code 的固定 +4/+2 结果；若策划要改为数据值，应另开平衡变更，不能混入架构迁移。

上述 contexts 是迁移前差异的结构化表达：`apply_shop_event` 会对定向/构筑事件补货，而 `_apply_route_event` 对同一 event 只结算扣费、free/discount/construction 与 summary，不补货。两条 caller 共享 Definition Registry + Service，但必须分别传 `shop_event` 与 `route_event`；不得为了“统一”而改变任一路径结果。

`RunEventDefinitionRegistry.prepare_configuration(content, source_kind)` / `commit_configuration(candidate)` 使用与 Quality 相同的一次性 opaque candidate 和 last-good 原子语义。source-kind 规则也相同：current assembly 与 versioned persisted snapshot 只要 `runtime_schema_version >= 1` 就必须全部显式；缺版本或版本 `< 1` 的 persisted snapshot 只允许 frozen 16 event 与冻结 rest node IDs 使用 legacy catalog；新 ID 永不 fallback。当前 extension 写入版本 1，但 reader 不把 `1` 错当成唯一可读版本。

Registry public surface 冻结为：

```gdscript
prepare_configuration(content: Dictionary, source_kind: StringName) -> Dictionary
commit_configuration(candidate: Dictionary) -> void
_is_configuration_candidate_pending(candidate: Dictionary) -> bool
is_configured() -> bool
validation_errors() -> Array[String]
operations_for_event(event_id: String) -> Array
operations_for_rest_node(node_id: String) -> Array
matching_post_battle_events(result_code: String) -> Array
```

三个 query 只返回 registry 内已规范化 blueprint 的深复制，不返回 handler、Script、authority 或原始 content 引用。`matching_post_battle_events` 每项固定为 `{event_id, trigger_id, priority, source_index, trigger_index, condition_label, operations}`，按 `priority/source_index/trigger_index/trigger_id/event_id` 稳定排序；caller 再用 `event_id` 查展示数据并调用同一 `RunEventEffectService`。未知 event/rest/result 返回空数组；对于 current/versioned 内容，任何 formal event 或 rest node 在 prepare 阶段缺定义已使整包失败，因此 query 的空结果不能被 caller 解释成默认规则。

CoreComposition 的 content binding 必须同时 prepare Quality 与 RunEventDefinition，二者全成功且两个 opaque candidate 都仍 pending 后才 commit；两个 registry 的 commit 都只消费已验证的内存 blueprint，不得调用外部代码或再产生可失败分支。任一 prepare/pending 检查失败都不 commit，保持两个 registry、`game_data`、content/source/hash cache 全部 last-good。Composition candidate 只保存两个 registry token，不能保存或复制第二份 content authority。

### E2 caller migration/order

- `_battle_prep_effect_from_event`、`_outer_run_effect_from_event`、`_apply_event_effect`、`_is_construction_*`、`_parse_gold_cost` 变成 Service caller 或删除。
- `choose_route` 的 rest 走 source node `event_operations`；route/shop event 都通过同一 Definition Registry + Service。
- `_post_battle_events_for_result` 按结构化 trigger 稳定排序解析，不出现 `evt_*` 字面量。
- 保持原顺序：校验 phase/id/day -> 全量 operation 校验 -> transaction 内扣费/执行 -> pending/summary commit -> 既有日志 -> route/phase advance -> command checkpoint。
- insufficient coins 仍返回原公开 bool/Result 与旧玩家日志；invalid operation 使用稳定错误码，但不扣费、不改 HP/coins/shop/roster/pending、不写日志、不推进 route/RNG/checkpoint/stateVersion。

验证新增 discovery/typed/params/duplicate/unknown/missing capability/rollback smokes；既有 route economy、shop event、post-battle、save/checkpoint/replay/history 与 content hash 全覆盖。static test 禁止 `evt_battle_fail/evt_battle_bonus` 以及 `find("护盾")`、`find("金币")`、`find("免费刷新")`、`find("折扣")`、`find("复制")`、`find("升阶")`、`find("升级")`、`find("候选")`、`find("商品位")`、`find("补货")` 出现在 core 执行代码。

提交拆为 `refactor(run): validate typed event operations`（E0，不改变 production 行为）和 `refactor(content): bind versioned run event definitions`（E1/E2）。extension 未回写上游时 `DATA_SYNC_PENDING`。

## 10. Atom L：Leader 边界（本轮默认不实施）

设计冻结：`leader_catalog` 的条目含 `id/side/display_name/snapshot_id/guard_handler/damage_cap`；状态仍只拥有 hero/enemy HP 等现有事实，catalog 只投影显示与 guard policy。禁止加入第二份 leader HP。

只有以下任一成立才重开并单独出协议迁移：正式内容出现第二个可选 player/enemy leader；Snapshot 需要公开稳定 leader content ID；或现有固定 guard policy 阻塞新规则。重开时必须决定 command、save、replay、hash、历史迁移，不能在本任务顺手添加 selected_leader。当前 `_leader_unit/_sync_leader_hp_from_target/_leader_guard_side` 保留，标记 `保留 + 重开条件`，不是本轮未完成项。

## 11. 实施顺序与提交/回滚

1. A0：本规格 + 任务卡，`docs(architecture): specify open extension bottom stability`。
2. S：商店发现式纵向证明。
3. M1：四个 clean mechanism Service。
4. 等 C5b 归档；重新取 HEAD/SHA/caller/租约。漂移则更新规格为 `REBASE_REQUIRED`，不直接继续。
5. C + Q：content bind 后品质 operation。
6. E：typed route/shop event。
7. M2：仅当 game_state 剩余 mechanism ID 分支仍存在且无租约时，按 M 契约迁移。
8. L 默认跳过，除非重开条件成立。
9. 最终验证、精确暂存、归档任务卡；不推送。

每次提交前 `git diff --cached --name-only` 必须只有该 atom 文件。回滚使用普通 `git revert <atom-commit>`；数据 atom 与代码 atom若存在依赖，先回滚后置 caller，再回滚 registry/schema。禁止 reset/checkout 用户 WIP。

## 12. 全量完成门

只有同时满足以下条件，任务才可 `complete`：

- S/M/C/Q/E 所有非条件 atom 已提交；L 依本文明确跳过或有独立协议提交。
- 新同类 shop/mechanism/quality/event fixture 只加 handler/data 就工作，registry/Service/state 无编辑。
- 稳定底层中不再有对应业务 ID/中文文案分支；static forbidden-token tests 通过。
- 所有 registry 对 duplicate/missing/wrong arity/unknown operation 均在 mutation 前 fail closed。
- `YsbzsState` 仍是唯一 authority；handler source scan 不含完整 core/state 存取。
- Command envelope、Result/Trace/Snapshot schema 无变化；若任何变化，必须有独立版本化迁移，不能算本规格原实现。
- normalized、stateHash、save、checkpoint、replay、Battle query 六 golden 全部保持；content revision 因 extension 增加允许变化，但旧历史仍可加载且 replay 结果一致。
- focused tests、`smoke_architecture_boundaries.gd`、`smoke_sts2_guided_capability_boundaries.gd`、composition ownership、content package 测试、`python3 tools/qa/run_qa.py --suite fast`、`git diff --check` 全通过。
- `git status --short` 中只剩任务开始前已记录的他人 WIP；本任务卡从 doing 移到 done，index 只在租约释放后精确更新。
- extension JSON 尚未回写正式策划上游时明确报告 `DATA_SYNC_PENDING`，但不以手改 generated pack 假装已同步。

## 13. 实施代理停机条件

实施代理只在以下情况停并回报架构师：目标租约冲突；baseline SHA 漂移；现有 Port 无法表达 primitive；公开 schema/hash/replay 必须改变；现有测试与冻结 parity 矛盾；需要编辑 generated pack；或 atom 无法独立回滚。其余局部命名、文件拆分和测试修复按本文直接完成，不向用户反问。
