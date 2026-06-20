import Foundation

// PublishEntryContext 发布入口上下文
// 核心职责：
// - 承载不同 Tab 进入发布页时的预填信息
// - 为系统导航 route 提供稳定 Hashable 参数
struct PublishEntryContext: Hashable, Sendable {
    let source: PublishEntrySource
    let selectedPetID: String?
    let selectedPetName: String?
    let city: String?
    let localEntityID: String?
    let localEntityName: String?
    let seedTopicID: String?
    let seedTopicName: String?

    init(
        source: PublishEntrySource,
        selectedPetID: String? = nil,
        selectedPetName: String? = nil,
        city: String? = nil,
        localEntityID: String? = nil,
        localEntityName: String? = nil,
        seedTopicID: String? = nil,
        seedTopicName: String? = nil
    ) {
        self.source = source
        self.selectedPetID = selectedPetID
        self.selectedPetName = selectedPetName
        self.city = city
        self.localEntityID = localEntityID
        self.localEntityName = localEntityName
        self.seedTopicID = seedTopicID
        self.seedTopicName = seedTopicName
    }
}

// PublishEntrySource 发布入口来源
// 核心职责：
// - 标识发布页由哪个业务 Tab 或实体入口打开
// - 为发布页选择默认事件类型和上下文提示
enum PublishEntrySource: String, Hashable, Sendable {
    case home
    case petWorld
    case sameCity
    case profile

    var defaultEventType: PublishEventType {
        switch self {
        case .home, .petWorld, .profile:
            .daily
        case .sameCity:
            .sameCity
        }
    }
}
