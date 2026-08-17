# 2026-08-03 Facade 死代码清理 — 可执行设计规格

author: Claude（架构师）
status: SPEC_READY（交付实现方执行；架构师不直接改代码）
基准: `HEAD`（commit `d94be93` 切链后）

## 目标

`core/state/game_state.gd`（8049 行 / 518 方法单一权威门面）在切链后遗留 **24 个零引用死方法** 与 **4 处过时分层注释**。本规格给出可逐字执行的删除方案：删除后 stateHash / save / replay / contentHash 冻结值不得漂移，方法计数 518 → 494。

## 冻结基线（验收必须逐项一致）

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| 方法计数 | 518 → 494（-24） |
| 反向依赖 | `0 methods / 0 calls`（`METHOD_INVENTORY.md` 现有断言） |

P0 探针：`tests/core/dump_puzzle_refactor_baseline.gd`。架构师已验证：按本规格删除后探针仍 `assertions: pass`，三哈希与冻结值完全一致。

## 1. 删除清单（24 个，逐名验证零引用）

来源 `reports/architecture/METHOD_INVENTORY.md` 归零列表；剔除了 `_init`（构造函数）、`_record_damage_trace`（`damage_resolution_port.gd:67` REQUIRED_PORT_METHODS 契约）两个机械误报。`_shape_catalog` / `_id_value` 为词边界验证 0 引用（非子串误报）。

| 方法 | 块（HEAD 1-based，闭区间） | 行数 |
|---|---|---|
| `_roster_index_for_pet` | L999..L1001 | 3 |
| `_roster_instance_id_exists` | L1011..L1013 | 3 |
| `_active_slot_available` | L1097..L1099 | 3 |
| `_next_active_slot_excluding` | L1100..L1102 | 3 |
| `_bag_slot_available` | L1112..L1114 | 3 |
| `_farthest_cell_index` | L1346..L1348 | 3 |
| `_target_exists_at_cell_index` | L1359..L1365 | 7 |
| `_replay_initial_json_safe` | L1795..L1797 | 3 |
| `_shape_catalog` | L2648..L2650 | 3 |
| `_quality_mark_matches_cell` | L3819..L3821 | 3 |
| `_auto_position_choices_signature` | L4236..L4238 | 3 |
| `_auto_position_choices_placement_signature` | L4239..L4241 | 3 |
| `_auto_position_beam_is_better` | L4395..L4397 | 3 |
| `_damage_trace_protocol` | L5100..L5102 | 3 |
| `_hash_seed` | L5874..L5876 | 3 |
| `_id_value` | L5886..L5888 | 3 |
| `_seeded_weighted_unique` | L5889..L5891 | 3 |
| `_replay_event_id` | L7645..L7647 | 3 |
| `_replay_battle_trace_change` | L7653..L7655 | 3 |
| `_replay_battle_trace_protocol` | L7656..L7658 | 3 |
| `_replay_battle_trace_text` | L7659..L7661 | 3 |
| `_replay_error_payload` | L7665..L7667 | 3 |
| `_save_phase_label` | L7703..L7705 | 3 |
| `_save_summary_text` | L7706..L7708 | 3 |

合计 76 行。块边界算法：从 `func <name>(` 声明起，到下一列 0 行（`^(func |static func |var |const |## |class_name |extends |enum |signal |@)`）前止。

## 2. 删除机制（⚠️ 关键：降序自底向上）

**必须在按 `start` **降序** 排序后自底向上删除。** 迭代升序列表 + 原地 `del` 会在前次删除后令后续索引失效，导致删除**活代码**（已实测：曾误删 `_add_pet_to_roster`、`reset()` 整个函数体、`_cell_detail_unit`、`load_from_user`、`roll_shop`、`_nearest_player` 等 17 处共 ~398 行，文件残缺）。正确脚本：

```python
import re
BOUNDARY = re.compile(r"^(func |static func |var |const |## |class_name |extends |enum |signal |@)")
lines = open("core/state/game_state.gd", encoding="utf-8").read().split("\n")
blocks = []
for name in TARGETS:                      # TARGETS = 上表 24 个方法名
    hits = [i for i, l in enumerate(lines) if l.startswith(f"func {name}(")]
    assert len(hits) == 1
    s = hits[0]; e = len(lines)
    for j in range(s + 1, len(lines)):
        if BOUNDARY.match(lines[j]):
            e = j; break
    blocks.append((s, e, name))
for s, e, name in sorted(blocks, key=lambda b: b[0], reverse=True):  # 降序！
    assert lines[s].startswith(f"func {name}(")
    del lines[s:e]
open("core/state/game_state.gd", "w", encoding="utf-8").write("\n".join(lines))
```

删除后自检：`func 声明 518 → 494`；24 个目标 `func <name>(` 全文件 0 命中；`git diff` 中 `-func ` 行恰好为这 24 个、无 `+func ` 行。

## 3. 注释编辑（3 处，与删除同提交）

| 位置 | 原文 | 新文 |
|---|---|---|
| L182-183 | `## Authoritative fields and the virtual cross-layer contract for YsbzsState.` / `## Business implementations live in the ordered core layers above this base.` | `## Authoritative fields for the single gameplay facade. Domain algorithms are` / `## composed explicitly through CoreComposition services and narrow ports.` |
| L271 | `## Stable public entrypoint for the layered authoritative core.` | `## Stable public entrypoint for the single authoritative facade.` |
| L2395-2397 | `## Shared read-only rules live at the earliest compatibility layer that consumes` / `## them. Battle/run descendants inherit these queries; no service caches writable` / `## authority state here.` | `## Shared read-only rules used by multiple domains; no service caches writable` / `## authority state here.` |

## 4. 实现方验证（按序执行，全部通过才可提交）

1. `python3 tools/qa/inventory_core_methods.py --output reports/architecture/METHOD_INVENTORY.md` 重生成，再 `--check`；方法计数 518 → 494、反向依赖保持 `0/0`。
2. `godot --headless --check-only --script core/state/game_state.gd` 退出 0。
3. `godot --headless --script tests/core/dump_puzzle_refactor_baseline.gd`：`assertions: pass`，三哈希与冻结值一致（见上表）。
4. `git diff --check`。
5. 可选：focused 架构 smoke + 完整 fast suite。

## 5. 提交与归档边界

- 单个提交：24 个死方法 + 3 处注释 + `METHOD_INVENTORY.md` 重生成 + 任务卡归档。
- 精确暂存：`git add core/state/game_state.gd reports/architecture/METHOD_INVENTORY.md <任务卡>`；**禁止 `git add .` / `git add -A`**。
- 提交后任务卡移入 `tasks/done/`，刷新 `tasks/index.md`；不推送。
- 冲突审计：`2026-07-15_mouse-playtest-day1-day2` 仅声明 `_cell_detail_unit()` 写范围，与本次删除目标无交集。

## 后续（不在此提交范围）

24 个死方法（76 行）是极薄转发层，未触及真正的主体重构：47 个 ≥30 行方法（~2626 行业务逻辑）仍驻留 facade，属下一阶段"下沉组合服务"迁移的设计范围，本规格不覆盖。
