import XCTest
@testable import maohuoban

// HomeDashboardStoreTests 首页 Store 测试
// 核心职责：
// - 验证首页加载状态流
// - 固化当前用户上下文传递到 Repository 的行为
final class HomeDashboardStoreTests: XCTestCase {
    @MainActor
    func testLoadTransitionsFromLoadingToLoaded() async throws {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(selectedPetID: "pet-1")
        let repository = DelayedHomeRepository(
            result: .success(
                MHBAPIResponse(
                    success: true,
                    code: "ok",
                    message: "首页已加载",
                    data: snapshot
                )
            )
        )
        let store = HomeDashboardStore(repository: repository)

        let task = Task {
            await store.load(currentUserID: "user-1")
        }
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(store.phase, .loading)
        await task.value
        XCTAssertEqual(store.phase, .loaded(snapshot))
        XCTAssertEqual(repository.receivedUserID, "user-1")
    }

    @MainActor
    func testLoadPassesSelectedPetIDToRepository() async {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(selectedPetID: "pet-2")
        let repository = DelayedHomeRepository(
            result: .success(
                MHBAPIResponse(
                    success: true,
                    code: "ok",
                    message: "首页已加载",
                    data: snapshot
                )
            ),
            delayMilliseconds: 0
        )
        let store = HomeDashboardStore(repository: repository)

        await store.load(currentUserID: "user-1", selectedPetID: "pet-2")

        XCTAssertEqual(repository.receivedUserID, "user-1")
        XCTAssertEqual(repository.receivedSelectedPetID, "pet-2")
        XCTAssertEqual(store.phase, .loaded(snapshot))
    }

    @MainActor
    func testLoadTurnsNilDataIntoFailure() async {
        let repository = DelayedHomeRepository(
            result: .success(
                MHBAPIResponse<HomeDashboardSnapshot>(
                    success: true,
                    code: "ok",
                    message: "首页已加载",
                    data: nil
                )
            )
        )
        let store = HomeDashboardStore(repository: repository)

        await store.load(currentUserID: "user-1")

        XCTAssertEqual(store.phase, .failed("首页数据为空"))
    }

    @MainActor
    func testRepeatedAutomaticLoadForSameContextKeepsLoadedSnapshot() async {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(selectedPetID: "pet-1")
        let repository = ScriptedHomeRepository(
            results: [
                .success(
                    MHBAPIResponse(
                        success: true,
                        code: "ok",
                        message: "首页已加载",
                        data: snapshot
                    )
                ),
                .failure(.transport("offline"))
            ]
        )
        let store = HomeDashboardStore(repository: repository)

        await store.load(currentUserID: "user-1")
        await store.load(currentUserID: "user-1")

        XCTAssertEqual(repository.requestCount, 1)
        XCTAssertEqual(store.phase, .loaded(snapshot))
    }
}

// DelayedHomeRepository 首页测试仓库
// 核心职责：
// - 模拟异步首页请求
// - 记录 Store 传入的当前用户上下文
@MainActor
private final class DelayedHomeRepository: HomeRepository {
    private let result: Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>
    private let delayMilliseconds: UInt64
    private(set) var receivedUserID: String?
    private(set) var receivedSelectedPetID: String?

    init(
        result: Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>,
        delayMilliseconds: UInt64 = 50
    ) {
        self.result = result
        self.delayMilliseconds = delayMilliseconds
    }

    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        receivedUserID = currentUserID
        receivedSelectedPetID = selectedPetID
        do {
            try await Task.sleep(for: .milliseconds(delayMilliseconds))
        } catch {
        }

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

// ScriptedHomeRepository 脚本化首页测试仓库
// 核心职责：
// - 按顺序返回预设首页请求结果
// - 记录首页 Store 实际发起的请求次数
@MainActor
private final class ScriptedHomeRepository: HomeRepository {
    private var results: [Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>]
    private(set) var requestCount = 0

    init(results: [Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>]) {
        self.results = results
    }

    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        requestCount += 1
        let result = results.isEmpty
            ? Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>.failure(.transport("首页测试结果为空"))
            : results.removeFirst()

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

extension HomeDashboardSnapshot {
    // homeTestSnapshot 构造首页测试快照
    // 核心职责：
    // - 为首页 Store 和路由测试提供最小稳定数据
    // - 支持按场景覆盖宠物或商家上下文
    @MainActor
    static func homeTestSnapshot(
        selectedPetID: String? = nil,
        merchantID: String? = nil
    ) -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            identity: Identity(
                kind: merchantID == nil ? .petOwner : .certifiedMerchant,
                displayName: merchantID == nil ? "毛伙伴用户" : "梧桐猫舍",
                city: merchantID == nil ? nil : "成都",
                verificationBadge: merchantID == nil ? nil : "已认证"
            ),
            selectedPet: selectedPetID.map {
                PetHeroSummary(
                    id: $0,
                    name: "糯米",
                    species: .dog,
                    breed: "比熊",
                    sex: .female,
                    ageText: "2岁",
                    statusText: "记录正在形成可信档案",
                    updatedText: "档案已同步",
                    avatarURL: nil,
                    heroImageAssetName: "HomePetHeroMock"
                )
            },
            petSwitcher: [],
            careSummary: nil,
            reminders: [],
            quickActions: [],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: merchantID.map {
                MerchantDashboardSummary(
                    merchantID: $0,
                    merchantName: "梧桐猫舍",
                    statusCounts: [],
                    litters: [],
                    pendingTasks: [],
                    recentEvents: []
                )
            },
            emptyState: nil,
            recommendedContent: []
        )
    }
}
