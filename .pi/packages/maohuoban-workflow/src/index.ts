import fs from "node:fs";
import crypto from "node:crypto";
import os from "node:os";
import path from "node:path";
import { Type } from "typebox";
import { defineTool, isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";

type GoalStatus = "active" | "complete" | "blocked";
type ExternalGoalStatus = "active" | "paused" | "budgetLimited" | "complete";
type ItemStatus = "pending" | "in_progress" | "done" | "blocked";
type EvidenceKind = "failing-test" | "green-test" | "verification" | "advisor-review" | "diff" | "note";

interface AcceptanceItem {
	id: string;
	text: string;
	status: ItemStatus;
	evidence: string[];
}

interface GoalEvidence {
	kind: EvidenceKind;
	text: string;
	command?: string;
	slice?: string;
	timestamp: string;
}

interface GoalState {
	status: GoalStatus;
	objective: string;
	source?: string;
	currentSlice?: string;
	todoWikiPath?: string;
	acceptanceItems: AcceptanceItem[];
	evidence: GoalEvidence[];
	blockedReason?: string;
	createdAt: string;
	updatedAt: string;
}

const STATE_ENTRY_TYPE = "maohuoban-goal-state";
const CODEX_GOAL_ENTRY_TYPE = "pi-codex-goal";
const TODO_WIKI_DIR = "docs/engineering/_goal-wiki";
const PROJECT_GOAL_STATE_FILE = `${TODO_WIKI_DIR}/_active-goal.json`;
const RESPONSIBILITY_DIRS = ["Domain", "Data", "Presentation", "Stores", "Services", "Infrastructure", "Theme"];
const RUST_CRATE_RESPONSIBILITY_SUFFIXES = ["-domain", "-application", "-http", "-infrastructure", "-worker", "-storage"];
const SWIFT_GUIDELINE_LIMIT = 250;
const SWIFT_HARD_LIMIT = 400;
const RUST_GUIDELINE_LIMIT = 300;
const RUST_HARD_LIMIT = 500;

interface StructureEvaluation {
	errors: string[];
	warnings: string[];
}

const GoalUpdateParams = Type.Object({
	action: Type.Union([
		Type.Literal("status"),
		Type.Literal("start_goal"),
		Type.Literal("set_current_slice"),
		Type.Literal("start_item"),
		Type.Literal("complete_item"),
		Type.Literal("add_evidence"),
		Type.Literal("complete_goal"),
		Type.Literal("block_goal"),
		Type.Literal("clear_goal"),
	]),
	objective: Type.Optional(Type.String()),
	source: Type.Optional(Type.String()),
	currentSlice: Type.Optional(Type.String()),
	itemId: Type.Optional(Type.String()),
	itemText: Type.Optional(Type.String()),
	evidenceKind: Type.Optional(Type.Union([
		Type.Literal("failing-test"),
		Type.Literal("green-test"),
		Type.Literal("verification"),
		Type.Literal("advisor-review"),
		Type.Literal("diff"),
		Type.Literal("note"),
	])),
	evidenceText: Type.Optional(Type.String()),
	command: Type.Optional(Type.String()),
	reason: Type.Optional(Type.String()),
});

let activeGoal: GoalState | undefined;
let externalGoalStatus: ExternalGoalStatus | undefined;
let externalGoalObjective: string | undefined;

// nowIso 生成可追踪时间戳
// 核心职责：
// - 统一 goal 状态时间字段
// - 避免多处散写时间格式
function nowIso(): string {
	return new Date().toISOString();
}

// resolveProjectPath 解析项目内路径
// 核心职责：
// - 支持绝对路径、相对路径和用户目录路径
// - 为目标文档读取提供稳定入口
function resolveProjectPath(value: string, cwd = process.cwd()): string {
	if (value.startsWith("~/")) {
		return path.join(os.homedir(), value.slice(2));
	}
	if (path.isAbsolute(value)) {
		return value;
	}
	return path.resolve(cwd, value);
}

// projectGoalStatePath 获取项目级 goal 状态文件
// 核心职责：
// - 提供跨 Pi session 的稳定恢复来源
// - 与 TODO wiki 放在同一执行台账目录
function projectGoalStatePath(): string {
	return path.resolve(process.cwd(), PROJECT_GOAL_STATE_FILE);
}

// loadProjectGoal 读取项目级 goal 状态
// 核心职责：
// - 在新 session 没有历史 entry 时恢复 Maohuoban gate
// - 避免状态文件损坏导致 Pi 启动失败
function loadProjectGoal(): GoalState | undefined {
	const filePath = projectGoalStatePath();
	if (!fs.existsSync(filePath)) {
		return undefined;
	}
	try {
		const parsed = JSON.parse(fs.readFileSync(filePath, "utf8")) as GoalState;
		if (!parsed || typeof parsed !== "object" || typeof parsed.status !== "string" || typeof parsed.objective !== "string") {
			return undefined;
		}
		if (!parsed.todoWikiPath) {
			parsed.todoWikiPath = todoWikiPathForGoal(parsed);
		}
		return parsed;
	} catch {
		return undefined;
	}
}

// saveProjectGoal 写入项目级 goal 状态
// 核心职责：
// - 让 active goal 跨新会话可恢复
// - clear 时移除 active 状态文件
function saveProjectGoal(goal: GoalState | undefined): void {
	const filePath = projectGoalStatePath();
	if (!goal) {
		if (fs.existsSync(filePath)) {
			fs.rmSync(filePath);
		}
		return;
	}
	fs.mkdirSync(path.dirname(filePath), { recursive: true });
	fs.writeFileSync(filePath, `${JSON.stringify(goal, null, 2)}\n`, "utf8");
}

// reconstructGoal 从会话恢复目标状态
// 核心职责：
// - 读取 Pi session 中的自定义状态记录
// - 会话无状态时从项目级状态文件恢复
function reconstructGoal(ctx: ExtensionContext): void {
	const manager = ctx.sessionManager as unknown as {
		getBranch?: () => unknown[];
		getEntries?: () => unknown[];
	};
	const entries = manager.getBranch?.() ?? manager.getEntries?.() ?? [];
	activeGoal = undefined;
	externalGoalStatus = undefined;
	externalGoalObjective = undefined;
	for (const entry of entries as Array<Record<string, unknown>>) {
		if (entry.type === "custom" && entry.customType === STATE_ENTRY_TYPE) {
			activeGoal = entry.data as GoalState | undefined;
		}
		if (entry.type === "custom" && entry.customType === CODEX_GOAL_ENTRY_TYPE) {
			const data = entry.data as Record<string, unknown> | null | undefined;
			if (!data || typeof data !== "object") continue;
			if (data.kind === "clear") {
				externalGoalStatus = undefined;
				externalGoalObjective = undefined;
				continue;
			}
			if (data.kind === "set" && data.goal && typeof data.goal === "object") {
				const goal = data.goal as Record<string, unknown>;
				if (typeof goal.status === "string") {
					externalGoalStatus = goal.status as ExternalGoalStatus;
				}
				if (typeof goal.objective === "string") {
					externalGoalObjective = goal.objective;
				}
				continue;
			}
			if (data.kind === "usage" && typeof data.status === "string") {
				externalGoalStatus = data.status as ExternalGoalStatus;
			}
		}
	}
	if (!activeGoal) {
		activeGoal = loadProjectGoal();
	}
}

// saveGoal 保存目标状态
// 核心职责：
// - 更新内存中的 active goal
// - 将状态追加进 Pi session 供恢复使用
function saveGoal(pi: ExtensionAPI, goal: GoalState | undefined): void {
	activeGoal = goal;
	if (goal) {
		syncTodoWiki(goal);
	}
	saveProjectGoal(goal);
	pi.appendEntry(STATE_ENTRY_TYPE, goal ?? null);
}

// createGoalFromSource 根据文档或描述创建目标
// 核心职责：
// - 从目标文档提取 objective 和验收项
// - 在无文档时使用用户描述创建轻量目标
function createGoalFromSource(sourceOrObjective: string, explicitObjective?: string): GoalState {
	const resolved = resolveProjectPath(sourceOrObjective);
	let source: string | undefined;
	let content = "";
	if (fs.existsSync(resolved) && fs.statSync(resolved).isFile()) {
		source = resolved;
		content = fs.readFileSync(resolved, "utf8");
	}

	const objective = explicitObjective?.trim() || extractObjective(content) || sourceOrObjective.trim();
	const acceptanceItems = content ? extractAcceptanceItems(content) : [];
	const createdAt = nowIso();
	const goal: GoalState = {
		status: "active",
		objective,
		source,
		acceptanceItems,
		evidence: [],
		createdAt,
		updatedAt: createdAt,
	};
	goal.todoWikiPath = todoWikiPathForGoal(goal);
	return goal;
}

// todoWikiPathForGoal 生成目标台账路径
// 核心职责：
// - 每个目标文档映射到一个稳定 TODO wiki
// - 避免中文标题和同名文档冲突
function todoWikiPathForGoal(goal: GoalState): string {
	const seed = goal.source ?? goal.objective;
	const baseName = goal.source ? path.basename(goal.source, path.extname(goal.source)) : goal.objective;
	const slug = slugify(baseName).slice(0, 72) || "goal";
	const hash = crypto.createHash("sha1").update(seed).digest("hex").slice(0, 8);
	return path.resolve(process.cwd(), TODO_WIKI_DIR, `${slug}-${hash}.md`);
}

// slugify 生成可读文件名片段
// 核心职责：
// - 保留中文、英文、数字和连字符
// - 清理文件系统不稳定字符
function slugify(value: string): string {
	return value
		.normalize("NFKC")
		.replace(/[^\p{Letter}\p{Number}]+/gu, "-")
		.replace(/^-+|-+$/g, "")
		.toLowerCase();
}

// syncTodoWiki 同步目标执行台账
// 核心职责：
// - 将 goal 状态、验收项和证据落到可审查文档
// - 给 Pi/DeepSeek 提供外部化 TODO 记忆
function syncTodoWiki(goal: GoalState): void {
	if (!goal.todoWikiPath) {
		goal.todoWikiPath = todoWikiPathForGoal(goal);
	}
	fs.mkdirSync(path.dirname(goal.todoWikiPath), { recursive: true });
	fs.writeFileSync(goal.todoWikiPath, renderTodoWiki(goal), "utf8");
}

// renderTodoWiki 渲染目标执行台账
// 核心职责：
// - 固定章节顺序，方便模型逐轮维护
// - 保留状态、TODO、证据和 advisor 审查记录
function renderTodoWiki(goal: GoalState): string {
	const source = goal.source ?? "未绑定目标文档";
	const currentSlice = goal.currentSlice ?? "未设置";
	const acceptance = goal.acceptanceItems.length > 0
		? goal.acceptanceItems.map((item) => `- [${item.status === "done" ? "x" : " "}] ${item.id} (${item.status}) ${item.text}${item.evidence.length > 0 ? `\n  - evidence: ${item.evidence.join(" | ")}` : ""}`).join("\n")
		: "- [ ] 当前目标未解析到验收项，必须从目标文档手工补充。";
	const evidence = goal.evidence.length > 0
		? goal.evidence.map((item) => `- ${item.timestamp} [${item.kind}]${item.slice ? ` slice=${item.slice}` : ""}${item.command ? `\n  - command: \`${item.command.replaceAll("`", "\\`")}\`` : ""}\n  - ${item.text}`).join("\n")
		: "- 暂无证据。";
	const nextActions = goal.acceptanceItems
		.filter((item) => item.status !== "done")
		.map((item) => `- [ ] ${item.id}: ${item.text}`)
		.join("\n") || "- [x] 当前无未完成验收项，完成前仍需 advisor-review 和 verification 证据。";

	return `# Maohuoban Goal TODO Wiki

## 目标
- status: ${goal.status}
- objective: ${goal.objective}
- source: ${source}
- current_slice: ${currentSlice}
- updated_at: ${goal.updatedAt}

## 当前执行规则
- 每个生产代码切片先记录 failing-test 证据，再写实现。
- 每次完成切片必须记录 green-test 或 verification 证据。
- 关键节点必须调用 advisor，并把结论记录为 advisor-review 证据。
- 标记 goal complete 前必须逐项核对目标文档验收项。

## TODO
${acceptance}

## 下一步
${nextActions}

## 证据
${evidence}

## 风险与待审
- [ ] 是否存在测试只验证派生快照、未验证真实持久化的问题。
- [ ] 是否存在状态更新过宽，误影响其他 pet/episode/task 的问题。
- [ ] 是否存在 route payload 缺少稳定 ID 的问题。
- [ ] 是否已执行目标文档要求的 agent_confirmation_tasks。
`;
}

// extractObjective 提取目标摘要
// 核心职责：
// - 优先使用文档中的 Goal 行
// - 回退到一级标题
function extractObjective(content: string): string | undefined {
	for (const line of content.split(/\r?\n/)) {
		const goal = line.match(/^\s*-\s*Goal[：:]\s*(.+)\s*$/i);
		if (goal?.[1]) {
			return goal[1].trim();
		}
		const title = line.match(/^#\s+(.+)\s*$/);
		if (title?.[1]) {
			return title[1].trim();
		}
	}
	return undefined;
}

// extractAcceptanceItems 提取验收项
// 核心职责：
// - 支持目标文档中的 Task 标题
// - 支持验收门禁表格和 checkbox
function extractAcceptanceItems(content: string): AcceptanceItem[] {
	const items: AcceptanceItem[] = [];
	const lines = content.split(/\r?\n/);
	let inGateSection = false;
	let gateIndex = 1;

	for (const line of lines) {
		const task = line.match(/^###\s*Task\s*([0-9]+)[：:]\s*(.+)\s*$/i);
		if (task?.[1] && task?.[2]) {
			items.push({
				id: `task-${task[1]}`,
				text: `Task ${task[1]}：${task[2].trim()}`,
				status: "pending",
				evidence: [],
			});
			continue;
		}

		const checkbox = line.match(/^\s*-\s*\[[ xX]\]\s+(.+)\s*$/);
		if (checkbox?.[1]) {
			items.push({
				id: `check-${items.length + 1}`,
				text: checkbox[1].trim(),
				status: "pending",
				evidence: [],
			});
			continue;
		}

		if (/^##\s*9\.\s*验收门禁/.test(line)) {
			inGateSection = true;
			continue;
		}
		if (inGateSection && /^##\s+/.test(line)) {
			inGateSection = false;
		}
		if (inGateSection && line.startsWith("|")) {
			const columns = line.split("|").map((value) => value.trim()).filter(Boolean);
			if (columns.length >= 2 && columns[0] !== "类型" && !columns[0].startsWith("---")) {
				items.push({
					id: `gate-${gateIndex++}`,
					text: `验收门禁：${columns[0]} -> ${columns.slice(1).join(" | ")}`,
					status: "pending",
					evidence: [],
				});
			}
		}
	}

	return dedupeItems(items);
}

// dedupeItems 去重验收项
// 核心职责：
// - 保持文档顺序
// - 避免重复标题造成状态混乱
function dedupeItems(items: AcceptanceItem[]): AcceptanceItem[] {
	const seen = new Set<string>();
	const result: AcceptanceItem[] = [];
	for (const item of items) {
		if (seen.has(item.text)) continue;
		seen.add(item.text);
		result.push(item);
	}
	return result;
}

// renderGoal 渲染目标状态
// 核心职责：
// - 给命令和工具返回稳定文本
// - 展示完成度、当前切片和证据数量
function renderGoal(goal: GoalState | undefined): string {
	if (!goal) {
		const external = externalGoalStatus ? `pi-codex-goal: ${externalGoalStatus}${externalGoalObjective ? `\nobjective: ${externalGoalObjective}` : ""}` : "pi-codex-goal: none";
		return `当前没有 Maohuoban project gate state。\n${external}\n使用 mhb_goal_update start_goal 记录目标文档验收项和 TDD slice。`;
	}
	const done = goal.acceptanceItems.filter((item) => item.status === "done").length;
	const total = goal.acceptanceItems.length;
	const lines = [
		`status: ${goal.status}`,
		`objective: ${goal.objective}`,
		goal.source ? `source: ${goal.source}` : undefined,
		goal.currentSlice ? `current_slice: ${goal.currentSlice}` : undefined,
		`acceptance: ${done}/${total}`,
		`evidence: ${goal.evidence.length}`,
		goal.todoWikiPath ? `todo_wiki: ${goal.todoWikiPath}` : undefined,
		goal.blockedReason ? `blocked_reason: ${goal.blockedReason}` : undefined,
	].filter(Boolean) as string[];
	if (goal.acceptanceItems.length > 0) {
		lines.push("");
		lines.push("acceptance_items:");
		for (const item of goal.acceptanceItems) {
			lines.push(`- [${item.status}] ${item.id}: ${item.text}`);
		}
	}
	return lines.join("\n");
}

// isGoalWorkActive 判断是否处于目标执行中
// 核心职责：
// - 兼容 pi-codex-goal 的 active 状态
// - 保持 Maohuoban 本地目标状态可独立驱动门禁
function isGoalWorkActive(): boolean {
	return activeGoal?.status === "active" || externalGoalStatus === "active";
}

// currentGoalGateLabel 输出门禁来源说明
// 核心职责：
// - 在阻断信息中说明触发来源
// - 帮助用户区分通用 goal 与项目 gate
function currentGoalGateLabel(): string {
	if (activeGoal?.status === "active" && externalGoalStatus === "active") {
		return "pi-codex-goal + Maohuoban project gate";
	}
	if (externalGoalStatus === "active") {
		return "pi-codex-goal";
	}
	return "Maohuoban project gate";
}

// addEvidence 记录目标证据
// 核心职责：
// - 将命令输出和人工说明纳入 goal 证据链
// - 自动绑定当前 TDD 切片
function addEvidence(goal: GoalState, kind: EvidenceKind, text: string, command?: string): void {
	goal.evidence.push({
		kind,
		text,
		command,
		slice: goal.currentSlice,
		timestamp: nowIso(),
	});
	goal.updatedAt = nowIso();
}

// findItem 查找验收项
// 核心职责：
// - 支持按 id 精确查找
// - 支持按文本片段查找
function findItem(goal: GoalState, itemId?: string, itemText?: string): AcceptanceItem | undefined {
	if (itemId) {
		const exact = goal.acceptanceItems.find((item) => item.id === itemId);
		if (exact) return exact;
	}
	if (itemText) {
		return goal.acceptanceItems.find((item) => item.text.includes(itemText));
	}
	return undefined;
}

// hasFailingEvidenceForCurrentSlice 判断 TDD 前置证据
// 核心职责：
// - 要求当前切片存在失败测试证据
// - 阻止 active goal 下绕过红灯阶段写生产代码
function hasFailingEvidenceForCurrentSlice(goal: GoalState): boolean {
	if (!goal.currentSlice) {
		return false;
	}
	return goal.evidence.some((evidence) => evidence.kind === "failing-test" && evidence.slice === goal.currentSlice);
}

// canCompleteGoal 判断目标是否可完成
// 核心职责：
// - 要求所有验收项完成
// - 要求至少一条 verification 证据
function canCompleteGoal(goal: GoalState): { ok: true } | { ok: false; reason: string } {
	const incomplete = goal.acceptanceItems.filter((item) => item.status !== "done");
	if (incomplete.length > 0) {
		return { ok: false, reason: `仍有 ${incomplete.length} 个验收项未完成：${incomplete.map((item) => item.id).join(", ")}` };
	}
	if (!goal.evidence.some((evidence) => evidence.kind === "verification")) {
		return { ok: false, reason: "缺少 verification 证据。" };
	}
	return { ok: true };
}

// toolPath 提取工具目标路径
// 核心职责：
// - 兼容 Pi 内置 write/edit 工具输入
// - 为写入门禁提供路径
function toolPath(input: unknown): string | undefined {
	const value = input as Record<string, unknown>;
	for (const key of ["path", "file_path", "filePath"]) {
		const candidate = value[key];
		if (typeof candidate === "string") return candidate;
	}
	return undefined;
}

// toolContent 提取写入内容
// 核心职责：
// - 读取 write 工具的新文件内容
// - 支撑行数和单职责门禁
function toolContent(input: unknown): string | undefined {
	const value = input as Record<string, unknown>;
	for (const key of ["content", "text", "newString", "newText"]) {
		const candidate = value[key];
		if (typeof candidate === "string") return candidate;
	}
	return undefined;
}

// bashCommand 提取 shell 命令
// 核心职责：
// - 读取 Pi bash 工具输入
// - 为 TDD shell 写入门禁提供命令文本
function bashCommand(input: unknown): string | undefined {
	const value = input as Record<string, unknown>;
	return typeof value.command === "string" ? value.command : undefined;
}

// productionWritePathFromCommand 识别 shell 写入生产代码
// 核心职责：
// - 捕获常见 shell 写入方式
// - 提取命令中出现的 Swift/Rust 生产文件路径
function productionWritePathFromCommand(command: string): string | undefined {
	const writes = /\b(apply_patch|tee|sed\s+-i|perl\s+-pi|ruby\s+-pi|python3?\b|node\b)|>>?|<<</.test(command);
	if (!writes) {
		return undefined;
	}
	const matches = command.match(/[~./A-Za-z0-9_\-]+(?:\/[~./A-Za-z0-9_\-]+)*\.(?:swift|rs)/g) ?? [];
	return matches.find((candidate) => isProductionCodePath(resolveProjectPath(candidate)));
}

// isCodePath 判断代码路径
// 核心职责：
// - 只检查 Swift 和 Rust 文件
// - 避免影响文档和 Pi 配置
function isCodePath(filePath: string): boolean {
	return filePath.endsWith(".swift") || filePath.endsWith(".rs");
}

// isProductionCodePath 判断生产代码路径
// 核心职责：
// - 测试、fixture、配置路径允许先写
// - 生产代码受 TDD 门禁保护
function isProductionCodePath(filePath: string): boolean {
	const normalized = filePath.replaceAll("\\", "/");
	if (!isCodePath(normalized)) return false;
	return !normalized.includes("/Tests/")
		&& !normalized.includes("/tests/")
		&& !normalized.includes("/Fixtures/")
		&& !normalized.includes("/fixtures/")
		&& !normalized.includes("/.pi/")
		&& !normalized.includes("/.codex/");
}

// evaluateStructure 检查项目结构
// 核心职责：
// - 复刻 Codex hook 的关键结构规则
// - 区分硬阻断和建议提醒
function evaluateStructure(filePath: string, content?: string): StructureEvaluation {
	const result: StructureEvaluation = { errors: [], warnings: [] };
	if (!isCodePath(filePath)) {
		return result;
	}
	const normalized = filePath.replaceAll("\\", "/");
	if (!hasResponsibilityDirectory(normalized)) {
		result.errors.push(`代码文件未落在明确职责目录中；允许职责目录：${RESPONSIBILITY_DIRS.join(", ")}，或 maohuoban-rust/crates/*-{domain,application,http,infrastructure}。`);
	}
	if (content !== undefined) {
		const lineCount = content.split(/\r?\n/).length;
		if (normalized.endsWith(".swift") && lineCount > SWIFT_HARD_LIMIT) {
			result.errors.push(`Swift 文件 ${lineCount} 行，超过硬上限 ${SWIFT_HARD_LIMIT} 行，必须拆分。`);
		}
		if (normalized.endsWith(".rs") && lineCount > RUST_HARD_LIMIT) {
			result.errors.push(`Rust 文件 ${lineCount} 行，超过硬上限 ${RUST_HARD_LIMIT} 行，必须拆分。`);
		}
		const declarations = primaryDeclarations(normalized, content);
		if (declarations.length > 1) {
			result.warnings.push(`一个文件包含多个顶层主要类型：${declarations.join(", ")}；建议一个类型优先一个文件。`);
		}
		if (normalized.endsWith(".swift") && lineCount > SWIFT_GUIDELINE_LIMIT) {
			result.warnings.push(`Swift 文件 ${lineCount} 行，超过建议线 ${SWIFT_GUIDELINE_LIMIT} 行，建议拆分。`);
		}
		if (normalized.endsWith(".rs") && lineCount > RUST_GUIDELINE_LIMIT) {
			result.warnings.push(`Rust 文件 ${lineCount} 行，超过建议线 ${RUST_GUIDELINE_LIMIT} 行，建议拆分。`);
		}
	}
	return result;
}

// hasResponsibilityDirectory 判断职责目录
// 核心职责：
// - 约束新代码进入清晰架构目录
// - 允许测试和配置路径
function hasResponsibilityDirectory(filePath: string): boolean {
	const parts = filePath.split("/");
	if (parts.some((part) => ["Tests", "tests", "__tests__", "Fixtures", "fixtures", ".pi", ".codex"].includes(part))) {
		return true;
	}
	if (parts.slice(0, -1).some((part) => RESPONSIBILITY_DIRS.includes(part))) {
		return true;
	}
	const cratesIndex = parts.indexOf("crates");
	const crateName = cratesIndex >= 0 ? parts[cratesIndex + 1] : undefined;
	if (crateName?.startsWith("maohuoban-") && RUST_CRATE_RESPONSIBILITY_SUFFIXES.some((suffix) => crateName.endsWith(suffix))) {
		return true;
	}
	return false;
}

// primaryDeclarations 提取顶层主要声明
// 核心职责：
// - 识别 Swift 顶层类型
// - 识别 Rust 公开顶层声明
function primaryDeclarations(filePath: string, content: string): string[] {
	const result: string[] = [];
	for (const rawLine of content.split(/\r?\n/)) {
		if (/^\s/.test(rawLine)) continue;
		const line = rawLine.trimStart();
		const name = filePath.endsWith(".swift") ? swiftDeclarationName(line) : rustDeclarationName(line);
		if (name && !result.includes(name)) {
			result.push(name);
		}
	}
	return result;
}

// swiftDeclarationName 提取 Swift 声明名
// 核心职责：
// - 支持常见访问控制修饰符
// - 返回主要类型名称
function swiftDeclarationName(line: string): string | undefined {
	return declarationNameAfterKeywords(
		line,
		["public", "open", "internal", "private", "fileprivate", "final"],
		["struct", "class", "enum", "actor", "protocol"],
	);
}

// rustDeclarationName 提取 Rust 声明名
// 核心职责：
// - 只约束公开顶层声明
// - 返回主要声明名称
function rustDeclarationName(line: string): string | undefined {
	let rest = line.trimStart();
	if (rest.startsWith("pub ")) {
		rest = rest.slice(4).trimStart();
	} else if (rest.startsWith("pub(")) {
		const end = rest.indexOf(")");
		if (end < 0) return undefined;
		rest = rest.slice(end + 1).trimStart();
	} else {
		return undefined;
	}
	return declarationNameAfterKeywords(rest, ["async"], ["struct", "enum", "trait", "type", "fn"]);
}

// declarationNameAfterKeywords 提取关键字后的名称
// 核心职责：
// - 跳过声明修饰符
// - 清理泛型和标点
function declarationNameAfterKeywords(line: string, modifiers: string[], keywords: string[]): string | undefined {
	const words = line.split(/\s+/);
	let index = 0;
	while (index < words.length && modifiers.includes(words[index])) {
		index += 1;
	}
	if (!keywords.includes(words[index])) {
		return undefined;
	}
	return words[index + 1]?.match(/^[A-Za-z0-9_]+/)?.[0];
}

export default function maohuobanWorkflow(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		reconstructGoal(ctx);
		ctx.ui.setStatus("mhb-goal", activeGoal ? `mhb:${activeGoal.status}` : undefined);
	});

	pi.on("session_tree", async (_event, ctx) => {
		reconstructGoal(ctx);
		ctx.ui.setStatus("mhb-goal", activeGoal ? `mhb:${activeGoal.status}` : undefined);
	});

	pi.on("before_agent_start", async (event, ctx) => {
		reconstructGoal(ctx);
		if (!isGoalWorkActive()) {
			return;
		}
		const goalContext = `

## Maohuoban Project Gate

${renderGoal(activeGoal)}

Rules for this project gate:
- Use pi-codex-goal tools for the durable long-running objective: get_goal, create_goal, update_goal.
- Use mhb_goal_update to record current slice, failing-test, green-test, verification, and acceptance item updates.
- Maintain the TODO wiki shown in mhb_goal_update status. Treat it as the visible execution ledger for TODO, evidence, risks, and next actions.
- Use advisor before major production edits, before marking an acceptance item done, and before completing the goal. Record the result with mhb_goal_update evidenceKind=advisor-review.
- Before editing production Swift/Rust code, create a failing test and record failing-test evidence for the current slice.
- Do not call update_goal complete until mhb_goal_update status shows required slice evidence and the objective audit has real verification.
- If evidence is missing, report progress and the exact missing evidence.
`;
		return { systemPrompt: `${event.systemPrompt}${goalContext}` };
	});

	pi.on("tool_call", async (event, ctx) => {
		reconstructGoal(ctx);
		if (isToolCallEventType("bash", event) && isGoalWorkActive() && !hasFailingEvidenceForCurrentSlice(activeGoal)) {
			const command = bashCommand(event.input);
			const productionPath = command ? productionWritePathFromCommand(command) : undefined;
			if (productionPath) {
				return {
					block: true,
					reason:
						`[MHB_TDD_GATE] ${currentGoalGateLabel()} active 下 shell 写入生产代码 ${productionPath} 前，必须先用 mhb_goal_update 设置 current slice 并记录该切片的 failing-test 证据。`,
				};
			}
		}

		if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
			const target = toolPath(event.input);
			if (!target) return;
			const resolved = resolveProjectPath(target);
			const structure = evaluateStructure(resolved, toolContent(event.input));
			if (structure.warnings.length > 0) {
				ctx.ui.notify(`[MHB_STRUCTURE_GATE] ${structure.warnings.join("\n")}`, "warning");
			}
			if (structure.errors.length > 0) {
				return { block: true, reason: `[MHB_STRUCTURE_GATE] ${structure.errors.join("\n")}` };
			}
			if (isGoalWorkActive() && isProductionCodePath(resolved) && !hasFailingEvidenceForCurrentSlice(activeGoal)) {
				return {
					block: true,
					reason:
						`[MHB_TDD_GATE] ${currentGoalGateLabel()} active 下写生产代码前必须先用 mhb_goal_update 设置 current slice，并记录该切片的 failing-test 证据。`,
				};
			}
		}
	});

	pi.registerCommand("mhb-goal", {
		description: "Maohuoban 项目门禁状态：status/evidence/clear",
		handler: async (args, ctx) => {
			const [command, rest] = splitFirst(args.trim());
			switch (command || "status") {
				case "status":
					ctx.ui.notify(renderGoal(activeGoal), activeGoal ? "info" : "warning");
					break;
				case "evidence":
					ctx.ui.notify(activeGoal?.evidence.map((item) => `${item.kind}: ${item.text}`).join("\n") || "当前没有 evidence。", "info");
					break;
				case "complete": {
					if (!activeGoal) {
						ctx.ui.notify("当前没有 active goal。", "error");
						return;
					}
					const check = canCompleteGoal(activeGoal);
					if (!check.ok) {
						ctx.ui.notify(`goal 不能完成：${check.reason}`, "error");
						return;
					}
					activeGoal.status = "complete";
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					ctx.ui.setStatus("mhb-goal", "mhb:complete");
					ctx.ui.notify("goal 已标记 complete。", "success");
					break;
				}
				case "block": {
					if (!activeGoal) {
						ctx.ui.notify("当前没有 active goal。", "error");
						return;
					}
					activeGoal.status = "blocked";
					activeGoal.blockedReason = rest.trim() || "未提供阻塞原因";
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					ctx.ui.setStatus("mhb-goal", "mhb:blocked");
					ctx.ui.notify("goal 已标记 blocked。", "warning");
					break;
				}
				case "clear":
					saveGoal(pi, undefined);
					ctx.ui.setStatus("mhb-goal", undefined);
					ctx.ui.notify("goal 已清空。", "success");
					break;
				default:
					ctx.ui.notify("用法：/mhb-goal status|evidence|complete|block|clear", "error");
			}
		},
	});

	pi.registerTool(defineTool({
		name: "mhb_goal_update",
		label: "MHB Goal Update",
		description: "Update Maohuoban project gate state. Use alongside pi-codex-goal for TDD slice, evidence, acceptance items, and project-specific blocking.",
		promptSnippet: "Record Maohuoban goal progress, TDD evidence, and completion checks",
		promptGuidelines: [
			"Use create_goal/get_goal/update_goal for the durable Codex-style objective.",
			"Use mhb_goal_update before and after each TDD slice.",
			"Maintain the TODO wiki path returned by mhb_goal_update as the visible execution ledger.",
			"Call advisor before major production edits, before completing an acceptance item, and before completing the goal; record advisor guidance as advisor-review evidence.",
			"Record failing-test evidence before production code edits.",
			"Only allow update_goal completion after project gate evidence covers all required acceptance items.",
		],
		parameters: GoalUpdateParams,
		async execute(_toolCallId, params) {
			switch (params.action) {
				case "status":
					return { content: [{ type: "text", text: renderGoal(activeGoal) }], details: activeGoal ?? null };
				case "start_goal": {
					const seed = params.source || params.objective;
					if (!seed) {
						return { content: [{ type: "text", text: "Error: source or objective required." }], details: activeGoal ?? null };
					}
					const goal = createGoalFromSource(seed, params.objective);
					saveGoal(pi, goal);
					return { content: [{ type: "text", text: `Started goal with ${goal.acceptanceItems.length} acceptance items.` }], details: goal };
				}
				case "set_current_slice": {
					if (!activeGoal) return { content: [{ type: "text", text: "Error: no active goal." }], details: null };
					if (!params.currentSlice) return { content: [{ type: "text", text: "Error: currentSlice required." }], details: activeGoal };
					activeGoal.currentSlice = params.currentSlice;
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					return { content: [{ type: "text", text: `Current slice set: ${params.currentSlice}` }], details: activeGoal };
				}
				case "start_item": {
					if (!activeGoal) return { content: [{ type: "text", text: "Error: no active goal." }], details: null };
					const item = findItem(activeGoal, params.itemId, params.itemText);
					if (!item) return { content: [{ type: "text", text: "Error: acceptance item not found." }], details: activeGoal };
					item.status = "in_progress";
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					return { content: [{ type: "text", text: `Item in progress: ${item.id}` }], details: activeGoal };
				}
				case "complete_item": {
					if (!activeGoal) return { content: [{ type: "text", text: "Error: no active goal." }], details: null };
					const item = findItem(activeGoal, params.itemId, params.itemText);
					if (!item) return { content: [{ type: "text", text: "Error: acceptance item not found." }], details: activeGoal };
					item.status = "done";
					if (params.evidenceText) {
						item.evidence.push(params.evidenceText);
						addEvidence(activeGoal, "note", params.evidenceText, params.command);
					}
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					return { content: [{ type: "text", text: `Item completed: ${item.id}` }], details: activeGoal };
				}
				case "add_evidence": {
					if (!activeGoal) return { content: [{ type: "text", text: "Error: no active goal." }], details: null };
					if (!params.evidenceKind || !params.evidenceText) {
						return { content: [{ type: "text", text: "Error: evidenceKind and evidenceText required." }], details: activeGoal };
					}
					addEvidence(activeGoal, params.evidenceKind as EvidenceKind, params.evidenceText, params.command);
					saveGoal(pi, activeGoal);
					return { content: [{ type: "text", text: `Evidence recorded: ${params.evidenceKind}` }], details: activeGoal };
				}
				case "complete_goal": {
					if (!activeGoal) return { content: [{ type: "text", text: "Error: no active goal." }], details: null };
					const check = canCompleteGoal(activeGoal);
					if (!check.ok) {
						return { content: [{ type: "text", text: `Cannot complete goal: ${check.reason}` }], details: activeGoal };
					}
					activeGoal.status = "complete";
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					return { content: [{ type: "text", text: "Goal completed." }], details: activeGoal };
				}
				case "block_goal": {
					if (!activeGoal) return { content: [{ type: "text", text: "Error: no active goal." }], details: null };
					activeGoal.status = "blocked";
					activeGoal.blockedReason = params.reason || "未提供阻塞原因";
					activeGoal.updatedAt = nowIso();
					saveGoal(pi, activeGoal);
					return { content: [{ type: "text", text: `Goal blocked: ${activeGoal.blockedReason}` }], details: activeGoal };
				}
				case "clear_goal":
					saveGoal(pi, undefined);
					return { content: [{ type: "text", text: "Goal cleared." }], details: null };
			}
		},
	}));
}

// splitFirst 拆分命令参数
// 核心职责：
// - 获取一级子命令
// - 保留后续原始参数
function splitFirst(value: string): [string, string] {
	const trimmed = value.trim();
	const index = trimmed.search(/\s/);
	if (index < 0) {
		return [trimmed, ""];
	}
	return [trimmed.slice(0, index), trimmed.slice(index + 1)];
}
