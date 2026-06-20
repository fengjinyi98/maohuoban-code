# Web HIS 前端 Goal 进度追踪

| Phase | 状态 | 完成内容 | 验证命令 | 结果 | Commit | 下一入口 | 风险 |
|---|---|---|---|---|---|---|---|
| Phase 0 | 已验收 | 创建 `maohuoban-his-web/`，配置 Vite、React、TS、HeroUI v3、Tailwind v4、MSW、Vitest、Playwright、基础布局和 MVVM 目录 | `pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build` | 通过 | 待提交 | Phase 1 权限壳 | HeroUI 深层组件行为以后续产品化继续收敛 |
| Phase 1 | 已验收 | mock 登录、租户/院区/角色选择、权限导航、403、刷新恢复、退出登录 | `pnpm test:e2e` | 通过：登录、刷新恢复、退出登录 | 待提交 | Phase 2 工作台 | 真实 token 后续由后端接入 |
| Phase 2 | 已验收 | 今日概览、角色待办、时间线队列、风险提醒、模块跳转 | 浏览器 1440/1280/1024 截图 | 通过：无空白页，导航和工作台可见 | 待提交 | Phase 3 患者 | 队列数据为 session 内 mock |
| Phase 3 | 已验收 | 患者列表、搜索、详情、新建患者、风险标签、历史就诊跳转 | 浏览器 1440/1280/1024 截图 | 通过：患者页可打开，表格横向滚动可用 | 待提交 | Phase 4 接诊 | 患者 fixture 数量低于最终演示数据量 |
| Phase 4 | 已验收 | 接诊队列、病历编辑、体征、诊断、处方、剂量提示、保存后生成待收费 | `pnpm test:e2e` | 通过：开始接诊 -> 保存病历 -> 生成收费 | 待提交 | Phase 5 收费药房 | 报告上传为 mock 文案 |
| Phase 5 | 已验收 | 收费、收据预览、退款原因、支付后待发药、确认发药和库存扣减 | `pnpm test:e2e` | 通过：收费 -> 待发药 -> 发药完成 | 待提交 | Phase 6 发布审计 | 打印外设暂未接入 |
| Phase 6 | 已验收 | 健康档案待发布、App 预览、敏感隔离、授权记录、审计筛选 | `pnpm test:e2e` | 通过：发布健康档案 -> 院长查看审计 | 待提交 | Phase 7 contract | 真实 App 回流暂未接入 |
| Phase 7 | 已验收 | mock API contract、错误码、OpenAPI 替换边界、进度追踪文档 | `pnpm format:check`、`pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`、`pnpm test:e2e` | 全部通过 | 待提交 | 后端 Rust contract 评审 | Rust 后端实现和数据库迁移仍在目标期外 |

## 浏览器验证记录

已执行：

| 视口 | 页面 | 截图 |
|---|---|---|
| 1440x900 | 今日工作台、宠物患者 | `output/playwright/his-dashboard-1440x900.png`、`output/playwright/his-patients-1440x900.png` |
| 1280x800 | 今日工作台、宠物患者 | `output/playwright/his-dashboard-1280x800.png`、`output/playwright/his-patients-1280x800.png` |
| 1024x768 | 今日工作台、宠物患者 | `output/playwright/his-dashboard-1024x768.png`、`output/playwright/his-patients-1024x768.png` |

1024 宽度曾发现退出登录区域覆盖工作台标题，已改为侧栏 flex 布局并复测通过。

## 当前验证结果

| 命令 | 结果 |
|---|---|
| `cd maohuoban-his-web && pnpm format:check` | 通过 |
| `cd maohuoban-his-web && pnpm typecheck` | 通过 |
| `cd maohuoban-his-web && pnpm lint` | 通过 |
| `cd maohuoban-his-web && pnpm test` | 3 files / 6 tests 通过 |
| `cd maohuoban-his-web && pnpm build` | 通过 |
| `cd maohuoban-his-web && pnpm test:e2e` | 2 tests 通过 |
