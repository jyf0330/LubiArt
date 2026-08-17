# 场下遗物战斗时间轴

## 边界

- 宠物仍在棋盘上，继续使用现有行动与 8 技能顺序；遗物是场下对象，不占棋盘格，也不进入宠物行动队列。
- `YsbzsState.relic_inventory` 是持有遗物的权威库存，`YsbzsState.relic_combat_state` 是当前战斗的权威时间轴。服务不持有第二套可存档状态。
- 时间轴只使用整数 `tick`，不使用 Godot `Timer`、`_process()` 或每 `0.1` 秒全量扫描。
- `battle_trace` 是结算后的表现/诊断事件，不反向充当玩法真相源。

## 确定性顺序

定时事件按以下键升序排列：

1. `due_tick`
2. `phase`
3. 遗物 `priority`
4. 全局递增 `sequence`
5. `instance_id`（最终稳定兜底）

重新排期不会从数组中强删旧事件。每次排期递增实例 `generation`，弹出时只接受当前 generation；被 Charge 替换的旧事件因此稳定失效。

同一逻辑时刻产生的语义触发进入独立即时队列。服务正在结算时，新触发只入队，不递归调用，因此遗物之间可以连锁但不会增长调用栈。

## 事件

当前战斗桥接事件：

- `BATTLE_STARTED`
- `SKILL_USED`
- `SKILL_COMBO_USED`
- `DAMAGE_APPLIED`
- `UNIT_DEFEATED`
- `BATTLE_ENDED`
- `TIMER_READY`

上游遗物表里的中文触发会规范化：`战斗开始`、`攻击后`、`受击后`、`死亡时`、`战斗结算`、`商店刷新`分别映射到对应的大写事件名。`SHOP_REFRESHED` 已保留在目录协议中，但战斗服务只在 `battle` 阶段处理；商店侧接入应走同一权威库存，不应创建另一套遗物系统。

## 数据字段

`economy.relics[]` 支持：

- `id`、`name`、`trigger_type`、`priority`
- `cooldown_ticks`：大于 0 时启用周期定时
- `duration_ticks`：效果自身的逻辑耗时（首版仅作为数据契约保留）
- `internal_cooldown_ticks`
- `max_triggers_per_tick`
- `effects`：复用现有效果白名单解释器
- `charges[]`：`target_instance_id` 或 `target_relic_id` 加 `amount_ticks`
- `emit_events[]`：遗物向其他遗物发布语义事件
- `event_filter`：对事件 payload 做精确字段匹配

现有总表导出的 40 条遗物只有旧字段，没有正式冷却、效果 JSON 或 Charge 数值，因此导出器把缺失值保持为 `0` / 空数组，不在代码里猜策划数值。未来应先在 `ysbzs_master.xlsx` 增加正式列和值，再走工作簿 → CSV → Godot JSON 的既定链路。

宠物技能目录同样接受可选 `duration_ticks`。字段缺失时为 0，代表本次技能不会推进遗物逻辑时钟；它不代表使用画面帧或粗粒度 Tick 推进。

## 循环保护

- 单个遗物可配置 `max_triggers_per_tick`。
- 每个逻辑时刻最多处理 1024 个即时事件。
- 一次 `advance()` 最多弹出 8192 个定时事件。

触发保护时，权威状态写入 `last_error`，并追加 `RELIC_LOOP_GUARD` Trace。三个上限是防止坏数据卡死的技术保护，不是策划平衡参数。

## 存档与回放

库存和完整时间轴均由 `authoritative_state_codec.gd` capture / restore，并参与状态哈希。预览命令的临时状态捕获也包含两者，因此预览不能泄漏触发次数、排期或 Charge 结果。
