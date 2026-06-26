import Foundation

// AIAssistantStore+MockContent AI 助手 mock 内容
// 核心职责：
// - 提供本地对话记录 mock 数据
// - 提供首屏建议问题 mock 数据
extension AIAssistantStore {
    var conversationHistories: [AIAssistantConversationHistory] {
        [
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
                ],
                petAvatarURL: nil,
                petName: "毛球",
                petSpecies: .cat
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
                ],
                petAvatarURL: nil,
                petName: "大黄",
                petSpecies: .dog
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
                ],
                petAvatarURL: nil,
                petName: "毛球",
                petSpecies: .cat
            )
        ]
    }

    var suggestedPrompts: [AIAssistantSuggestedPrompt] {
        [
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
    }
}
