import XCTest
@testable import maohuoban

// AIAssistantStoreRuntimeAdapterTests AI runtime adapter 状态测试
// 核心职责：
// - 验证 Store 消费后端稳定 SSE 工具态和确认态
// - 验证 Provider error 后恢复发送入口
@MainActor
final class AIAssistantStoreRuntimeAdapterTests: XCTestCase {

    func testErrorEventRestoresDraftSendAvailability() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: Self.errorEvents())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)
        store.draftText = "继续提问"

        XCTAssertFalse(store.isStreaming)
        XCTAssertTrue(store.canSendDraft)
    }

    func testConfirmationEventExposesAssistantStatus() async {
        let taskID = UUID()
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: Self.confirmationEvents(taskID: taskID))
        )
        store.draftText = "帮我确认换粮"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.pendingConfirmationTask?.id, taskID.uuidString)
        XCTAssertEqual(store.pendingConfirmationTask?.questionText, "是否确认把毛球的主粮改为鸡肉配方？")
        XCTAssertEqual(store.pendingConfirmationTask?.preview.note, "精神好转，食欲仍减少")
        XCTAssertEqual(store.pendingConfirmationTask?.actions.map(\.kind), ["approve", "reject"])
        XCTAssertFalse(store.isStreaming)
    }

    func testConfirmPendingConfirmationTaskStreamsBackendAssistantReply() async {
        let taskID = UUID()
        let repository = RuntimeAdapterTestRepository(streamEvents: [
            .messageCompleted(
                messageID: UUID(),
                finalText: "已把这次异常更新写入进展时间线。",
                referenceChips: [],
                references: [],
                contentBlocks: []
            )
        ])
        let store = AIAssistantStore(context: AIAssistantEntryContext(), repository: repository)
        store.pendingConfirmationTask = Self.pendingConfirmationTask(id: taskID)

        store.confirmPendingConfirmationTask()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(repository.approvalStreamTaskIDs, [taskID.uuidString])
        XCTAssertTrue(repository.approvedConfirmationTaskIDs.isEmpty)
        XCTAssertTrue(repository.streamConfirmationTaskIDs.isEmpty)
        XCTAssertNil(store.pendingConfirmationTask)
        XCTAssertFalse(store.messages.contains { $0.role == .user && $0.text == "确认写入" })
        XCTAssertEqual(store.messages.last?.role, .assistant)
        XCTAssertEqual(store.messages.last?.text, "已把这次异常更新写入进展时间线。")
    }

    func testRejectPendingConfirmationTaskCallsRepositoryAndClearsTask() async {
        let taskID = UUID()
        let repository = RuntimeAdapterTestRepository(streamEvents: [])
        let store = AIAssistantStore(context: AIAssistantEntryContext(), repository: repository)
        store.pendingConfirmationTask = Self.pendingConfirmationTask(id: taskID)

        store.rejectPendingConfirmationTask()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(repository.rejectedConfirmationTaskIDs, [taskID.uuidString])
        XCTAssertNil(store.pendingConfirmationTask)
        XCTAssertEqual(store.messages.last?.text, "已取消这条记录。")
    }

    func testAgentActivityUsesBackendTextAndClearsWhenCompleted() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(
            .agentActivity(displayText: "正在查看毛球近期饮食", status: "started")
        )
        XCTAssertEqual(store.activeAgentActivityText, "正在查看毛球近期饮食")
        XCTAssertEqual(store.messages.last?.text, "")

        store.handleStreamEvent(
            .agentActivity(displayText: "正在查看毛球近期饮食", status: "completed")
        )
        XCTAssertNil(store.activeAgentActivityText)
        XCTAssertEqual(store.messages.last?.text, "")
    }

    func testAgentActivityClearsWhenAnswerDeltaArrives() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(
            .agentActivity(displayText: "正在查看毛球近期饮食", status: "started")
        )
        XCTAssertEqual(store.activeAgentActivityText, "正在查看毛球近期饮食")

        store.handleStreamEvent(.delta(text: "先观察精神状态"))

        XCTAssertNil(store.activeAgentActivityText)
        XCTAssertEqual(store.messages.last?.text, "先观察精神状态")
    }

    func testAgentActivityDoesNotParsePetProfileText() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(
            .agentActivity(displayText: "正在整理梅录的宠物档案", status: "started")
        )

        XCTAssertEqual(store.activeAgentActivityText, "正在整理梅录的宠物档案")
        XCTAssertTrue(store.messages.last?.contentBlocks.isEmpty == true)
    }

    func testContentBlockDeltaAppliesBackendHeadingAndSkeleton() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(.contentBlockDelta(contentBlocks: [
            .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "这是梅录的宠物信息")),
            .petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock(
                id: "loading-1",
                title: "正在整理梅录的宠物档案"
            ))
        ]))

        XCTAssertEqual(store.messages.last?.contentBlocks.count, 2)
        guard case .sectionHeading(let heading) = store.messages.last?.contentBlocks[safe: 0] else {
            XCTFail("第一块应该使用后端标题块")
            return
        }
        XCTAssertEqual(heading.id, "heading-1")
        XCTAssertEqual(heading.text, "这是梅录的宠物信息")
        guard case .petProfileCardSkeleton(let block) = store.messages.last?.contentBlocks[safe: 1] else {
            XCTFail("第二块应该使用后端骨架块")
            return
        }
        XCTAssertEqual(block.id, "loading-1")
        XCTAssertEqual(block.title, "正在整理梅录的宠物档案")
    }

    func testPetProfileContentBlockDeltaControlsHeadingBeforeSkeletonOrder() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(.contentBlockDelta(contentBlocks: [
            .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "这是梅录的宠物信息")),
            .petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock(
                id: "loading-1",
                title: "正在整理梅录的宠物档案"
            ))
        ]))

        XCTAssertEqual(store.messages.last?.text, "")
        XCTAssertEqual(store.messages.last?.contentBlocks.count, 2)
        guard case .sectionHeading(let heading) = store.messages.last?.contentBlocks[safe: 0] else {
            XCTFail("第一块应该由后端明确下发标题块")
            return
        }
        XCTAssertEqual(heading.id, "heading-1")
        XCTAssertEqual(heading.text, "这是梅录的宠物信息")
        guard case .petProfileCardSkeleton = store.messages.last?.contentBlocks[safe: 1] else {
            XCTFail("第二块应该由后端明确下发宠物档案骨架")
            return
        }
    }

    func testPetProfileCompletionUsesBackendFinalBlocksWithoutDerivingHeading() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(.contentBlockDelta(contentBlocks: [
            .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "这是梅录的宠物信息")),
            .petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock(
                id: "loading-1",
                title: "正在整理梅录的宠物档案"
            ))
        ]))
        store.handleStreamEvent(.messageCompleted(
            messageID: UUID(),
            finalText: "这是梅录的宠物信息",
            referenceChips: [],
            references: [],
            contentBlocks: [
                .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-2", text: "这是梅录的宠物信息")),
                .petProfileCard(Self.makePetProfileCardBlock(id: "pet-card-1"))
            ]
        ))

        XCTAssertEqual(store.messages.last?.text, "这是梅录的宠物信息")
        XCTAssertEqual(store.messages.last?.contentBlocks.count, 2)
        guard case .sectionHeading(let heading) = store.messages.last?.contentBlocks[safe: 0] else {
            XCTFail("最终资料卡前应该使用后端完成态标题块")
            return
        }
        XCTAssertEqual(heading.id, "heading-2")
        XCTAssertEqual(heading.text, "这是梅录的宠物信息")
        guard case .petProfileCard(let card) = store.messages.last?.contentBlocks[safe: 1] else {
            XCTFail("完成态应该使用后端正式资料卡块")
            return
        }
        XCTAssertEqual(card.id, "pet-card-1")
    }

    func testPetProfileCompletionUsesBackendHeadingAfterActivityFirst() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(
            .agentActivity(displayText: "正在整理梅录的宠物档案", status: "started")
        )
        store.handleStreamEvent(.messageCompleted(
            messageID: UUID(),
            finalText: "这是梅录的宠物信息",
            referenceChips: [],
            references: [],
            contentBlocks: [
                .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "这是梅录的宠物信息")),
                .petProfileCard(Self.makePetProfileCardBlock(id: "pet-card-1"))
            ]
        ))

        XCTAssertEqual(store.messages.last?.contentBlocks.count, 2)
        guard case .sectionHeading(let heading) = store.messages.last?.contentBlocks[safe: 0] else {
            XCTFail("完成后第一块应该是后端正式标题")
            return
        }
        XCTAssertEqual(heading.id, "heading-1")
        XCTAssertEqual(heading.text, "这是梅录的宠物信息")
        guard case .petProfileCard(let card) = store.messages.last?.contentBlocks[safe: 1] else {
            XCTFail("完成后第二块应该是宠物资料卡")
            return
        }
        XCTAssertEqual(card.id, "pet-card-1")
    }

    private static func makeStoreWithStreamingPlaceholder() -> AIAssistantStore {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: [])
        )
        store.ensureStreamingPlaceholderExists()
        return store
    }

    private static func errorEvents() -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "新对话"),
            .error(
                code: "ai.provider_not_configured",
                message: "AI 服务未配置",
                retryable: false,
                safeFallbackText: "AI 服务暂时不可用，请稍后重试。"
            ),
        ]
    }

    private static func confirmationEvents(taskID: UUID = UUID()) -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "换粮确认"),
            .agentActivity(displayText: "正在查看毛球待确认喂食记录", status: "completed"),
            .confirmationTask(
                taskID: taskID,
                questionText: "是否确认把毛球的主粮改为鸡肉配方？",
                preview: AIStreamConfirmationTaskPreviewPayload(
                    title: "准备记录一条观察",
                    eventSubkind: "agent_observation_note",
                    note: "精神好转，食欲仍减少",
                    sourceLabel: "毛球更新"
                ),
                actions: [
                    AIStreamConfirmationTaskActionPayload(kind: "approve", label: "确认写入"),
                    AIStreamConfirmationTaskActionPayload(kind: "reject", label: "取消")
                ]
            ),
            .messageCompleted(
                messageID: UUID(),
                finalText: "需要你确认后再记录。",
                referenceChips: [],
                references: []
            ),
        ]
    }

    private static func makePetProfileCardBlock(id: String) -> AIAssistantPetProfileCardBlock {
        AIAssistantPetProfileCardBlock(
            id: id,
            pet: AIAssistantPetProfileFact(
                id: "pet-1",
                name: "梅录",
                species: .cat,
                speciesText: "猫",
                sex: .female,
                sexText: "女生",
                breed: "银渐层",
                avatarURL: nil,
                birthDate: "2024-06-17",
                arrivalDate: "2024-09-01"
            ),
            computed: AIAssistantPetProfileComputed(
                ageText: "2岁15天",
                companionshipText: "1年10个月"
            ),
            narrative: AIAssistantPetProfileNarrative(
                birth: "梅录已经2岁15天啦。",
                arrival: "它来到你身边1年10个月了。"
            )
        )
    }

    private static func pendingConfirmationTask(id: UUID) -> PendingConfirmationTask {
        PendingConfirmationTask(
            id: id.uuidString,
            questionText: "是否确认写入这条观察？",
            preview: PendingConfirmationTaskPreview(
                title: "准备记录一条观察",
                eventSubkind: "agent_observation_note",
                note: "精神好转，食欲仍减少",
                sourceLabel: "毛球更新"
            ),
            actions: [
                PendingConfirmationTaskAction(kind: "approve", label: "确认写入"),
                PendingConfirmationTaskAction(kind: "reject", label: "取消")
            ]
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
