# maohuoban-his-web

毛伙伴医院端 Web HIS 前端工程，连接 Rust 后端和开发库真实 HIS 数据，跑通医院员工登录、合作医院上下文、预约队列、宠物患者和后续接诊病历回流入口。

## 技术栈

| 层         | 选择                                |
| ---------- | ----------------------------------- |
| 构建       | Vite                                |
| 语言       | TypeScript                          |
| UI         | React + HeroUI v3 + Tailwind CSS v4 |
| 路由       | React Router                        |
| 服务端状态 | TanStack Query                      |
| 测试       | Vitest + Playwright                 |

## 运行

```bash
pnpm install
pnpm dev
```

默认地址：`http://127.0.0.1:5173/`

默认后端：通过 Vite `/api` 同源代理连接 `http://127.0.0.1:8080`

可通过环境变量覆盖：

```bash
VITE_API_BASE_URL=http://127.0.0.1:8080 pnpm dev
```

## 验证

```bash
pnpm format:check
pnpm typecheck
pnpm lint
pnpm test
pnpm build
pnpm test:e2e
```

## 开发库验证账号

| 手机号        | 密码           | 角色 |
| ------------- | -------------- | ---- |
| `13900000001` | `Maohuoban@123` | 医生 |

## 交付文档

| 文档                                                        | 用途                                  |
| ----------------------------------------------------------- | ------------------------------------- |
| `../docs/engineering/web-his/01_Web_HIS前端Goal进度追踪.md` | 7 个阶段完成记录和验证结果            |
