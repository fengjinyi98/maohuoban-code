# 毛伙伴 HIS Web Mock API Contract

## 边界

前端当前使用 `/api/mock` 前缀和 MSW 拦截请求。页面只依赖 `src/shared/api/http.ts` 与各 Feature Repository；后端接入时替换 baseURL 或生成 client，不改变页面事件流。

## Auth

| Method | Path                             | 用途                                        |
| ------ | -------------------------------- | ------------------------------------------- |
| POST   | `/api/mock/auth/login`           | mock 员工登录，返回 session、可选租户和院区 |
| POST   | `/api/mock/auth/context`         | 选择医院租户、院区和角色                    |
| GET    | `/api/mock/auth/context-options` | 获取可选医院和院区                          |

## HIS

| Method | Path                                                              | 用途                                     |
| ------ | ----------------------------------------------------------------- | ---------------------------------------- |
| GET    | `/api/mock/his/dashboard/today`                                   | 今日概览、队列、风险和待发布             |
| GET    | `/api/mock/his/patients`                                          | 患者列表，支持 `keyword`                 |
| POST   | `/api/mock/his/patients`                                          | 新建患者                                 |
| GET    | `/api/mock/his/patients/:patientId`                               | 患者详情、历史就诊、账单                 |
| GET    | `/api/mock/his/encounters/:encounterId?`                          | 接诊队列或单个就诊                       |
| POST   | `/api/mock/his/encounters/:encounterId/start`                     | 开始接诊                                 |
| POST   | `/api/mock/his/encounters/:encounterId/save`                      | 保存病历、处方并生成待收费               |
| GET    | `/api/mock/his/invoices`                                          | 收费单列表                               |
| POST   | `/api/mock/his/invoices/:invoiceId/pay`                           | 收款并推进药房待发药                     |
| POST   | `/api/mock/his/invoices/:invoiceId/refund`                        | 退款申请，必须填写原因                   |
| GET    | `/api/mock/his/pharmacy`                                          | 待发药和库存                             |
| POST   | `/api/mock/his/pharmacy/:encounterId/dispense`                    | 确认发药并扣减库存                       |
| GET    | `/api/mock/his/health-record-publications`                        | 健康档案发布列表                         |
| POST   | `/api/mock/his/health-record-publications/:publicationId/:action` | `publish`、`delay`、`block`              |
| GET    | `/api/mock/his/audit-logs`                                        | 授权和审计日志，支持 `keyword`、`action` |
| GET    | `/api/mock/his/settings`                                          | 员工、角色、院区和药品配置               |

## 错误码

| HTTP | code           | 场景                   |
| ---: | -------------- | ---------------------- |
|  401 | `UNAUTHORIZED` | 未登录或 session 失效  |
|  403 | `FORBIDDEN`    | 账号停用或权限不足     |
|  404 | `NOT_FOUND`    | 资源不存在             |
|  409 | `CONFLICT`     | 状态冲突或缺少退款原因 |
|  500 | `INTERNAL`     | 服务端内部错误         |
