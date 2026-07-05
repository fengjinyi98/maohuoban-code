---
alwaysApply: true
scene: git_message
---

## 提交规范

1. 提交信息统一使用 Conventional Commits 单行标题格式：
   ```text
   <type>(<scope>): <中文变更摘要>
   ```
2. `type` 只使用以下常见类型：
   - `feat`：新增用户可见能力、业务能力或平台能力。
   - `fix`：修复缺陷、回归、异常状态或兼容问题。
   - `refactor`：重构结构、拆分模块、迁移目录，且不改变外部行为。
   - `test`：新增或调整测试、评测用例、合同验证。
   - `docs`：新增或调整文档、目标说明、工程记录。
   - `chore`：仓库配置、构建脚本、清理产物、依赖和非业务维护。
3. `scope` 必须表达影响范围，优先使用模块或领域名，例如 `ai`、`ios`、`rust`、`auth`、`home`、`design-system`、`repo`。
4. 标题摘要使用简体中文，描述本次提交完成的具体结果，禁止使用“修改一下”“调整代码”“提交更新”等模糊表达。
5. 每个提交只表达一个清晰意图；代码、测试、文档可以同提交，但必须共同服务同一变更目标。
6. 修复类提交必须使用 `fix(<scope>): ...`；测试或评测合同使用 `test(<scope>): ...`；纯目录拆分或文件搬迁使用 `refactor(<scope>): ...`。
7. 合并提交也必须规范化，例如：
   ```text
   chore(ai): 合并 WT01 session 与 turn 主链
   ```
8. 提交前必须检查暂存区，只提交本轮相关文件；禁止把用户已有无关改动混入提交。
9. 未推送到远端的本地提交若标题不规范，应通过 `git commit --amend` 或保留 merge 拓扑的 rebase 修正；已推送提交需要先确认是否会影响协作者。

示例：

```text
feat(ai): 接入同会话最近历史上下文
fix(ai): 增强流式回退与 provider SSE 解析
refactor(ai): 拆分 DeepSeek 与 OpenAI provider
test(ai): 新增评测回归合同测试与诊断断言用例
docs(ai): 更新工程规则与 Agent 落地清单
chore(repo): 添加 tmp 到 gitignore
```
