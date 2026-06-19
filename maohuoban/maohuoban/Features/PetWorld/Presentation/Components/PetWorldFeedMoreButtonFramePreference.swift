import SwiftUI

// PetWorldFeedCoordinateSpace 宠物世界 Feed 坐标空间
// 核心职责：
// - 为 Feed 内浮动菜单锚点测量提供统一命名空间
// - 保持按钮 frame 与列表覆盖层使用同一套坐标
enum PetWorldFeedCoordinateSpace {
    static let name = "PetWorldFeedList"
}

// PetWorldFeedMoreButtonFramePreferenceKey 更多按钮位置偏好
// 核心职责：
// - 收集每张 Feed 卡片更多按钮在列表坐标中的 frame
// - 为自定义浮动菜单提供定位锚点
struct PetWorldFeedMoreButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(
        value: inout [String: CGRect],
        nextValue: () -> [String: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    // petWorldFeedMoreButtonFrame 记录 Feed 更多按钮位置
    // 核心职责：
    // - 在不改变按钮布局的前提下写入 frame 偏好
    // - 让列表层统一承载弹出菜单展示
    func petWorldFeedMoreButtonFrame(cardID: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PetWorldFeedMoreButtonFramePreferenceKey.self,
                    value: [cardID: proxy.frame(in: .named(PetWorldFeedCoordinateSpace.name))]
                )
            }
        }
    }
}
