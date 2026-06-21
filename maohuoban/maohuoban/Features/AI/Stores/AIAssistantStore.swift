import Foundation
import UIKit

// AIAssistantStore AI 助手本地状态容器
// 核心职责：
// - 管理前端对话消息、输入草稿和待确认动作
// - 管理系统相机、相册入口和本地附件摘要
@MainActor
@Observable
final class AIAssistantStore {
    let context: AIAssistantEntryContext
    var draftText = ""
    var messages: [AIAssistantMessage]
    var pendingAction: AIAssistantProposedAction?
    var presentedAttachmentSource: AIAssistantAttachmentSource?
    var selectedAttachment: AIAssistantSelectedAttachment?
    var selectedAttachmentImage: UIImage?
    var selectedConversationHistoryID: String?
    var currentConversationTitle: String?

    let conversationHistories: [AIAssistantConversationHistory] = [
        AIAssistantConversationHistory(
            id: "today-vaccine",
            title: "疫苗和驱虫提醒",
            subtitle: "今天",
            messages: [
                AIAssistantMessage(
                    role: .user,
                    text: "毛球，下一次疫苗和驱虫分别是什么时候？"
                ),
                AIAssistantMessage(
                    role: .assistant,
                    text: "按当前档案的 mock 数据看，年度疫苗建议在 2026-08-20 前后完成；体内外驱虫建议按最近一次记录向后推 30 天，并在前一周提醒。",
                    referenceChips: ["疫苗记录", "驱虫周期", "提醒计划"]
                )
            ]
        ),
        AIAssistantConversationHistory(
            id: "health-triage",
            title: "腹泻观察建议",
            subtitle: "昨天",
            messages: [
                AIAssistantMessage(
                    role: .user,
                    text: "今天有点拉肚子，需要马上去医院吗？"
                ),
                AIAssistantMessage(
                    role: .assistant,
                    text: "先看精神、食欲、饮水、呕吐和便血情况。若精神沉郁、持续呕吐、便血、幼宠或超过 24 小时未缓解，建议尽快就医；症状轻微时可先记录并观察。",
                    referenceChips: ["红旗症状", "观察时间", "就医建议"]
                ),
                AIAssistantMessage(
                    role: .assistant,
                    text: "我已把这次 mock 分诊保留在对话记录中，后端接入后会关联宠物健康时间线。"
                )
            ]
        ),
        AIAssistantConversationHistory(
            id: "food-review",
            title: "猫粮测评适配分析",
            subtitle: "本周",
            messages: [
                AIAssistantMessage(
                    role: .user,
                    text: "这篇猫粮测评适合我家宠物吗？"
                ),
                AIAssistantMessage(
                    role: .assistant,
                    text: "需要结合年龄、体重、绝育状态、过敏史和当前粮食过渡情况判断。当前 mock 结论是：若没有谷物或鸡肉过敏，可先少量过渡，并观察软便和抓挠情况。",
                    referenceChips: ["UGC 上下文", "过敏史", "换粮观察"]
                )
            ]
        )
    ]

    let suggestedPrompts: [AIAssistantSuggestedPrompt] = [
        AIAssistantSuggestedPrompt(
            id: "vaccine",
            title: "下一次疫苗",
            subtitle: "什么时候",
            prompt: "下一次疫苗是什么时候？",
            systemImage: "syringe.fill"
        ),
        AIAssistantSuggestedPrompt(
            id: "health",
            title: "腹泻要就医吗",
            subtitle: "帮我判断",
            prompt: "今天有点拉肚子，需要去医院吗？",
            systemImage: "cross.case.fill"
        ),
        AIAssistantSuggestedPrompt(
            id: "ugc",
            title: "测评是否适合",
            subtitle: "结合档案",
            prompt: "这篇猫粮测评适合我家宠物吗？",
            systemImage: "doc.text.magnifyingglass"
        )
    ]

    init(context: AIAssistantEntryContext) {
        self.context = context
        self.messages = []
    }

    var canSendDraft: Bool {
        sanitizedDraft.isEmpty == false
    }

    var navigationTitle: String {
        currentConversationTitle ?? "新对话"
    }

    var navigationSubtitle: String? {
        currentConversationTitle == nil ? "内容由毛球 AI 生成" : nil
    }

    var shouldShowSuggestedPrompts: Bool {
        messages.isEmpty && currentConversationTitle == nil
    }

    var conversationHistoryNavigationTitle: String {
        "\(context.displayPetName)的对话记录"
    }

    func submitDraft() {
        let prompt = sanitizedDraft
        guard prompt.isEmpty == false else {
            return
        }

        draftText = ""
        send(prompt)
    }

    func sendSuggestedPrompt(_ prompt: AIAssistantSuggestedPrompt) {
        send(prompt.prompt)
    }

    func requestAttachmentSource(_ source: AIAssistantAttachmentSource) {
        presentedAttachmentSource = source
    }

    func cancelAttachmentSelection() {
        presentedAttachmentSource = nil
    }

    func completeAttachmentSelection(
        source: AIAssistantAttachmentSource,
        image: UIImage
    ) {
        presentedAttachmentSource = nil
        selectedAttachmentImage = image
        selectedAttachment = AIAssistantSelectedAttachment(
            source: source,
            title: "已添加 1 张图片"
        )
    }

    func clearAttachment() {
        selectedAttachment = nil
        selectedAttachmentImage = nil
        presentedAttachmentSource = nil
    }

    func selectConversationHistory(_ history: AIAssistantConversationHistory) {
        selectedConversationHistoryID = history.id
        currentConversationTitle = history.title
        draftText = ""
        pendingAction = nil
        clearAttachment()
        messages = history.messages
    }

    func confirmPendingAction() {
        guard let pendingAction else {
            return
        }

        messages.append(
            AIAssistantMessage(
                role: .user,
                text: pendingAction.confirmTitle
            )
        )
        messages.append(
            AIAssistantMessage(
                role: .assistant,
                text: "已保留这次确认状态。后端写入接口接入后，这里会创建对应提醒或宠物事件，并生成审计记录。",
                referenceChips: ["待接入后端动作"]
            )
        )
        self.pendingAction = nil
    }

    func cancelPendingAction() {
        pendingAction = nil
        messages.append(
            AIAssistantMessage(
                role: .assistant,
                text: "已取消这次建议动作，对话记录会继续保留。"
            )
        )
    }

    private var sanitizedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send(_ text: String) {
        if currentConversationTitle == nil {
            currentConversationTitle = makeConversationTitle(from: text)
        }

        messages.append(
            AIAssistantMessage(
                role: .user,
                text: text
            )
        )
        clearAttachment()

        let response = responseMessage(for: text)
        messages.append(response.message)
        pendingAction = response.action
    }

    private func makeConversationTitle(from text: String) -> String {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 18 else {
            return title
        }

        return "\(title.prefix(18))..."
    }

    private func responseMessage(for text: String) -> (message: AIAssistantMessage, action: AIAssistantProposedAction?) {
        if text.contains("疫苗") {
            return vaccineResponse()
        }

        if text.contains("拉肚子") || text.contains("腹泻") || text.contains("医院") {
            return healthTriageResponse()
        }

        if text.contains("测评") || text.contains("猫粮") || text.contains("适合") {
            return ugcHandoffResponse()
        }

        return generalResponse()
    }

    private func vaccineResponse() -> (message: AIAssistantMessage, action: AIAssistantProposedAction?) {
        let petName = context.displayPetName
        return (
            AIAssistantMessage(
                role: .assistant,
                text: "\(petName) 的疫苗问题需要读取未来提醒和最近疫苗事件。当前前端先展示结果形态：若最近狂犬疫苗记录为 2025-08-20，下一次可推算到 2026-08-20，并提示用户确认添加提醒。",
                referenceChips: ["疫苗记录", "提醒查询", "年度加强推算"]
            ),
            AIAssistantProposedAction(
                id: "add-vaccine-reminder",
                title: "添加疫苗提醒",
                subtitle: "为 \(petName) 添加 2026-08-20 狂犬疫苗提醒",
                confirmTitle: "添加提醒",
                cancelTitle: "暂不添加",
                systemImage: "calendar.badge.plus"
            )
        )
    }

    private func healthTriageResponse() -> (message: AIAssistantMessage, action: AIAssistantProposedAction?) {
        let petName = context.displayPetName
        return (
            AIAssistantMessage(
                role: .assistant,
                text: "\(petName) 腹泻需要结合精神状态、便血、呕吐、饮水、年龄和持续时间判断。若出现便血、频繁呕吐、精神沉郁、脱水或幼宠状态，应尽快就医；症状轻微且少于 24 小时，可先记录症状并观察变化。",
                referenceChips: ["健康分级", "红旗症状", "时间线记录"]
            ),
            AIAssistantProposedAction(
                id: "record-symptom",
                title: "记录症状",
                subtitle: "把这次腹泻情况加入 \(petName) 时间线",
                confirmTitle: "记录到时间线",
                cancelTitle: "先观察",
                systemImage: "waveform.path.ecg"
            )
        )
    }

    private func ugcHandoffResponse() -> (message: AIAssistantMessage, action: AIAssistantProposedAction?) {
        let title = context.ugcContextTitle ?? "这篇内容"
        return (
            AIAssistantMessage(
                role: .assistant,
                text: "个体适配需要进入私域宠物助手后结合 \(context.displayPetName) 的档案、过敏史和喂养记录判断。当前已展示前端交接形态：顶部会带入“\(title)”，后端接入后将通过 ugc_id 重新读取可见内容。",
                referenceChips: ["UGC 上下文", "私域宠物判断"]
            ),
            nil
        )
    }

    private func generalResponse() -> (message: AIAssistantMessage, action: AIAssistantProposedAction?) {
        (
            AIAssistantMessage(
                role: .assistant,
                text: "我会按私域宠物助手的边界处理：先确认问题类型，再读取授权范围内的宠物事实，最后给出带来源的回答和需要确认的动作。",
                referenceChips: ["意图识别", "受控工具", "来源校验"]
            ),
            nil
        )
    }
}
