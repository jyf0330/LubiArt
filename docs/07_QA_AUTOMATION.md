# QA 自动化说明

> 本文说明已有测试工具和可选验证手段，不是提交门禁。默认先运行与改动直接相关的代码检查和截图；只有确实需要观察连续时序时再录屏。

## 目标

QA 按发现成本分层运行：确定性命令 / replay、现有 smoke、隔离存档的批量 Seed Bot、真实场景输入与关键帧截图，最后按风险选择正式主入口录屏。自动层负责尽早发现功能、规则、存档、性能和稳定视觉问题；录屏负责真实输入、动画时序和受影响的跨阶段流程，只有结算语义受影响时才必须录到最终结算。

统一入口：

```bash
python3 tools/qa/run_qa.py --suite fast
```

本机默认查找 `/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot` 和 `/Applications/Godot.app/Contents/MacOS/Godot`，也可通过 `--godot /absolute/path/to/Godot` 或 `GODOT_BIN` 指定。

## 套件

| 套件 | 用途 | 默认触发 |
| --- | --- | --- |
| `isolation` | 连跑两个写 `user://` 的 probe，确认测试身份和数据目录彼此独立 | runner 自测、`fast` |
| `bot` | 3 个固定 seed 的完整游戏日 Bot | Bot 开发和专项回归 |
| `fast` | Session / 核心 / feature / 玩家流代表 smoke，加 `bot` | PR、开发提交前 |
| `session` / `core` / `features` / `integration` | 按目录枚举对应全部 `smoke_*.gd` | 分层定位、低磁盘分批 |
| `full` | 上述四层的全部权威 `smoke_*.gd` | 大改、nightly |
| `quarantine` | 固定为空；用于兼容旧命令，不允许承载非阻塞测试 | 不触发 |
| `nightly` | `full`、隔离 probe 和 24 个确定性 Seed Bot | 每日定时、手动 |
| `visual` | 正式 `art/scenes/app/game.tscn`、真实 Godot 输入事件、路线到战斗和结算关键帧 | release、UI 改动 |
| `release` | `nightly` 加 `visual` | 本机完整预检 |

清单位于 `qa/suites.json`。查看实际展开项但不运行：

```bash
python3 tools/qa/run_qa.py --suite nightly --list
```

也可直接复现一个或多个测试：

```bash
python3 tools/qa/run_qa.py --test tests/core/smoke_phase_policy.gd
```

## 隔离与证据

runner 为每个测试建立临时项目壳，并通过 `override.cfg` 设置唯一项目身份和 `application/config/custom_user_dir_name`。测试使用的 `user://` 固定落在 `YSBZS_QA/<run>/<test>` 命名空间；运行前清空该测试目录，结束后只删除验证过包含 `YSBZS_QA` 的精确目录。不得让 smoke、Bot 或视觉回归直接使用正式 `YSBZS Godot Singleplayer` 玩家目录。

默认产物：

```text
output/validation/qa/<run>/
├── summary.json
├── junit.xml
└── tests/<test-id>/
    ├── stdout.log（单项最多保留 4MiB 尾部）
    ├── result.json
    └── 失败时的 replay / save / diff / user_data 证据
```

关键参数：

```bash
# 指定产物目录
python3 tools/qa/run_qa.py --suite fast --output output/validation/qa/manual-fast

# 首个失败即停
python3 tools/qa/run_qa.py --suite full --fail-fast

# 临时扩大 nightly 的 Bot 数量
python3 tools/qa/run_qa.py --suite nightly --seed-count 100

# 诊断时保留隔离 user://
python3 tools/qa/run_qa.py --suite isolation --keep-user-data
```

`output/validation/` 是可再生成证据，不加入 Git。CI 无论成功或失败都会上传整个运行目录。

### 商用门禁不接受 Quarantine

`qa/quarantine.json` 与 `qa/suites.json` 的 `quarantine` 清单必须保持为空；现行权威行为必须进入 blocking suite。仅当测试前提已经失效、依赖个人数据或与现行专项门禁重复时，才允许删除，并在 `qa/retired_tests.json` 记录退役理由与 blocking 替代覆盖；禁止静默排除或用 `continue-on-error` 制造全绿。

## Seed Bot

`tests/qa/seed_bot.gd` 使用公开 command、snapshot、save 和 replay 接口完成一个完整游戏日，不直接改内部状态。矩阵位于 `qa/seed_matrix.json`，覆盖固定 seed、`6x6`、`8x7`、`8x8`、normal / easy，并验证：

- 流程能到达 `day_end` 或 `game_over`；
- 棋盘尺寸、英雄生命、单位坐标和占位不变量；
- 命令数量和单例耗时预算；
- replay 逐 checkpoint 验证；
- save / load 后最终 `stateHash` 一致。

失败 case 自动保留对应 replay 和 save JSON，先用该小证据复现，再补入专项 smoke；不要依赖重复看完整录屏定位纯规则问题。

## 历史恢复确定性

- `tests/core/smoke_authoritative_state_codec.gd` 锁定 save/load/hash 共用字段，覆盖被击败单位、回合元素结算保护、自动布置缓存、Trace 和内嵌内容包。
- `tests/integration/smoke_deterministic_run_history.gd` 完成第一天、建立日结与第二天开局 checkpoint、从第一天末创建分支，并要求分支执行同一 `START_NEXT_DAY` 后与原线 `stateHash` 完全一致。
- 同一专项把真实新商品加入可抽取池，要求内容修订单调前进；旧分支必须复用原 `contentRevision` 和压缩共享内容包。run 目录不得再复制 `content_pack.json`。
- 每个 checkpoint 必须声明 `restoreMode=direct_checkpoint`；新历史必须写入无 checkpoint 列表的固定 `run.json` 和确定命名的单日指针。专项会临时移除增长中的 manifest，要求按日恢复仍成功，证明恢复不依赖扫描历史或重放此前命令。
- 同一专项继续写入 100 条以上命令，确认命令日志和 replay 不再以 80 条截断；内容 hash 被修改时 replay 必须明确返回版本不匹配。

历史回归不能只比较“刚读档的 hash”。至少要在原线和恢复线各继续执行同一条后续命令，再比较 Result、Trace、`stateVersion` 与 `stateHash`；否则可能漏掉未持久化但会影响下一步的状态。

## UI 关键帧

`tests/qa/ui_regression.gd` 加载正式 `art/scenes/app/game.tscn`，通过 `Input.parse_input_event()` 发送鼠标移动和按键事件，依次经过路线、商店、奖励、战斗自动布置、开始行动和结算。它在稳定节点抓取 480×270 PNG，并用 Godot `Image.compute_image_metrics()` 的 RMSE 加 changed-pixel ratio 对比当前平台基准；少量延迟消失的伤害数字 / 抗锯齿像素被容差吸收，成片布局变化仍会失败。

基准按平台隔离：

```text
qa/visual_baselines/
├── macos/
├── linux/
└── windows/
```

正常测试缺基准或超出阈值会失败，并生成 `*.actual.png`、`*.diff.png` 和 `ui_regression_results.json`。只有确认变化是预期设计后才显式更新：

```bash
python3 tools/qa/run_qa.py --suite visual --update-baselines
git diff -- qa/visual_baselines
```

本机有专用虚拟屏时，先实时确认其屏幕编号，再附加 `--screen <index>`；该参数只作用于 `display: true` 的测试，CI 默认不指定。

基准更新不能自动发生在 PR / nightly / release CI 中。

## CI 门禁

- `.github/workflows/qa-pr.yml`：PR 和 `main` push 运行 `fast`。
- `.github/workflows/qa-nightly.yml`：每天北京时间 02:17 运行 `nightly`，也支持手动调整 Seed 数量。
- `.github/workflows/qa-release.yml`：tag 或手动触发；Ubuntu 先跑完整 headless 门禁，通过后在 macOS 跑视觉回归。

CI 通过 `tools/qa/install_godot_ci.sh` 从 Godot 官方下载入口安装固定 `4.7-stable`，不会复用浮动的系统 Godot。

## 与连续录屏的边界

自动测试通过不等于战斗界面已经符合预期。涉及棋盘、单位、拖拽、按钮、动画或反馈时，可以从正式主入口截取受影响画面；涉及无法靠静态截图判断的连续时序时，再按需录制相关片段。

推荐闭环：

1. `fast` / 专项 smoke / replay 先找出规则和接口回归；
2. Seed Bot 扩大组合和存读档覆盖；
3. UI 关键帧捕获稳定视觉差异；
4. 只有连续时序需要证据时，才从正式主入口录制相关片段；
5. 录制或截图中发现的新 bug 可以按影响范围另行处理；
6. 修复后重跑相关自动层，再从主入口复验受影响路径。

连续录屏是可选证据，不是默认步骤，也不是唯一的缺陷发现机制。
