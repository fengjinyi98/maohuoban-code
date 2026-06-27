import Foundation

// AIAssistantStore+MockContent AI 助手建议问题
// 核心职责：
// - 提供首屏建议问题数据
extension AIAssistantStore {
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
