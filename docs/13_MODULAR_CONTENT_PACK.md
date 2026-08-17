# 模块化内容包

## 目标

正式运行数据位于 `data/content/**/*.json`。`GameDataRepository` 递归读取文件，经 Validator、Registry、Assembler 确定性装配成兼容现有核心的 Dictionary；运行时不再读取单体快照。

这套边界组合了 Type Object、Registry、Specification 和 Assembler：

- JSON 是 Type Object，只声明数据，不指定脚本路径。
- Reader 只负责发现和解析文件。
- Validator 校验 package schema 与声明式操作结构。
- Registry 对 `package_id` 去重并按 `priority -> order -> package_id` 排序。
- Assembler 应用声明式操作；任何重复路径、缺失父级或缺失绑定目标都会让整个内容集 fail-closed。
- `EffectContentValidator` 在所有 package 装配完成后递归校验效果语义；未知 effect/condition/target/operation 插件 ID、stat/hook ID、状态引用或跨包 stat 定义缺失都会让整个内容集 fail-closed。

`GameDataRepository` 的装配缓存归每个 repository 实例所有。新建 Session 会获得独立缓存，不会因先前的 Session、测试或内容根目录污染而读到过期数据。语义校验发生在缓存和返回之前；失败项只缓存空数据与确定性错误列表，不能伪装成一次成功加载。

## 目录

- `data/content/generated/`：由正式导出器机械重建，不手改。
- `data/content/extensions/`：JSON 先行扩展，一个功能通常一个文件。
- `persistence/content_pack_*.gd`：读取、验证、注册与装配服务。
- `tools/export_*`：按领域拆分的上游转换器，正式入口是 `export_ysbzs_singleplayer_data.py`。

内容包按独立 `package_id`、业务域、所有权和加载顺序组织，不按行数分片。Reader、Validator、Registry、Assembler 分开是因为它们有不同变更原因；某个高内聚实现较长时可以保留。

## 包格式

```json
{
  "schema": "ysbzs.content-package.v1",
  "package_id": "extension.trait_example",
  "priority": 100,
  "order": 0,
  "operations": []
}
```

支持四种操作：

- `set`：首次定义字典路径；重复定义报错。
- `append`：向已存在数组追加一个实体。
- `append_to`：找到数组内实体，再向其数组字段追加内容；机械导出器使用。
- `attach_unique`：延迟到基础内容完成后绑定，重复值不再追加；扩展文件优先使用。

## 新增特性

普通特性只新增 `data/content/extensions/trait_<id>.json`。同一文件包含两个 operation：

1. `set ["trait_catalog", "trait_<id>"]` 定义特性。
2. `attach_unique` 把特性 ID 绑定到一个宠物的 `traits`。

不需要修改 Registry、Assembler、宠物类或中央映射。只有新增当前四种操作无法表达的权威能力时，才修改基础服务并增加协议测试。

技能、组合、状态和普通属性采用相同方式：一个扩展文件既可定义目录对象，也可声明目标绑定。效果类型、属性玩法语义和条件仍由现有安全插件注册表控制。

添加同类内容只应增加 JSON，并复用已有 effect type。只有当现有效果无法表达新的权威能力原语时，才新增 `core/effects/handlers/*.gd`；目录扫描会确定性校验 `plugin_id()` 和 `execute()`。任一脚本加载/实例化失败、ID 缺失/为空/重复或必需方法缺失，会清空本次注册结果并拒绝执行，禁止半套内容带病运行。JSON 仍不得指定任意脚本路径。

## 效果 vocabulary 与加载期 Schema

`core/effects/effect_vocabulary.gd` 是效果 Dictionary 的唯一字段解析入口，集中 `type`、`stat` / `stat_id`、`operation`、`hook`、`target`、`condition` 和 `status_id` 的 key、trim 与默认值。Trait、Status、Interpreter、Condition、Target 和 StatResolver 不再分别解释这些字段。`core/stats/stat_ids.gd`、`core/stats/stat_operation_ids.gd` 与 `core/effects/effect_hook_ids.gd` 提供当前公开 ID 常量；效果/条件/目标的开放插件 ID 不复制成中央映射，仍以对应目录 Registry 为唯一真相源。

Hook vocabulary 按发布职责分成 8 个 executable trigger hook 与 28 个 StatQuery hook；`modify_stat` 可以绑定 `always`、trigger 或 StatQuery hook，`StatResolver` 对 permanent/equipment/runtime/extra 全部 modifier 统一执行 `always || modifier_hook == query_hook`。Trait/Status 收集的非 modifier 效果必须显式绑定 trigger hook；Skill/Combo/Relic 直接执行的非 modifier 效果禁止声明会被 Interpreter 忽略的 hook。运行时 publisher 和默认值统一引用这张 vocabulary，避免内容校验表与真实发布面各自演进。条件插件可以选择实现 `content_schema_errors()` 声明自己的必填字段，中央 validator 只负责调用契约，不内置 `stat_compare` 等插件 ID 分支。

加载顺序固定为：

```text
Reader -> package Validator -> Registry -> Assembler
       -> EffectContentValidator -> repository cache/result
```

因此技能包可以引用稍后才装配的 stat/status 包，但所有跨包引用必须在最终装配图中成立；任意显式 `status_id` 都必须解析到装配后的 `status_catalog`。`flat_add_per_stack` 是 StatusService 在进入 StatResolver 前消费的唯一内容适配 operation，只允许出现在顶层 owner 确认为 `status_catalog` 的定义中，不能靠嵌套 key 或对象 ID 同名伪造作用域；其余 operation 必须命中 `core/stats/operations/` 的目录 Registry。新增普通内容只复用现有 ID；新增 stat 或 operation 能力原语必须显式扩展常量表、数据 Type Object / operation 插件及专项测试。

长期门禁 `tests/core/smoke_effect_content_schema.gd` 已加入 `fast`：它检查当前 47 个 stat Type Object 与常量表精确对应，并对未知 effect type、stat、operation、hook、target、condition、status 引用和 stat 定义逐项做 repository 边界 mutation；还覆盖 SkillEffectPort 生成的 scoped runtime modifier 在 movement 生效而不泄漏到 snapshot、Trait/Status hook 必填、Skill/Combo/Relic ignored-hook 拒绝、owner path collision、缺 stat 的插件条件，以及两条 legacy Trait 分支的实际归一化行为。运行期的“跳过未注册效果”仍作为防御，但不能替代加载期拒绝。

## 导出与迁移

完整上游同步运行：

```bash
python3 tools/export_ysbzs_singleplayer_data.py
```

导出器直接重建 `generated/`，保留 `extensions/`，不会生成运行时单体 JSON。迁移历史快照可运行 `python3 tools/split_content_pack.py --input <snapshot>`。

未同步 workbook / CSV 时记录 `DATA_SYNC_PENDING`，但不阻塞 Godot JSON 实现、验证或提交。专项 smoke 检查装配指纹、单文件特性、业务域包所有权、重复 ID 和缺失绑定目标，不检查文件行数。
