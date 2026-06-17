import Foundation

// MHBStableTextInputCommitResult 稳定输入提交结果
// 核心职责：
// - 表达输入事件是否产出可写入业务状态的稳定文本
// - 表达当前输入法是否仍处于组合态
struct MHBStableTextInputCommitResult: Equatable {
    let committedText: String?
    let isComposing: Bool
}

// MHBStableTextInputStateMachine 输入法组合态状态机
// 核心职责：
// - 过滤中文输入法 marked text 与提交前短暂空态
// - 保留普通输入和普通删除的即时提交能力
struct MHBStableTextInputStateMachine {
    private(set) var committedText: String
    private var isWaitingForPostMarkedCommit = false

    init(committedText: String) {
        self.committedText = committedText
    }

    mutating func receive(text: String, hasMarkedText: Bool) -> MHBStableTextInputCommitResult {
        if hasMarkedText {
            isWaitingForPostMarkedCommit = true
            return MHBStableTextInputCommitResult(committedText: nil, isComposing: true)
        }

        if isWaitingForPostMarkedCommit && text.isEmpty {
            return MHBStableTextInputCommitResult(committedText: nil, isComposing: true)
        }

        isWaitingForPostMarkedCommit = false
        guard text != committedText else {
            return MHBStableTextInputCommitResult(committedText: nil, isComposing: false)
        }

        committedText = text
        return MHBStableTextInputCommitResult(committedText: text, isComposing: false)
    }

    mutating func forceCommit(text: String) -> MHBStableTextInputCommitResult {
        isWaitingForPostMarkedCommit = false
        guard text != committedText else {
            return MHBStableTextInputCommitResult(committedText: nil, isComposing: false)
        }

        committedText = text
        return MHBStableTextInputCommitResult(committedText: text, isComposing: false)
    }

    mutating func syncCommittedText(_ text: String) {
        committedText = text
        isWaitingForPostMarkedCommit = false
    }
}
