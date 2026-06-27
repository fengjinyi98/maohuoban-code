# Maohuoban Rust 后端

`maohuoban-rust` 是毛伙伴产品后端入口，当前承载认证系统与法务文档服务。工程采用 Rust workspace + 分层 crate，根 crate 只负责配置、迁移、依赖装配、路由聚合和运行时启动。

## 技术基线

| 项 | 规则 |
|---|---|
| Rust | `1.96` stable，根 `Cargo.toml` 的 `rust-version` 是 workspace MSRV 来源 |
| Edition | Rust 2024 edition，新 crate 使用 `edition.workspace = true` |
| 依赖解析 | Cargo resolver 3，新增 crate 使用 `rust-version.workspace = true` |
| 推荐 API | 测试断言优先用 `std::{assert_matches, debug_assert_matches}`；全局惰性状态优先评估 `LazyLock` / `OnceLock` 的职责差异 |

## 当前能力

| 领域 | 能力 | 存储/依赖 |
|---|---|---|
| Auth | 手机验证码登录、密码登录、token refresh、退出登录、账号恢复、第三方登录占位 | PostgreSQL、Redis、Argon2、JWT |
| Legal | 用户服务协议、用户隐私政策的后端托管 HTML 文档读取 | PostgreSQL `legal_documents` |
| Diagnostics | 启动生命周期事件、敏感字段脱敏、分段诊断输出 | `maohuoban-diagnostics-sdk/` |

## Workspace 结构

| 路径 | 职责 |
|---|---|
| `src/main.rs` | 启动诊断 SDK，读取环境配置，监听 HTTP 服务 |
| `src/lib.rs` | 装配 PostgreSQL、Redis、迁移、Auth 服务、Legal 服务和 Axum Router |
| `crates/maohuoban-auth-domain` | 用户身份、设备会话、认证错误等领域模型 |
| `crates/maohuoban-auth-application` | 认证用例编排与端口 trait |
| `crates/maohuoban-auth-infrastructure` | PostgreSQL 仓储、Redis 验证码存储、Argon2、JWT |
| `crates/maohuoban-auth-http` | `/api/v1/auth/*` 与账号恢复 HTTP DTO/响应映射 |
| `crates/maohuoban-legal-domain` | 法务文档类型与后端托管文档模型 |
| `crates/maohuoban-legal-application` | 已发布法务文档读取用例 |
| `crates/maohuoban-legal-infrastructure` | `legal_documents` PostgreSQL 仓储 |
| `crates/maohuoban-legal-http` | `/api/v1/legal-documents/{kind}` HTTP DTO/响应映射 |
| `migrations/` | Auth baseline 与 Legal document 建表/内容迁移 |
| `tests/` | Auth、Legal HTTP 契约测试 |

## 接口概览

| 方法 | 路径 | 用途 |
|---|---|---|
| `POST` | `/api/v1/auth/phone/code` | 发送手机号验证码 challenge |
| `POST` | `/api/v1/auth/phone/verify` | 验证手机号验证码并创建会话 |
| `POST` | `/api/v1/auth/password/login` | 密码登录 |
| `POST` | `/api/v1/auth/refresh` | 使用 refresh token 换新会话 |
| `POST` | `/api/v1/auth/logout` | 注销设备会话 |
| `POST` | `/api/v1/auth/oauth/{provider}` | 第三方登录占位 |
| `POST` | `/api/v1/account-recovery/code` | 发送账号恢复验证码 |
| `POST` | `/api/v1/account-recovery/reset-password` | 重置密码 |
| `GET` | `/api/v1/legal-documents/{kind}` | 读取 `user_agreement` 或 `privacy_policy` |

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `SERVER_BIND_ADDR` | `0.0.0.0:8080` | HTTP 监听地址 |
| `DATABASE_URL` | `postgres://fengjinyi@localhost/maohuoban` | 运行环境 PostgreSQL |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | 运行环境 Redis |
| `REDIS_KEY_PREFIX` | `maohuoban:auth` | 验证码等 Redis key 前缀 |
| `JWT_SECRET` | 本地开发默认密钥 | JWT 签名密钥，生产环境必须覆盖 |
| `TEST_DATABASE_URL` | `postgres://fengjinyi@localhost/maohuoban_test` | 契约测试数据库，必须与开发库隔离 |
| `TEST_REDIS_URL` | `redis://127.0.0.1:6379/15` | 契约测试 Redis DB |

## 本地运行

```bash
cd /Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust
cargo run
```

服务启动时会自动执行 `migrations/`，并在 `target/maohuoban-diagnostics/segments` 写入诊断片段。

## 验证命令

| 场景 | 命令 |
|---|---|
| 格式 | `cargo fmt --all --check` |
| 编译 | `cargo check --workspace --all-targets` |
| 全量测试 | `cargo test --workspace` |
| lint | `cargo clippy --workspace --all-targets` |
| Auth 契约 | `cargo test --test auth_contract` |
| Legal 契约 | `cargo test --test legal_contract` |

## 架构约束

| 层 | 约束 |
|---|---|
| HTTP | 只处理协议、DTO、状态码和响应映射 |
| Application | 编排用例、事务意图和端口 trait |
| Domain | 只放业务模型、业务规则和领域错误 |
| Infrastructure | 实现 PostgreSQL、Redis、安全和外部适配 |
| Root crate | 只做配置读取、迁移、依赖装配、路由聚合和启动 |

跨业务域调用必须通过 application 端口或共享模型，新增宠物档案、宠物事件、同城交易、医疗记录、保险协同时继续按 `*-domain`、`*-application`、`*-infrastructure`、`*-http` 拆分。
