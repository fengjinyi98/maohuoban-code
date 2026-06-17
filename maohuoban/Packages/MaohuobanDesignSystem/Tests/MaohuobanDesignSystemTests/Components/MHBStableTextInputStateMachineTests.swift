import Testing
@testable import MaohuobanDesignSystem

// MHBStableTextInputStateMachineTests 稳定输入状态机测试
// 核心职责：
// - 验证输入法组合态不会写入业务文本
// - 验证普通删除仍然可以提交空文本
@Suite("MHBStableTextInput 状态机")
struct MHBStableTextInputStateMachineTests {
    @Test("中文输入法组合态与临时空态不会提交业务文本")
    func markedTextAndTransientEmptyAreDeferred() {
        var stateMachine = MHBStableTextInputStateMachine(committedText: "布偶")

        let markedResult = stateMachine.receive(text: "buou", hasMarkedText: true)
        #expect(markedResult.committedText == nil)
        #expect(markedResult.isComposing == true)

        let transientEmptyResult = stateMachine.receive(text: "", hasMarkedText: false)
        #expect(transientEmptyResult.committedText == nil)
        #expect(transientEmptyResult.isComposing == true)

        let committedResult = stateMachine.receive(text: "布偶猫", hasMarkedText: false)
        #expect(committedResult.committedText == "布偶猫")
        #expect(committedResult.isComposing == false)
    }

    @Test("普通删除可以提交空文本")
    func regularDeletionCanCommitEmptyText() {
        var stateMachine = MHBStableTextInputStateMachine(committedText: "布偶")

        let result = stateMachine.receive(text: "", hasMarkedText: false)

        #expect(result.committedText == "")
        #expect(result.isComposing == false)
    }

    @Test("输入限制可以按非空格字符计数并标记越界")
    func inputLimitCountsNonWhitespaceCharacters() {
        let limit = MHBStableTextInputLimit(maxCount: 6, countingRule: .nonWhitespace)

        let validState = limit.state(for: "奶 盖 宝 宝 兔 兔")
        #expect(validState.count == 6)
        #expect(validState.isExceeded == false)

        let exceededState = limit.state(for: "奶 盖 宝 宝 兔 兔 猫")
        #expect(exceededState.count == 7)
        #expect(exceededState.isExceeded == true)
    }
}
