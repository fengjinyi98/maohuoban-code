# 登录系统 Goal 进度追踪

- 更新时间：2026-06-13 12:57
- Goal：完成完整登录系统前后端代码与端到端测试，包含数据库清理、Redis、观测、toast 反馈、设计文档和进度追踪。

## 1. 当前结论

| 项 | 状态 | 证据 |
|---|---|---|
| 登录设计稿 | 已读取 | `docs/html/maohuoban-login-design.html` 包含验证码登录、密码登录入口、忘记密码、第三方入口 |
| iOS 工程 | 已实现并通过 UI E2E | 已接入 `AuthRootView`、登录页、验证码页、忘记密码页、网络层、Keychain token store、`maohuobanUITests`；UI E2E 已处理系统保存密码 Sheet |
| DesignSystem Toast | 已完善基础设施 | `MHBToast.duration` 已生效，根视图统一挂载 `.mhbToast()` |
| Rust 后端 | 已实现认证基线 | 已拆为 auth crates，覆盖验证码登录、密码登录、refresh、logout、账号恢复、第三方 TODO 和认证审计事件 |
| 后端架构约束 | 已固化 | `AGENTS.md`、`README.md` 已明确 workspace crates + 分层架构和依赖方向 |
| 真机联调地址 | 已切换到局域网链路 | iOS 默认 API 地址为 `http://192.168.2.2:8080`；`ipconfig getifaddr en0` 返回 `192.168.2.2`；Rust 默认监听 `0.0.0.0:8080`；局域网 IP E2E 已通过 |
| Redis | 可用 | `redis-cli ping` 返回 `PONG`，Redis server `8.6.2` |
| PostgreSQL | 可用 | Postgres.app 监听 `127.0.0.1:5432`，客户端在 `/Applications/Postgres.app/Contents/Versions/18/bin/psql` |
| 新数据库 | 已创建 | `psql -lqt` 显示 `maohuoban` 数据库 |
| 旧项目表 | 已清理 | `maohuoban.public` 当前只保留 `_sqlx_migrations` 和 5 张认证业务表 |

## 2. 已识别旧表

旧表位于 `fengjinyi.public`，包括：

```text
_sqlx_migrations
admin_audit_logs
admin_roles
admin_user_roles
admin_users
board_change_logs
board_media_history
boards
business_events
device_sessions
media_assets
media_bindings
media_components
media_moderation_jobs
media_processing_jobs
media_upload_sessions
metrics_daily_board_growth
post_album_items
post_albums
post_bookmarks
post_comment_likes
post_comments
post_likes
post_media_items
post_poll_options
post_poll_votes
post_polls
post_publish_drafts
post_share_events
post_topics
post_view_events
posts
remember_login_credentials
reserved_partner_codes
topic_follows
topic_view_events
topics
user_devices
user_follows
user_ip_locations
user_profile_change_logs
user_profiles
users
```

清理策略：

| 操作 | 状态 |
|---|---|
| 创建独立 `maohuoban` 数据库 | 已完成 |
| 删除 `fengjinyi.public` 旧表 | 已完成 |
| 在 `maohuoban` 库执行新迁移 | 已完成，`psql -d maohuoban -c '\dt'` 显示 6 张认证表 |

## 3. Phase 进度

| Phase | 状态 | 下一步 |
|---|---|---|
| 1. 文档与环境准备 | 已完成 | 进入后端 TDD 和迁移实现 |
| 2. 后端认证能力 | 已完成基线 | 进入 iOS 登录前端和端到端验证 |
| 3. iOS 登录前端 | 已完成基线 | 进入后端 + 模拟器端到端验证 |
| 4. 端到端验证 | 已完成 | HTTP E2E、局域网 HTTP E2E、iOS UI E2E、Rust 测试、Rust lint、iOS 构建均通过 |

## 4. 验收清单

| 要求 | 证据 | 状态 |
|---|---|---|
| 设计文档落地 | `docs/engineering/auth/00_登录系统设计文档.md` | 已完成 |
| Goal 进度文档落地 | 当前文档 | 已完成 |
| 旧表删除 | `psql -d maohuoban` 只显示 `_sqlx_migrations`、`auth_audit_events`、`device_sessions`、`password_credentials`、`user_identities`、`users` | 已完成 |
| Redis 用于验证码 | `RedisOtpChallengeStore` 存储 challenge，契约测试完成发送与消费链路 | 已完成基线 |
| 开发验证码固定 `123456` | `auth_contract.rs` 覆盖验证码登录成功 | 已完成 |
| 后端返回准确 message | `auth_contract.rs` 断言登录、refresh、logout、账号恢复、第三方 TODO 的中文 message | 已完成 |
| 双 token 可刷新 | `refresh_rotates_refresh_token_and_rejects_old_token` 覆盖 refresh 轮换与旧 token 拒绝 | 已完成 |
| 多设备可扩展 | `device_sessions` 包含 `device_id`、`device_name`、`platform`、`app_version`、`previous_refresh_token_hash` | 已完成基线 |
| 第三方登录 TODO 壳 | `/api/v1/auth/oauth/apple` 返回 `auth.oauth_todo` / `Apple 登录暂未开放` | 已完成 |
| Logout 当前设备 | `logout_revokes_current_device_refresh_session` 覆盖退出后 refresh 失效 | 已完成 |
| 忘记密码独立边界 | `account_recovery_resets_password_and_revokes_old_sessions` 覆盖独立接口、密码重置、旧 session 撤销 | 已完成 |
| 前端符合设计稿 | 模拟器截图复核通过；UI E2E 覆盖登录页、验证码页、忘记密码页、系统保存密码 Sheet、首页退出入口 | 已完成 |
| Toast 声明式反馈 | `MHBToastPresenter` 统一消费后端 message；`MHBToast.duration` 支持单条时长 | 已完成基线 |
| 观测接入 | `auth_flow_writes_audit_events_for_observability` 覆盖 `auth_audit_events` 写入；运行时存在 diagnostics 时同步 Identity 事件 | 已完成基线 |
| Rust 测试 | `cargo test --workspace` 全部通过 | 已完成 |
| Rust lint | `cargo clippy --workspace --all-targets` 通过，无 warning | 已完成 |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` 显示 `** BUILD SUCCEEDED **` | 已完成 |
| DesignSystem 测试 | `cd maohuoban/Packages/MaohuobanDesignSystem && xcodebuild -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO test` 显示 `** TEST SUCCEEDED **`，9 个 Swift Testing 用例通过 | 已完成 |
| HTTP E2E | `scripts/e2e/auth_login.sh` 输出 `auth e2e ok: audit_events=8` | 已完成 |
| 局域网 HTTP E2E | `BASE_URL=http://192.168.2.2:8080 scripts/e2e/auth_login.sh` 输出 `auth e2e ok: audit_events=8`，`lsof` 显示 `TCP *:8080 (LISTEN)` | 已完成 |
| iOS UI E2E | `MHB_BACKEND_BASE_URL=http://192.168.2.2:8080 xcodebuild test ... -only-testing:maohuobanUITests/MaohuobanAuthUITests/testAuthFlowFromPhoneCodeToPasswordRecovery` 显示 `** TEST SUCCEEDED **` | 已完成 |
| UI Test AppIntents 配置 | `maohuobanUITests` target 已链接 `AppIntents.framework`；最新 UI E2E 日志显示 `Extracted no relevant App Intents symbols, skipping writing output`，无缺框架 warning | 已完成 |
| iOS 本地网络配置 | 构建产物 `Info.plist` 已验证 `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` 和 `NSLocalNetworkUsageDescription` | 已完成 |
| 模拟器运行 | `build_run_sim` 成功安装并运行 `com.jinyi.maohuoban`；截图路径 `/var/folders/tq/ystrxttj7yz5zwqyrb2n909r0000gn/T/screenshot_optimized_bd33e992-62c6-4ef4-a6e9-855e1300f7f6.jpg` | 已完成截图复核 |
| UI 层级读取 | `snapshot_ui` 仍受 Xcode beta 工具路径限制；已用 XCUITest 补齐自动点击 E2E 证据 | 已替代验证 |

## 5. 上下文恢复要点

| 主题 | 记录 |
|---|---|
| 登录模式 | 验证码登录、密码登录、忘记密码，第三方登录本期 TODO |
| Token | access token 15 分钟，refresh token 180 天滑动有效，refresh token 轮换 |
| 数据库 | 使用独立 `maohuoban` 库；旧表在 `fengjinyi` 默认库 |
| Redis | 本机可用，key 使用 `maohuoban:` 前缀 |
| 前端 | 以设计稿为准，后续从 `ContentView` 进入认证根视图 |
| UI 自动化 | 系统“保存密码？”Sheet 会挡住密码登录按钮，XCUITest 通过 `dismissPasswordSavePromptIfPresent` 关闭后等待按钮可命中 |
| Toast | 根视图统一挂载 `.mhbToast()`；ViewModel 通过 `MHBToastPresenter` 展示后端 message；duration 已生效 |
| 观测 | 使用现有 diagnostics SDK，必要时补充后端 auth/performance 事件封装 |

## 6. 后端 crates 结构

| Crate | 状态 | 关键文件 |
|---|---|---|
| `maohuoban-auth-domain` | 已完成基线 | `auth/model.rs`、`auth/error.rs` |
| `maohuoban-auth-application` | 已完成基线 | `auth/service.rs`、`auth/ports.rs`，包含 account recovery、logout、审计端口 |
| `maohuoban-auth-infrastructure` | 已完成基线 | `postgres/repository.rs`、`redis/otp_store.rs`、`security/token.rs`、`security/password.rs`，包含审计表和 diagnostics Identity 事件 |
| `maohuoban-auth-http` | 已完成基线 | `auth/router.rs` |
| `maohuoban_rust` | 已完成装配 | `src/lib.rs`、`src/main.rs`、`migrations/0001_auth_baseline.sql` |

## 7. 已验证命令

| 命令 | 结果 |
|---|---|
| `cargo test -p maohuoban_rust --test auth_contract` | 7 passed |
| `cargo test --workspace` | 全部通过 |
| `/Applications/Postgres.app/Contents/Versions/18/bin/psql -d maohuoban -c '\dt'` | 显示 `_sqlx_migrations` 和 5 张认证业务表 |
| `cargo clippy --workspace --all-targets` | 通过，无 warning |
| `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` | `** BUILD SUCCEEDED **` |
| `cd maohuoban/Packages/MaohuobanDesignSystem && xcodebuild -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO test` | 9 tests passed，`** TEST SUCCEEDED **` |
| `scripts/e2e/auth_login.sh` | `auth e2e ok: audit_events=8` |
| `BASE_URL=http://192.168.2.2:8080 scripts/e2e/auth_login.sh` | `auth e2e ok: audit_events=8` |
| `MHB_BACKEND_BASE_URL=http://192.168.2.2:8080 xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanUITests/MaohuobanAuthUITests/testAuthFlowFromPhoneCodeToPasswordRecovery` | `** TEST SUCCEEDED **`；`auth.password.login_success` 写入 `auth_audit_events` |
| `rg -n "warning: Metadata extraction skipped\|Extracted no relevant App Intents symbols\|TEST SUCCEEDED" /tmp/maohuoban-ui-e2e.log -S` | 无 `warning: Metadata extraction skipped`；存在 `Extracted no relevant App Intents symbols, skipping writing output` 和 `** TEST SUCCEEDED **` |
| `PlistBuddy -c 'Print :NSAppTransportSecurity' <Debug app Info.plist>` | `NSAllowsArbitraryLoads = true` |
| `build_run_sim` | App 已安装运行到 iPhone 17 Pro 模拟器 |
