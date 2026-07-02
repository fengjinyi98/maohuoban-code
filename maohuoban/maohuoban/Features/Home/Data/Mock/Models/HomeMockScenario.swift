import Foundation

// HomeMockScenario 首页 Mock 场景
// 核心职责：
// - 定义首页 UI 开发阶段可切换的数据场景
// - 隔离启动参数与具体 Mock 快照构造
enum HomeMockScenario: String {
    case petOwner = "pet-owner"
    case newUser = "new-user"
    case merchant

    static func current() -> HomeMockScenario {
        let rawValue = MHBMockSystem.scenario(
            namespace: "home",
            default: HomeMockScenario.petOwner.rawValue
        )
        return HomeMockScenario(rawValue: normalized(rawValue)) ?? .petOwner
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }
}
