# 权威会话服部署

服务仅监听 `127.0.0.1:9080`，公网入口由 nginx 终止 TLS，并把 `/session/` 升级为 WebSocket。

`/etc/ysbzs/authority.env` 必须由部署系统以 `0600` 权限创建，至少包含：

```text
YSBZS_SESSION_SECRET=<至少32字节随机值>
YSBZS_SESSION_ID=production
YSBZS_BIND_ADDRESS=127.0.0.1
YSBZS_PORT=9080
GODOT_USER_HOME=/var/lib/ysbzs
```

部署包需包含 Godot 4.7.1 标准二进制、项目资源和本目录的 systemd/nginx 配置。启用前依次执行 `nginx -t`、systemd 服务启动与本机 WebSocket 端到端 smoke；密钥不得进入仓库、日志或客户端构建。

签发短效令牌示例：

```sh
YSBZS_SESSION_SECRET='...' bin/godot --headless --path . --script res://session/auth/issue_session_token.gd -- --actor=player-a --session=production --ttl=300
```
