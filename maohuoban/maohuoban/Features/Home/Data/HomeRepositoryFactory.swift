import Foundation

// HomeRepositoryFactory 首页仓库工厂
// 核心职责：
// - 根据 Mock 系统开关选择首页数据源
// - 让 Store 和 View 保持对 HomeRepository 协议依赖
enum HomeRepositoryFactory {
    static func makeDefault() -> HomeRepository {
        if MHBMockSystem.isEnabled() {
            return MockHomeRepository()
        }

        return DefaultHomeRepository()
    }
}
