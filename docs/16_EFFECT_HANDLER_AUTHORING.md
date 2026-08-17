# Effect Handler 作者规范

> 本文记录当前 Effect Handler 接口和 Registry 的真实契约，方便定位代码；它不是 AI 工作流规则。若修改接口，应以调用方和测试同步后的 live source 为准。

## 先判断是否真的需要新 Handler

Effect Handler 表达一种新的权威能力原语。已有 `physical_damage`、`heal`、`grant_shield`、`apply_status`、`remove_status`、`apply_element_layer`、`modify_stat` 能通过 JSON 参数和多个 effect 组合表达时，只新增 Content Pack，不写新 Handler。只有输入、输出或权威 mutation 语义确实新增时，才扩展 `core/effects/handlers/`。

真实成本应限制在 Handler、对应窄 Port 能力、JSON 和专项案例；不得修改继承链分发、增加中央 ID 映射、Autoload 或第二权威状态。

## 三方法契约

每个 `core/effects/handlers/*.gd` 都是无状态 `RefCounted`，并必须实现：

```gdscript
func plugin_id() -> String
func consumed_stats(effect: Dictionary, source_kind: String) -> Array[String]
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant
```

- `plugin_id` 是 JSON `type` 使用的稳定 ASCII ID；目录内必须唯一且非空。
- `consumed_stats` 必须如实列出本次效果读取的最终 stat。使用 `StatIdsScript` 常量；条件分支和 Skill/Combo 差异也必须反映在返回值中。它决定 Trait modifier 是否进入效果计算和归因，不是可选文档。
- `execute` 只解释参数和选择 Port 方法。Handler 不读取文件、不持有 Node、不访问 `YsbzsState`、不创建全局服务，也不直接改权威状态。

Registry 自动扫描目录，不需要手工注册。发现期同时校验 `plugin_id()` 为 0 参数、`consumed_stats(effect, source_kind)` 为 2 参数、`execute(port, context, effect)` 为 3 参数。任一脚本缺少方法、参数数量错误、ID 为空/重复、加载或实例化失败，整个效果 Registry 都 fail-closed，不暴露半套插件，也不把签名错误拖到第一次调用时才暴露。

## 实现步骤

1. 复制 `tools/templates/effect_handler.gd.template` 到 `core/effects/handlers/<effect_id>_effect.gd`，替换全部 `REPLACE_ME`。
2. 若现有 Port 没有所需 mutation，给相关窄 Port 增加一个有语义的方法；不要把整个 State 或任意 Callable 暴露给 Handler。
3. 在 Content Pack 中使用稳定 JSON，例如：

```json
{
  "type": "grant_shield",
  "target": "self",
  "amount": 4
}
```

4. 在 `tests/core/smoke_effect_handler_contract.gd` 的 `HANDLER_CASES` 增加同 ID 案例，声明输入 effect、source kind、唯一预期 Port 方法、精确 `consumed_stats`，以及 Handler 负责补齐的默认 target。
5. 若字段有新的必填/引用语义，同步扩展加载期 Schema；数据错误必须在 GameDataRepository 边界拒绝，不能等到 execute 才静默跳过。
6. 跑专项、Effect Schema、开放扩展、P0 冻结基线和 fast。

## 返回与默认值

`execute` 可返回 `Dictionary`、`bool` 或其他值；推荐返回 `{"applied": bool, "targets": [], "payload": {}}`。Interpreter 会规范化 `applied`，并只在成功时记录效果归因。需要默认 target 时复制 effect 后写入，禁止修改 Content Pack 传入的原 Dictionary。

默认值和字段名统一复用 `EffectVocabulary`；stat、hook、operation 统一复用相应常量。不要在新 Handler 中重新散落同义字符串解析。

## 长期门禁

`smoke_effect_handler_contract.gd` 要求 Registry ID 与 `HANDLER_CASES` 双向精确相等：新增脚本却没有案例、删除脚本却遗留案例都会失败。它还通过真实 `EffectInterpreter` 深比较每个 Handler 传给 Port 的完整 context/effect、缺省与显式 target、`effect_applied` outcome 中的精确 stat 归因，以及 Skill/Combo 的完整 stat 集合；缺方法或三方法参数数量错误时 Registry 必须在发现期整体拒绝。
