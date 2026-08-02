# Core UI

`core_ui/scripts/` 是项目唯一的 UI GDScript 根目录。

```text
core_ui/scripts/
├── app/             正式装配、功能注册与场景路由
├── artist_flow/     路线/商店/背包/队伍组合界面适配
├── battle/          战斗控制器、投影、HUD、VFX 与 prefab 表现
├── route/           路线 Presenter / Controller
├── shop/            商店 Presenter / Controller
├── inventory/       背包 Presenter / Controller
├── party/           队伍 Presenter / Controller
├── settlement/      结算 Presenter / Controller
├── shared/          跨界面复用的表现脚本
└── debug/           调试场景脚本
```

规则：

- 所有正式 UI `.gd` 和 `.gd.uid` 放在这里；`art/` 内不放脚本。
- 场景与预制体分别引用 `art/scenes`、`art/prefabs`，图片引用 `art/images`。
- 只负责装配、状态投影、表现、输入、信号和公开接口。
- 不创建第二个权威状态，不在这里复制 `core/`、`session/` 或 `persistence/` 的玩法逻辑。
- 新 scope 同时创建 `art` 视觉路径和 `core_ui/scripts` 脚本路径，不恢复 `features/`、`game/` 或 `assets/` 旧目录。
- `app/game_controller.gd` 是唯一 Session 和 Feature 生命周期拥有者；美术 Scene 只发送语义 Command，不能发送目标 Scene 请求。
- `app/scene_router.gd` 只管理 `FeatureHost` 子节点，不读取 Snapshot 或 phase。完整链路见 `docs/SCENE_ROUTING_STANDARD.md`。
