import ActivityKit
import Foundation

// PetWalkActivityAttributes 遛弯实时事件属性
// 核心职责：
// - 为 ActivityKit 提供遛弯实时事件的静态属性和动态状态
// - 统一 App、Widget Extension 和测试使用的展示数据
nonisolated struct PetWalkActivityAttributes: ActivityAttributes, Hashable {
    let sessionID: String

    struct ContentState: Codable, Hashable {
        let petName: String
        let petAvatarURLString: String?
        let status: PetWalkLiveActivityStatus
        let distanceText: String
        let distanceValueText: String
        let distanceUnitText: String
        let elapsedText: String
        let caloriesText: String
        let updatedAt: Date

        var statusText: String {
            status.title
        }

        var compactRotationItems: [PetWalkLiveActivityCompactItem] {
            [
                PetWalkLiveActivityCompactItem(kind: .elapsed, text: elapsedText),
                PetWalkLiveActivityCompactItem(kind: .status, text: statusText),
                PetWalkLiveActivityCompactItem(kind: .distance, text: distanceText)
            ]
        }

        var compactPetAvatarURLString: String? {
            petAvatarURLString
        }

        var compactRotationDirection: PetWalkLiveActivityRotationDirection {
            .up
        }
    }
}

// PetWalkLiveActivityStatus 遛弯实时事件展示状态
// 核心职责：
// - 将遛弯记录状态映射为实时事件文案
// - 为灵动岛紧凑态和展开态提供稳定状态值
nonisolated enum PetWalkLiveActivityStatus: String, Codable, Hashable, Sendable {
    case tracking
    case paused
    case finished

    var title: String {
        switch self {
        case .tracking:
            "正在遛弯"
        case .paused:
            "已暂停"
        case .finished:
            "已结束"
        }
    }
}

// PetWalkLiveActivityCompactItem 灵动岛收起态轮播项
// 核心职责：
// - 描述收起态按时间、状态、距离切换的内容
// - 为 Widget UI 提供稳定 identity
nonisolated struct PetWalkLiveActivityCompactItem: Codable, Hashable, Identifiable, Sendable {
    let kind: Kind
    let text: String

    var id: Kind {
        kind
    }

    enum Kind: String, Codable, Hashable, Sendable {
        case elapsed
        case status
        case distance
    }
}

// PetWalkLiveActivityRotationDirection 灵动岛收起态轮播方向
// 核心职责：
// - 表达文字切换时的滚动方向
// - 让展示模型和 SwiftUI 动画配置保持一致
nonisolated enum PetWalkLiveActivityRotationDirection: String, Codable, Hashable, Sendable {
    case up
}

// PetWalkLiveActivityFormatters 遛弯实时事件格式化器
// 核心职责：
// - 统一距离、时长和千卡展示格式
// - 避免 Widget 与 App 各自维护文案规则
nonisolated enum PetWalkLiveActivityFormatters {
    static func distanceText(from kilometers: Double) -> String {
        "\(String(format: "%.2f", max(0, kilometers))) 公里"
    }

    static func distanceValueText(from kilometers: Double) -> String {
        String(format: "%.2f", max(0, kilometers))
    }

    static var distanceUnitText: String {
        "公里"
    }

    static func elapsedText(from seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func caloriesText(from calories: Int) -> String {
        "\(max(0, calories)) 千卡"
    }
}
