# maohuoban-his-web

毛伙伴医院端 Web HIS 前端工程，用 mock 数据跑通医院账号登录、权限导航、今日工作台、宠物患者、接诊病历、收费、药房、健康档案发布和授权审计。

## 技术栈

| 层         | 选择                                |
| ---------- | ----------------------------------- |
| 构建       | Vite                                |
| 语言       | TypeScript                          |
| UI         | React + HeroUI v3 + Tailwind CSS v4 |
| 路由       | React Router                        |
| 服务端状态 | TanStack Query                      |
| Mock       | MSW                                 |
| 测试       | Vitest + Playwright                 |

## 运行

```bash
pnpm install
pnpm dev
```

默认地址：`http://127.0.0.1:5173/`

## 验证

```bash
pnpm format:check
pnpm typecheck
pnpm lint
pnpm test
pnpm build
pnpm test:e2e
```

## Mock 账号

| 账号                 | 角色 |
| -------------------- | ---- |
| `owner@mhb.test`     | 院长 |
| `doctor@mhb.test`    | 医生 |
| `frontdesk@mhb.test` | 前台 |
| `pharmacy@mhb.test`  | 药房 |
| `finance@mhb.test`   | 财务 |

任意密码均可进入 mock 登录流程。

## 交付文档

| 文档                                                        | 用途                                  |
| ----------------------------------------------------------- | ------------------------------------- |
| `docs/mock-api-contract.md`                                 | 前端 mock API contract 和后端接入边界 |
| `../docs/engineering/web-his/01_Web_HIS前端Goal进度追踪.md` | 7 个阶段完成记录和验证结果            |
