# 商用运行与发布基线

## 发布门禁

`nightly` 是全部 Session/Core/Feature/Integration 权威 smoke、隔离性 probe 和 24-seed Bot 的 blocking 门禁；`visual` 校验正式入口关键帧。商用门禁不允许非阻塞 quarantine，退役测试及替代覆盖记录在 `qa/retired_tests.json`。

Web 产物由 `tools/release/build_web_release.sh` 原子替换到 `build/web`，包含 `SHA256SUMS`；`tools/release/smoke_web_release.py` 通过本地 HTTP 与 Chromium 启动真实导出物。tag release CI 必须依次通过 headless、visual 与 Web export/browser smoke 才上传产物。

## 性能、崩溃与存档

性能阈值集中在 `qa/performance_budgets.json`，阻塞用例不得用并发负载下的偶发结果放宽预算。`diagnostics/runtime_diagnostics.gd` 每秒采样 FPS、静态内存与进程耗时，最多 600 条；最多保留 20 份本地 JSON 报告。启动标记用于在下一次启动识别未正常退出，报告只落 `user://diagnostics`，后续上传必须由玩家明确同意。

`qa/save_fault_matrix.json` 把原子替换、主档损坏回退、校验和篡改、非法阶段、旧/未来 schema、槽位隔离与越界写入映射到 blocking tests。

## 权威联机

客户端通过 `WebSocketSessionTransport` 连接 `ws/wss`，先提交短效 HMAC-SHA256 bearer token，再发送带 actor/session 身份的命令或 snapshot 请求。服务端限制 1 MiB 消息、2 MiB 缓冲与每连接每秒 60 条消息，并由 `SessionAuthorityHost` 保持 `GameSession -> Command -> State -> Result/Snapshot` 权威边界。

生产服务只监听回环地址，nginx 负责 TLS/WebSocket 升级，systemd 以无特权用户和只读系统目录运行。部署步骤与密钥要求见 `deploy/server/README.md`；仓库不保存 secret，也不把服务端脚本与测试打入 Web 客户端产物。
