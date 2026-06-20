# Web HIS 前端从 0 启动目标文档

- 文档版本：v0.1
- 更新时间：2026-06-21
- Goal：从 0 建立毛伙伴医院端 Web HIS 前端工程，在后端暂不改动的前提下，通过 mock 数据完成医院账号登录、角色权限、今日工作台、宠物患者、接诊病历、处方收费、药房库存、健康档案发布和审计授权等核心界面闭环。
- 执行方式：前端独立启动；第一阶段使用 mock 数据和 MSW；后端 Rust 方向保持不变，本目标期不改后端接口和数据库。
- 关联产品文档：
  - `docs/product/strategy/02_宠物HIS系统与数据信任架构.md`
  - `docs/product/prd/00_V1_PRD_产品总纲与核心流程.md`
- 关联组件库：HeroUI v3 React
- 关联约束：`AGENTS.md`

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 医院端形态 | 第一版采用 Web HIS，医院员工通过浏览器访问 |
| 前端语言 | TypeScript |
| 前端框架 | React |
| 构建工具 | Vite |
| UI 组件 | HeroUI v3 React |
| 样式底座 | Tailwind CSS v4 + `@heroui/styles` |
| 前端架构 | MVVM 目录结构 + 单向数据流 |
| Mock 方式 | 本地 fixture + MSW 拦截 API |
| 后端 | 继续使用 Rust，后端本阶段不动 |
| API 类型 | 先定义前端 mock contract，后续由 Rust OpenAPI 生成 TypeScript client |
| 数据安全边界 | 前端只做体验和可见性控制，租户、权限、审计最终必须由后端强制执行 |

推荐技术栈：

```text
maohuoban-web
  -> TypeScript
  -> React
  -> Vite
  -> React Router
  -> TanStack Query
  -> Tailwind CSS v4
  -> HeroUI v3 React
  -> MSW
  -> Vitest
  -> Playwright
```

---

## 2. 目标边界

## 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| Web 工程骨架 | 新建独立 `maohuoban-web/`，具备开发、构建、测试、类型检查和 lint 命令 |
| 登录壳 | mock 医院员工账号登录，支持选择医院租户、院区和角色 |
| 权限壳 | 根据角色控制导航、按钮、页面入口和危险操作展示 |
| 主导航 | 建立医院工作台、患者、接诊、收费、药房、健康档案、授权审计、设置等一级模块 |
| Mock 数据 | 使用稳定 fixture 覆盖医院、员工、宠物患者、预约、就诊、处方、收费、库存、报告和审计 |
| 核心流程 | 用 mock 跑通“预约到院 -> 接诊 -> 开处方 -> 收费 -> 发药 -> 发布健康档案” |
| 验收体系 | 每个阶段都有可运行命令、页面验收和交互验收 |

## 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| Rust 后端接口实现 | 当前阶段先验证医院 Web HIS 信息架构和交互闭环 |
| 数据库迁移 | 后端模型需要在前端流程确认后再固化 |
| 真实登录和 token | 先使用 mock session，避免被认证链路阻塞 |
| 真实跨院授权 | 先做授权界面和数据结构 mock |
| 真实 App 回流 | 先做健康档案发布审核界面和 mock 状态 |
| 外设对接 | 打印机、扫码枪、钱箱、检验仪器后续通过本地助手或院内网关接入 |
| 私有化部署 | 先按标准 SaaS 前端形态验证 |

---

## 3. 产品定位

Web HIS 是医院员工使用的业务工作台，不是面向宠物主的营销页。

首页和导航要服务高频医疗工作：

| 角色 | 高频任务 |
|---|---|
| 院长/管理员 | 看今日经营、员工权限、审计、数据导出、设置 |
| 医生 | 查看待接诊、写病历、开处方、发布健康档案 |
| 助理/护士 | 录入体征、执行医嘱、上传报告、协助接诊 |
| 前台 | 建档、预约、到院登记、收费、打印 |
| 药房 | 查看待发药处方、发药、退药、库存预警 |
| 财务 | 收款、退款、对账、费用报表 |

界面原则：

| 原则 | 要求 |
|---|---|
| 工作台优先 | 首屏展示待办、队列、风险提醒和快捷操作 |
| 信息密度适中 | 医院场景需要扫描效率，避免营销式大图和装饰性布局 |
| 权限清晰 | 员工看到自己能处理的任务和入口 |
| 医疗安全优先 | 过敏、当前用药、未收费、未发药、未发布等状态必须醒目 |
| 审计意识内置 | 发布、导出、退款、权限变更等危险操作有原因、确认和记录 |

---

## 4. 技术选型

## 4.1 前端语言和框架

| 技术 | 选择 | 说明 |
|---|---|---|
| 语言 | TypeScript | HIS 表单和数据模型复杂，必须使用静态类型 |
| 框架 | React | 复杂后台生态成熟，适合表格、表单、权限和状态组合 |
| 构建 | Vite | 登录后后台系统不需要 SSR，Vite 简洁高效 |
| 路由 | React Router | 适合权限路由、嵌套路由和工作台模块 |
| 服务端状态 | TanStack Query | 接口请求、缓存、刷新、错误状态统一 |
| 前端架构 | MVVM + 单向数据流 | View 只渲染和转发事件，ViewModel 承接状态派生和命令入口 |
| 样式 | Tailwind CSS v4 | HeroUI v3 强依赖 Tailwind v4 |
| 组件库 | HeroUI v3 React | 基于 React Aria Components，适合可访问性和主题定制 |
| 表单 | HeroUI Form / TextField / Select + 业务封装 | 起步统一，后续抽通用医疗表单组件 |
| 表格 | HeroUI Table + 业务封装 | 患者、预约、库存、审计列表高频使用 |
| Mock | MSW | 浏览器内模拟真实 HTTP，后续切后端成本低 |
| 单元测试 | Vitest + Testing Library | 组件、权限、数据 mapper 和交互逻辑 |
| E2E | Playwright | 登录、接诊、收费、发药等流程验收 |

## 4.2 HeroUI v3 落地规范

HeroUI v3 是本 Web HIS 的默认组件库。实现前需要遵循以下约束：

| 约束 | 要求 |
|---|---|
| 版本 | 只使用 HeroUI v3 模式 |
| 依赖 | 安装 `@heroui/react`、`@heroui/styles`、`tailwind-variants`、`tailwindcss`、`@tailwindcss/postcss`、`postcss` |
| Provider | v3 无需 `HeroUIProvider` |
| 样式导入 | `globals.css` 先 `@import "tailwindcss";`，再 `@import "@heroui/styles";` |
| 组件写法 | 使用复合组件模式，例如 `Card.Header`、`Card.Content`、`Card.Footer` |
| 交互事件 | HeroUI 组件优先使用 `onPress` |
| 语义变体 | 使用 `primary`、`secondary`、`tertiary`、`outline`、`ghost`、`danger` 等语义变体 |
| 主题 | 使用 CSS variables 和 oklch 色彩变量，沉淀毛伙伴 Web token |
| 文档 | 开发新组件前通过 `heroui-react` skill 查询对应组件文档 |

安装命令建议：

```bash
pnpm add @heroui/react @heroui/styles tailwind-variants
pnpm add -D tailwindcss @tailwindcss/postcss postcss
```

CSS 入口要求：

```css
@import "tailwindcss";
@import "@heroui/styles";
```

核心组件映射：

| HIS 场景 | HeroUI 组件 |
|---|---|
| 主按钮、危险操作、图标按钮 | `Button`、`ButtonGroup`、`Tooltip` |
| 今日概览和风险提醒 | `Card`、`Alert`、`Chip`、`Badge` |
| 表单录入 | `Form`、`TextField`、`TextArea`、`Select`、`DatePicker`、`NumberField` |
| 队列和列表 | `Table`、`Pagination`、`Tabs`、`SearchField` |
| 弹窗和抽屉 | `Modal`、`Drawer`、`AlertDialog` |
| 状态反馈 | `Toast`、`Spinner`、`Skeleton`、`ProgressBar` |
| 权限和设置 | `Switch`、`Checkbox`、`RadioGroup`、`Accordion` |

业务层需要封装以下组件，避免页面直接堆叠基础组件：

| 业务组件 | 用途 |
|---|---|
| `HisPageShell` | 统一后台页面标题、操作区和内容区 |
| `HisStatusChip` | 就诊、收费、发药、发布、授权状态 |
| `HisDataTable` | 表格筛选、空态、加载、分页、行操作 |
| `HisFormSection` | 病历表单分组和保存状态 |
| `HisRiskAlert` | 过敏、当前用药、低库存、近效期风险 |
| `HisConfirmDialog` | 退款、导出、发布、权限变更等危险操作确认 |

## 4.3 后端方向

后端继续使用 Rust，但本目标期只在前端定义 mock contract。

| 层 | 方向 |
|---|---|
| 后端框架 | Rust + axum |
| 数据库 | PostgreSQL |
| 缓存 | Redis |
| 文件存储 | RustFS/S3 兼容对象存储 |
| API 契约 | REST + OpenAPI |
| 前端 client | 后续由 OpenAPI 生成 TypeScript client |

前端 mock contract 应尽量贴近未来后端边界：

```text
hospital tenant
  -> site
  -> member
  -> role/permission
  -> patient
  -> encounter
  -> prescription
  -> invoice
  -> inventory
  -> health record publication
  -> consent/audit
```

## 4.4 包管理和命令

推荐使用 `pnpm`。

目标命令：

| 命令 | 用途 |
|---|---|
| `pnpm dev` | 启动本地 Web HIS |
| `pnpm build` | 生产构建 |
| `pnpm typecheck` | TypeScript 类型检查 |
| `pnpm lint` | ESLint |
| `pnpm test` | Vitest |
| `pnpm test:e2e` | Playwright E2E |
| `pnpm format:check` | 格式检查 |

---

## 5. 目录规划

Web 工程建议放在仓库根目录：

```text
maohuoban-web/
  package.json
  vite.config.ts
  tsconfig.json
  postcss.config.mjs
  playwright.config.ts
  src/
    globals.css
    app/
      App.tsx
      router.tsx
      providers/
      layouts/
    shared/
      api/
      auth/
      components/
      design-system/
      mocks/
      permissions/
      utils/
    features/
      auth/
      dashboard/
      patients/
      encounters/
      billing/
      pharmacy/
      health-records/
      audit/
      settings/
    test/
      fixtures/
      helpers/
  e2e/
```

目录职责：

| 目录 | 职责 |
|---|---|
| `app` | 应用入口、路由、布局、全局 provider |
| `shared/api` | HTTP client、mock contract、后续 OpenAPI client 适配 |
| `shared/auth` | mock session、当前医院、当前角色 |
| `shared/components` | 跨 feature 复用组件 |
| `shared/design-system` | Web 端 token、布局、状态色、业务组件封装 |
| `shared/mocks` | MSW handlers、fixture、mock seed |
| `shared/permissions` | 前端权限声明和 route guard |
| `features/auth` | 登录、选择租户、选择院区、选择角色 |
| `features/dashboard` | 今日工作台 |
| `features/patients` | 宠物患者和主人档案 |
| `features/encounters` | 接诊、病历、医嘱、处方、报告 |
| `features/billing` | 收费、退款、账单 |
| `features/pharmacy` | 发药、退药、库存 |
| `features/health-records` | 健康档案发布、App 回流审核 |
| `features/audit` | 授权、访问日志、导出日志、审计 |
| `features/settings` | 员工、角色、院区、项目、药品、模板 |

## 5.1 Feature 内部 MVVM 结构

每个业务 Feature 必须保持同一套 MVVM 目录结构，便于扩展、测试和后端接入。

```text
features/patients/
  domain/
    models.ts
    permissions.ts
  data/
    patientRepository.ts
    patientMappers.ts
    patientApi.ts
  view-models/
    usePatientListViewModel.ts
    usePatientDetailViewModel.ts
  presentation/
    PatientListPage.tsx
    PatientDetailPage.tsx
    components/
  routes.tsx
```

| 层 | 职责 | 禁止事项 |
|---|---|---|
| `domain` | 业务模型、枚举、权限语义、纯派生规则 | 不依赖 React、HTTP、MSW、浏览器 API |
| `data` | API client 适配、DTO mapper、Repository | 不写页面状态和 UI 文案编排 |
| `view-models` | 页面状态派生、表单草稿、命令式操作入口 | 不直接渲染 JSX，不直接读取 fixture |
| `presentation` | 页面和组件渲染、转发用户事件 | 不直接调用 fetch，不直接 import MSW fixture |
| `routes.tsx` | Feature 内路由和权限 guard 组合 | 不承载业务状态 |

命名规则：

| 类型 | 命名 |
|---|---|
| 页面 | `XxxPage.tsx` |
| 业务组件 | `XxxSection.tsx`、`XxxPanel.tsx`、`XxxTable.tsx` |
| ViewModel hook | `useXxxViewModel.ts` |
| Repository | `xxxRepository.ts` |
| Mapper | `xxxMappers.ts` |
| 模型 | `models.ts` 或按对象拆分 |

## 5.2 单向数据流

Web HIS 前端数据流必须保持单一模式：

```text
用户操作
  -> presentation 转发事件
  -> view-models 执行命令/更新本地草稿
  -> data repository 调用 API client
  -> MSW mock 或未来 Rust API 返回 DTO
  -> data mapper 转换为 domain model
  -> view-models 派生页面状态
  -> presentation 重新渲染
```

数据流约束：

| 约束 | 要求 |
|---|---|
| View 只渲染 | 页面组件只读取 ViewModel 输出并转发事件 |
| 命令入口集中 | 保存、发布、收费、发药、退款等操作进入 ViewModel |
| API 集中 | 所有 HTTP 调用经过 `shared/api` 和 Feature `data` 层 |
| Mock 隔离 | MSW 和 fixture 只存在于 `shared/mocks` 与测试目录 |
| 状态归属清晰 | 远端状态交给 TanStack Query，本地表单草稿交给 ViewModel |
| 纯函数可测试 | mapper、权限判断、状态派生保持纯函数 |
| 跨模块通信克制 | Feature 之间通过稳定 domain model、route params 或 shared service 交互 |

验收标准：

| 项 | 标准 |
|---|---|
| 目录一致 | 每个 Feature 都有 `domain/data/view-models/presentation` |
| 无反向依赖 | `domain` 不依赖上层，`presentation` 不被 `data` 引用 |
| 无页面直连 API | `presentation` 中没有 `fetch`、API client 或 MSW fixture import |
| ViewModel 可测 | 关键 ViewModel 有单元测试覆盖加载、提交、失败、权限禁用 |
| Mapper 可测 | DTO 到 domain model 的转换有测试覆盖 |
| 状态可追踪 | 关键流程的状态迁移能在测试或 E2E 中验证 |

---

## 6. Mock 策略

## 6.1 Mock 原则

| 原则 | 说明 |
|---|---|
| mock 走 HTTP | 页面通过同一套 API client 调用，MSW 拦截请求 |
| fixture 稳定 | 测试和演示使用固定数据，避免随机数据导致验收不稳定 |
| 状态可变 | 接诊、收费、发药、发布等流程允许在浏览器会话内改变状态 |
| 数据贴近真实 | 字段名和未来 Rust DTO 保持语义一致 |
| 权限真实模拟 | 不同角色登录后看到不同入口和动作 |
| 不把 mock 写散 | 所有 mock 数据集中在 `shared/mocks` 和 `test/fixtures` |

## 6.2 Mock 数据集

第一版至少准备以下 mock 数据：

| 数据 | 数量 | 说明 |
|---|---:|---|
| 医院租户 | 2 | 单店医院、连锁医院 |
| 院区 | 3 | 总院、分院、门诊点 |
| 员工 | 8 | 院长、医生、助理、前台、药房、财务 |
| 宠物患者 | 20 | 猫、狗，覆盖幼年、成年、老年 |
| 主人 | 15 | 单宠、多宠、家庭共管 |
| 今日预约 | 12 | 待到院、待接诊、接诊中、待收费、待发药、已完成 |
| 就诊记录 | 30 | 普通门诊、疫苗、急诊、慢病复诊 |
| 处方 | 12 | 待收费、待发药、已发药、部分退药 |
| 检验报告 | 10 | 血常规、生化、PCR、粪检 |
| 影像报告 | 6 | X 光、B 超 |
| 收费单 | 12 | 未支付、已支付、退款中、已退款 |
| 药品库存 | 30 | 正常、低库存、近效期、停用 |
| 健康档案发布 | 10 | 待发布、已发布、延迟发布、不发布 |
| 审计日志 | 50 | 查看、编辑、导出、授权、发布、退款 |

## 6.3 Mock API 分组

| API 组 | 示例路径 | 用途 |
|---|---|---|
| Auth | `/api/mock/auth/login` | mock 登录和当前 session |
| Tenant | `/api/mock/hospitals/current` | 当前医院、院区、角色 |
| Dashboard | `/api/mock/his/dashboard/today` | 今日工作台 |
| Patients | `/api/mock/his/patients` | 宠物患者列表和详情 |
| Encounters | `/api/mock/his/encounters` | 接诊、病历、医嘱 |
| Billing | `/api/mock/his/invoices` | 收费和退款 |
| Pharmacy | `/api/mock/his/pharmacy` | 发药和库存 |
| Health Records | `/api/mock/his/health-record-publications` | 发布版健康档案 |
| Audit | `/api/mock/his/audit-logs` | 审计和授权日志 |
| Settings | `/api/mock/his/settings` | 员工、角色、项目、药品、模板 |

后续接真实后端时，`/api/mock` 前缀移除，API client 替换为 OpenAPI 生成 client。

---

## 7. 信息架构

## 7.1 一级导航

| 导航 | 核心页面 | 主要角色 |
|---|---|---|
| 今日工作台 | 今日预约、待接诊、待收费、待发药、异常提醒 | 全员 |
| 宠物患者 | 患者列表、患者详情、主人信息、历史就诊 | 医生、前台、助理 |
| 接诊病历 | 接诊队列、病历编辑、医嘱、处方、报告 | 医生、助理 |
| 收费 | 待收费、账单详情、支付、退款 | 前台、财务 |
| 药房库存 | 待发药、发药详情、库存、批号、预警 | 药房、院长 |
| 健康档案 | 待发布、已发布、延迟发布、不发布 | 医生、院长 |
| 授权审计 | 跨院授权、App 授权、访问日志、导出日志 | 院长、管理员 |
| 设置 | 员工、角色、院区、项目、药品、病历模板 | 院长、管理员 |

## 7.2 工作台状态

今日工作台必须覆盖医院高频队列：

| 队列 | 状态 |
|---|---|
| 预约队列 | 待到院、已到院、爽约、取消 |
| 接诊队列 | 待接诊、接诊中、待补报告、待归档 |
| 收费队列 | 待收费、已收费、退款中 |
| 药房队列 | 待发药、部分发药、已发药、退药 |
| 健康档案队列 | 待发布、已发布、延迟发布、不发布 |
| 风险提醒 | 过敏、低库存、近效期、未收费发药、超时待接诊 |

---

## 8. 核心页面目标

## 8.1 登录和租户选择

| 页面 | 目标 |
|---|---|
| 登录页 | 输入手机号/邮箱和密码，mock 返回员工身份 |
| 租户选择 | 员工属于多家医院时选择医院 |
| 院区选择 | 连锁医院选择当前院区 |
| 角色切换 | 开发 mock 阶段可快速切换院长、医生、前台、药房等角色 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 登录成功 | 进入今日工作台 |
| 权限生效 | 不同角色看到不同导航和按钮 |
| session 恢复 | 刷新页面后保留 mock 登录态 |
| 退出登录 | 清除 mock session 并回到登录页 |

## 8.2 今日工作台

| 模块 | 内容 |
|---|---|
| 今日概览 | 预约数、待接诊、待收费、待发药、待发布 |
| 时间线队列 | 按时间展示预约和就诊进度 |
| 角色待办 | 医生看待接诊，前台看待收费，药房看待发药 |
| 风险提醒 | 过敏、低库存、近效期、超时等待 |
| 快捷动作 | 新建患者、登记到院、开始接诊、收费、发药 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 数据展示 | mock 队列按状态准确分组 |
| 角色过滤 | 医生、前台、药房待办不同 |
| 快捷跳转 | 点击队列项进入对应详情页 |
| 响应式 | 1440px 桌面可高效操作，1024px 平板宽度不遮挡 |

## 8.3 宠物患者

| 页面 | 内容 |
|---|---|
| 患者列表 | 宠物名、物种、品种、年龄、主人、最近就诊、风险标签 |
| 患者详情 | 基础信息、主人信息、健康概览、历史就诊、报告、用药 |
| 新建患者 | 宠物基础信息、主人信息、来源、备注 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 搜索筛选 | 支持按宠物名、主人手机号、病历号、品种筛选 |
| 风险信息 | 过敏、慢病、当前用药在详情页明显展示 |
| 新建患者 | mock 提交后患者进入列表 |
| 历史就诊 | 可以从患者详情跳转到就诊详情 |

## 8.4 接诊病历

| 模块 | 内容 |
|---|---|
| 接诊头部 | 宠物、主人、过敏、体重、当前状态 |
| 主诉和体征 | 主诉、体温、体重、精神、食欲、排泄 |
| 诊断 | 初步诊断、诊断标签、严重程度 |
| 医嘱 | 检查、检验、治疗、护理 |
| 处方 | 药品、剂量、频次、途径、天数 |
| 报告 | 上传检验/影像报告 mock |
| 归档 | 病历完成、待补充、延迟归档 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 表单可用 | 医生能填写主诉、体征、诊断、处方 |
| 剂量提示 | 处方区显示按体重计算的 mock 提示 |
| 状态推进 | 保存病历后就诊状态从接诊中变为待收费或待发药 |
| 权限限制 | 前台不能编辑医生病历 |
| 离开保护 | 表单有未保存内容时提示确认 |

## 8.5 收费

| 模块 | 内容 |
|---|---|
| 待收费列表 | 就诊、主人、金额、处方、检查项目 |
| 收费详情 | 项目、药品、折扣、应收、实收、支付方式 |
| 收据预览 | 生成可打印 mock 单据 |
| 退款 | 选择项目、填写原因、权限确认 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 账单计算 | 项目和药品金额汇总正确 |
| 支付状态 | mock 收费后状态变为已支付 |
| 流程联动 | 已支付后药房出现待发药任务 |
| 退款审计 | 退款必须填写原因并生成审计记录 |

## 8.6 药房库存

| 模块 | 内容 |
|---|---|
| 待发药 | 已收费处方、宠物、药品清单 |
| 发药详情 | 药品、批号、数量、用法、注意事项 |
| 库存列表 | 药品名、规格、库存、批号、效期、预警 |
| 库存预警 | 低库存、近效期、停用药品 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 发药流程 | 药房能完成 mock 发药 |
| 批号选择 | 发药时选择批号并扣减 mock 库存 |
| 低库存提示 | 库存低于阈值时出现预警 |
| 权限限制 | 非药房/管理员不能确认发药 |

## 8.7 健康档案发布

| 模块 | 内容 |
|---|---|
| 待发布列表 | 就诊摘要、报告、用药摘要、复诊建议 |
| 发布审核 | 选择发布内容、隐藏内部备注、预览 App 展示 |
| 发布状态 | 已发布、延迟发布、不发布 |
| 发布历史 | 版本、发布时间、发布人、撤回记录 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 发布预览 | 能看到宠物主 App 将展示的摘要 |
| 敏感隔离 | 内部备注、成本、利润、方案模板不出现在预览 |
| 状态变更 | mock 发布后状态进入已发布 |
| 审计记录 | 发布、撤回、延迟发布都进入审计日志 |

## 8.8 授权审计

| 模块 | 内容 |
|---|---|
| 跨院授权 | 宠物主授权给其他医院的记录 |
| App 授权 | 家庭成员、保险方授权记录 |
| 访问日志 | 谁在什么时间看了哪只宠物、哪份病历 |
| 导出日志 | 导出范围、申请人、原因、时间 |
| 工单访问 | 平台排障工单授权 mock |

验收标准：

| 验收项 | 标准 |
|---|---|
| 审计可查 | 可按员工、宠物、动作、时间筛选 |
| 敏感动作 | 导出、发布、退款、权限变更有醒目标识 |
| 授权详情 | 可查看授权对象、范围、用途、有效期 |
| 平台工单 | 展示平台访问需要医院授权的 mock 流程 |

## 8.9 设置

| 模块 | 内容 |
|---|---|
| 员工管理 | 邀请、启用、停用、重置密码、角色分配 |
| 角色权限 | 医生、助理、前台、药房、财务、院长 |
| 院区管理 | 院区资料、营业时间、默认工作区 |
| 项目配置 | 检查、治疗、服务项目 |
| 药品配置 | 药品、规格、单位、库存阈值 |
| 病历模板 | 常用主诉、诊断、处方模板 |

验收标准：

| 验收项 | 标准 |
|---|---|
| 员工独立账号 | 每个员工有独立 mock 账号 |
| 院长授权 | 只有院长/管理员能调整角色权限 |
| 停用生效 | 停用员工后该账号无法 mock 登录 |
| 权限审计 | 权限变更进入审计日志 |

---

## 9. 权限模型

前端权限用于体验控制，后端接入后必须由 Rust 后端再次校验。

| 权限 | 院长 | 医生 | 助理 | 前台 | 药房 | 财务 |
|---|---:|---:|---:|---:|---:|---:|
| 查看工作台 | 是 | 是 | 是 | 是 | 是 | 是 |
| 新建患者 | 是 | 是 | 是 | 是 | 否 | 否 |
| 编辑病历 | 是 | 是 | 辅助 | 否 | 否 | 否 |
| 开处方 | 是 | 是 | 否 | 否 | 否 | 否 |
| 收费 | 是 | 否 | 否 | 是 | 否 | 是 |
| 退款 | 是 | 否 | 否 | 受限 | 否 | 是 |
| 发药 | 是 | 否 | 否 | 否 | 是 | 否 |
| 库存管理 | 是 | 否 | 否 | 否 | 是 | 否 |
| 发布健康档案 | 是 | 是 | 否 | 否 | 否 | 否 |
| 查看审计 | 是 | 否 | 否 | 否 | 否 | 受限 |
| 员工管理 | 是 | 否 | 否 | 否 | 否 | 否 |

---

## 10. 数据模型草案

前端 mock 阶段先定义以下 TypeScript 模型，后续与 Rust DTO 对齐。

| 模型 | 说明 |
|---|---|
| `HospitalTenant` | 医院或连锁租户 |
| `HospitalSite` | 院区、门店或诊疗点 |
| `HospitalMember` | 医院员工账号 |
| `Role` | 医院内岗位角色 |
| `Permission` | 具体操作权限 |
| `PetPatient` | 医院侧宠物患者 |
| `OwnerProfile` | 主人资料 |
| `Appointment` | 预约 |
| `VisitEncounter` | 一次就诊 |
| `MedicalRecordDraft` | 病历草稿 |
| `Diagnosis` | 诊断 |
| `MedicalOrder` | 医嘱 |
| `Prescription` | 处方 |
| `PrescriptionItem` | 处方明细 |
| `Invoice` | 收费单 |
| `PaymentRecord` | 支付记录 |
| `InventoryItem` | 药品或耗材 |
| `InventoryBatch` | 库存批号 |
| `LabReport` | 检验报告 |
| `ImagingReport` | 影像报告 |
| `HealthRecordPublication` | 发布到 App 的健康档案版本 |
| `ConsentGrant` | 用户授权记录 |
| `AuditLog` | 审计日志 |

---

## 11. 分阶段实施与验收

## 11.0 目标模式执行纪律

本目标文档用于长周期目标模式执行。每个阶段必须具备清晰边界、验收标准、提交节点和交接记录，避免上下文压缩或会话切换后遗漏关键信息。

执行原则：

| 原则 | 要求 |
|---|---|
| 单阶段聚焦 | 每次只推进当前 Phase 的目标范围 |
| 范围显式 | 开始前确认当前 Phase 的范围、暂缓事项和验收标准 |
| 验收先行 | 每个 Phase 完成前必须跑完该阶段要求的命令和浏览器验证 |
| 及时提交 | 每个 Phase 验收通过后及时创建 git commit |
| 交接可恢复 | 每个 Phase 结束后记录完成内容、验证结果、剩余风险和下一阶段入口 |
| 上下文可重建 | 新会话只需读取本目标文档、最近提交和进度记录即可继续 |

阶段执行模板：

```text
1. 读取目标文档和当前 Phase 边界
2. 确认本阶段范围和暂缓事项
3. 按 MVVM + 单向数据流实现
4. 运行本阶段验收命令
5. 浏览器验证关键页面和流程
6. 更新阶段进度记录
7. git status 确认变更范围
8. 提交当前 Phase commit
9. 在交接记录中写明下一阶段入口
```

提交要求：

| 项 | 要求 |
|---|---|
| 提交粒度 | 每个 Phase 至少一个 commit；较大 Phase 可按可验证切片拆多个 commit |
| 提交前置 | `typecheck`、`lint`、`test`、`build` 通过；涉及流程时 `test:e2e` 通过 |
| 提交内容 | 只包含当前 Phase 相关文件 |
| 提交信息 | 使用 `feat(web-his): ...`、`test(web-his): ...`、`docs(web-his): ...` 等前缀 |
| 提交后记录 | 在阶段进度记录写入 commit hash、验证命令、结果和剩余风险 |

交接记录建议新增：

```text
docs/engineering/web-his/01_Web_HIS前端Goal进度追踪.md
```

进度记录每个 Phase 至少包含：

| 字段 | 内容 |
|---|---|
| Phase | 当前阶段名称 |
| 状态 | 未开始、进行中、已验收、已提交 |
| 完成内容 | 本阶段实际完成的功能和文件范围 |
| 暂缓事项 | 明确留到后续阶段的内容 |
| 验证命令 | 实际运行的命令 |
| 验证结果 | 通过、失败和关键日志 |
| 浏览器验证 | 视口、页面、流程、截图路径 |
| Commit | 提交 hash |
| 下一入口 | 下个阶段从哪里开始 |
| 风险 | 仍需关注的问题 |

## 11.0.1 阶段边界矩阵

| Phase | 本阶段范围 | 暂缓事项 | 验收标准 | 提交要求 |
|---|---|---|---|---|
| Phase 0 | 工程骨架、HeroUI v3、Tailwind v4、MSW 开关、MVVM 模板 | 业务深层页面、完整 HIS 流程、后端接口 | 登录页可打开，构建、类型、lint、测试通过 | `feat(web-his): bootstrap web his app` |
| Phase 1 | mock 登录、租户/院区/角色、权限导航、403 | 今日队列、接诊、收费、药房深层流程 | 登录、退出、刷新恢复、权限路由通过 E2E | `feat(web-his): add mock auth and role shell` |
| Phase 2 | 今日工作台、角色待办、风险提醒、队列跳转 | 患者详情、病历编辑、收费发药完整闭环 | 三类角色工作台可用，队列状态可变更 | `feat(web-his): add daily dashboard queues` |
| Phase 3 | 患者列表、患者详情、新建患者、风险信息 | 接诊病历、处方、收费、发药 | 搜索、新建、详情、权限验收通过 | `feat(web-his): add patient records` |
| Phase 4 | 接诊病历、体征、诊断、医嘱、处方、报告 mock | 收费支付、发药库存、健康档案发布 | 接诊到待收费流程 E2E 通过 | `feat(web-his): add encounter and prescription flow` |
| Phase 5 | 收费、退款、药房发药、库存扣减、收据预览 | 健康档案发布、授权审计深层能力 | 收费到发药完成流程 E2E 通过 | `feat(web-his): add billing and pharmacy flow` |
| Phase 6 | 健康档案发布、App 预览、授权日志、访问审计 | 真实 App 回流、真实跨院授权、后端审计落库 | 发布预览隔离敏感信息，审计筛选可用 | `feat(web-his): add health publication and audit` |
| Phase 7 | mock API contract、DTO 对齐、OpenAPI 接入准备、错误映射 | Rust 后端实现、数据库迁移、真实 token | 关闭 MSW 的替换路径清晰，contract 文档完成 | `docs(web-his): document api contract for backend handoff` |

## 11.1 Phase 0：前端工程骨架

目标：建立可运行、可构建、可测试的 Web 工程基础。

| 任务 | 内容 |
|---|---|
| 工程创建 | 新建 `maohuoban-web/`，配置 React + TypeScript + Vite |
| 基础工具 | 配置 ESLint、Prettier、Vitest、Playwright |
| 目录骨架 | 建立 `app/shared/features` 目录 |
| MVVM 骨架 | 为首批 Feature 建立 `domain/data/view-models/presentation` 模板 |
| 基础布局 | 登录布局、后台布局、侧边导航、顶部栏 |
| Mock 开关 | 支持开发环境启用 MSW |

验收标准：

| 类型 | 标准 |
|---|---|
| 运行 | `pnpm dev` 可启动，打开后看到登录页 |
| 构建 | `pnpm build` 成功 |
| 类型 | `pnpm typecheck` 无错误 |
| Lint | `pnpm lint` 无错误 |
| 测试 | `pnpm test` 有基础 smoke test 并通过 |
| 架构 | 示例 Feature 符合 MVVM 目录结构，页面不直接读取 mock fixture |

## 11.2 Phase 1：登录、租户、角色和权限壳

目标：完成医院员工 mock 登录和角色权限体验。

| 任务 | 内容 |
|---|---|
| mock 登录 | 支持院长、医生、前台、药房等固定账号 |
| 当前上下文 | 保存当前医院、院区、员工、角色 |
| 权限导航 | 不同角色展示不同导航 |
| route guard | 无权限访问显示 403 页面 |
| 员工切换 | 开发模式支持快速切换角色 |

验收标准：

| 类型 | 标准 |
|---|---|
| 页面 | 登录页、租户选择、院区选择、403 页面完整 |
| 交互 | 登录、退出、刷新恢复 session 正常 |
| 权限 | 医生看不到收费退款入口，药房看不到病历编辑入口 |
| 测试 | 权限 helper 单元测试覆盖主要角色 |
| E2E | Playwright 覆盖登录 -> 工作台 -> 退出 |

## 11.3 Phase 2：今日工作台

目标：建立医院高频队列和角色待办。

| 任务 | 内容 |
|---|---|
| 概览卡 | 今日预约、待接诊、待收费、待发药、待发布 |
| 队列表 | 按时间和状态展示待办 |
| 风险提醒 | 过敏、低库存、近效期、超时 |
| 快捷动作 | 新建患者、登记到院、开始接诊、收费、发药 |
| 状态联动 | mock 状态变更后工作台刷新 |

验收标准：

| 类型 | 标准 |
|---|---|
| 数据 | mock 今日队列展示准确 |
| 角色 | 医生、前台、药房看到不同主待办 |
| 交互 | 点击队列项能进入对应模块详情 |
| 响应式 | 1440px、1280px、1024px 宽度无明显遮挡 |
| E2E | 覆盖登记到院 -> 工作台状态变化 |

## 11.4 Phase 3：宠物患者和主人档案

目标：完成患者检索、详情和新建患者闭环。

| 任务 | 内容 |
|---|---|
| 患者列表 | 搜索、筛选、风险标签 |
| 患者详情 | 基础信息、主人、健康概览、历史就诊 |
| 新建患者 | 宠物和主人基础表单 |
| 历史记录 | 报告、用药、就诊摘要 |
| 风险提示 | 过敏、慢病、当前用药醒目展示 |

验收标准：

| 类型 | 标准 |
|---|---|
| 查询 | 宠物名、主人手机号、病历号搜索可用 |
| 新建 | 新建患者后列表和详情可见 |
| 风险 | 过敏和当前用药不被折叠隐藏 |
| 权限 | 前台可建档，药房不可建档 |
| 测试 | 患者 mapper、搜索 filter、详情状态测试通过 |

## 11.5 Phase 4：接诊病历和处方

目标：跑通医生接诊、病历保存和处方生成。

| 任务 | 内容 |
|---|---|
| 接诊页 | 宠物摘要、主诉、体征、诊断 |
| 医嘱 | 检查、检验、治疗、护理 |
| 处方 | 药品选择、剂量、频次、途径、疗程 |
| 报告上传 mock | 检验/影像报告附件 mock |
| 病历状态 | 草稿、待补报告、已归档 |

验收标准：

| 类型 | 标准 |
|---|---|
| 表单 | 病历和处方可保存为 mock 数据 |
| 安全 | 处方区显示体重、过敏、剂量提示 |
| 状态 | 保存处方后生成待收费项 |
| 离开保护 | 未保存表单离开前有确认 |
| E2E | 覆盖开始接诊 -> 填病历 -> 开处方 -> 待收费 |

## 11.6 Phase 5：收费和药房

目标：跑通收费、支付、发药和库存扣减。

| 任务 | 内容 |
|---|---|
| 待收费 | 就诊产生收费单 |
| 收费详情 | 项目、药品、折扣、支付方式 |
| 收据 | mock 打印预览 |
| 待发药 | 已支付处方进入药房队列 |
| 发药 | 选择批号，确认发药，扣减 mock 库存 |
| 库存 | 低库存、近效期和停用状态 |

验收标准：

| 类型 | 标准 |
|---|---|
| 金额 | 收费单金额计算正确 |
| 流程 | 支付后药房出现待发药 |
| 发药 | 确认发药后库存扣减 |
| 审计 | 退款和发药生成审计日志 |
| E2E | 覆盖待收费 -> 支付 -> 待发药 -> 发药完成 |

## 11.7 Phase 6：健康档案发布和授权审计

目标：建立 App 回流发布版健康档案和审计证明界面。

| 任务 | 内容 |
|---|---|
| 待发布 | 就诊后生成健康档案候选摘要 |
| 发布审核 | 选择诊断摘要、报告、用药摘要、复诊建议 |
| App 预览 | 展示宠物主 App 将看到的内容 |
| 授权日志 | 跨院授权、保险授权、家庭成员授权 |
| 访问审计 | 查看、导出、发布、退款、权限变更日志 |

验收标准：

| 类型 | 标准 |
|---|---|
| 隔离 | 内部备注、成本、利润、方案模板不出现在 App 预览 |
| 发布 | 发布后状态进入已发布并生成版本记录 |
| 授权 | 可查看授权对象、范围、用途、有效期 |
| 审计 | 可按员工、宠物、动作、时间筛选 |
| E2E | 覆盖就诊完成 -> 发布健康档案 -> 审计日志可查 |

## 11.8 Phase 7：后端接入准备

目标：让前端 mock contract 可平滑过渡到 Rust API。

| 任务 | 内容 |
|---|---|
| API contract 整理 | 输出 mock API、请求、响应、错误码 |
| DTO 对齐 | 清理前端模型和未来 Rust DTO 命名差异 |
| OpenAPI 预留 | API client 层封装便于替换为生成代码 |
| 错误处理 | 统一处理业务错误、权限错误、未登录、网络错误 |
| 数据状态 | 明确前端临时状态和后端权威状态边界 |

验收标准：

| 类型 | 标准 |
|---|---|
| 文档 | 生成 Web HIS mock API contract 文档 |
| 架构 | 页面不直接依赖 MSW fixture，只依赖 API client |
| 数据流 | Feature 遵循 presentation -> view-models -> data -> API client 的单向链路 |
| 替换成本 | 关闭 MSW 后只需要替换 baseURL 和 client 实现 |
| 错误态 | 401、403、404、409、500 均有统一 UI |
| 测试 | API mapper 和 error mapper 单元测试通过 |

---

## 12. 质量门禁

每个阶段完成后必须运行：

| 类型 | 命令 |
|---|---|
| 安装 | `cd maohuoban-web && pnpm install` |
| 类型检查 | `cd maohuoban-web && pnpm typecheck` |
| Lint | `cd maohuoban-web && pnpm lint` |
| 单元测试 | `cd maohuoban-web && pnpm test` |
| 构建 | `cd maohuoban-web && pnpm build` |
| E2E | `cd maohuoban-web && pnpm test:e2e` |

涉及 UI 调整时必须额外完成浏览器验证：

| 视口 | 验证 |
|---|---|
| 1440 x 900 | 主力桌面工作站 |
| 1280 x 800 | 常见笔记本 |
| 1024 x 768 | 小屏平板/旧电脑 |

浏览器验收要求：

| 项 | 标准 |
|---|---|
| 无空白页 | 登录后所有一级导航可打开 |
| 无文本溢出 | 表格、按钮、标签、弹窗内容不挤压错位 |
| 无遮挡 | 顶栏、侧栏、表单、抽屉、弹窗不互相遮挡 |
| 状态完整 | 加载、空态、错误、禁用、选中、保存中都有表现 |
| 关键流程可操作 | 接诊、收费、发药、发布、审计能走通 |

架构验收要求：

| 项 | 标准 |
|---|---|
| MVVM 目录 | 新增 Feature 保持 `domain/data/view-models/presentation` |
| 单向数据流 | 页面事件只能进入 ViewModel，再由 Repository 调 API |
| Mock 隔离 | 业务页面和 ViewModel 不直接 import fixture |
| 可替换 API | 关闭 MSW 后页面依赖仍指向同一套 API client |
| 可维护测试 | domain、mapper、ViewModel 至少覆盖核心状态和失败路径 |

---

## 13. UI/UX 约束

| 约束 | 要求 |
|---|---|
| 后台工具定位 | 避免营销页、落地页和大面积装饰图 |
| 信息密度 | 表格、筛选、状态和快捷操作优先 |
| 视觉 token | 先建立 Web token，颜色、间距、圆角统一 |
| 状态颜色 | 医疗风险、收费状态、发药状态、发布状态有稳定语义 |
| 表单分组 | 接诊病历按主诉、体征、诊断、医嘱、处方分区 |
| 操作可逆 | 发布、退款、权限变更等危险动作有确认和原因 |
| 可访问性 | 表单 label、按钮 aria、键盘导航基础可用 |
| 打印预留 | 收据、处方、报告预览按打印友好结构设计 |

---

## 14. 后端接入前的交付物

前端 mock 阶段完成后，必须输出：

| 交付物 | 用途 |
|---|---|
| Web HIS 可运行前端 | 医院端产品流程演示 |
| Mock API contract | 后端 Rust 接口拆分依据 |
| TypeScript 数据模型 | Rust DTO 和数据库模型对齐依据 |
| 权限矩阵 | 后端 RBAC 和审计设计依据 |
| 关键流程 E2E | 后端接入后的回归用例 |
| 页面截图/录屏 | 产品评审和医院访谈材料 |
| 问题清单 | 哪些流程需要后端能力、哪些只是前端交互 |

---

## 15. 风险

| 风险 | 影响 | 处理 |
|---|---|---|
| mock 流程过于理想 | 后端接入时发现真实状态复杂 | mock 数据必须覆盖异常、空态、权限和冲突 |
| 前端权限被误认为安全边界 | 数据安全误判 | 文档和代码注释明确前端权限只做体验控制 |
| UI 过早深度定制 HeroUI 基础组件 | 后期迁移成本高 | 起步阶段封装 HIS 业务组件，页面层通过业务组件组合 |
| Feature 目录各自为政 | 扩展和维护成本升高 | 强制 MVVM 目录模板和单向数据流 |
| HIS 模块过大 | 单阶段难以验收 | 按 Phase 独立验收，每阶段保持可运行 |
| 健康档案发布边界不清 | 医院担心泄露内部方案 | 发布预览必须排除内部备注、成本、利润、方案模板 |
| 后端 DTO 后续反推前端大改 | 接入成本高 | Phase 7 专门做 contract 整理和命名对齐 |
| 只做界面不跑流程 | 原型价值不足 | 每阶段都要有 E2E 或手动流程验收 |

---

## 16. 当前推荐决策

| 决策 | 结论 |
|---|---|
| 是否现在启动 Web 前端 | 可以启动 |
| 后端是否同步开发 | 当前目标期暂缓 |
| 前端工程目录 | `maohuoban-web/` |
| 语言 | TypeScript |
| 框架 | React + Vite |
| UI | HeroUI v3 React + Tailwind CSS v4，沉淀毛伙伴 Web 组件 |
| 架构 | MVVM 目录结构 + 单向数据流 |
| Mock | MSW + fixture |
| 第一验收点 | 医院员工 mock 登录后进入今日工作台 |
| 第一条完整业务链 | 预约到院 -> 接诊 -> 处方 -> 收费 -> 发药 -> 发布健康档案 |
