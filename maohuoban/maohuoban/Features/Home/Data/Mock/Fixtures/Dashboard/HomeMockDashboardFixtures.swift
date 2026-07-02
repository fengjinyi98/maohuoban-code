import Foundation

// HomeMockDashboardFixtures 首页 Mock 快照工厂
// 核心职责：
// - 集中维护首页 UI 开发阶段的样例数据
// - 输出与后端聚合接口一致的 HomeDashboardSnapshot
enum HomeMockDashboardFixtures {
    static func snapshot(
        scenario: HomeMockScenario,
        selectedPetID: String?
    ) -> HomeDashboardSnapshot {
        switch scenario {
        case .petOwner:
            petOwnerSnapshot(selectedPetID: selectedPetID)
        case .newUser:
            newUserSnapshot()
        case .merchant:
            merchantSnapshot()
        }
    }
}
