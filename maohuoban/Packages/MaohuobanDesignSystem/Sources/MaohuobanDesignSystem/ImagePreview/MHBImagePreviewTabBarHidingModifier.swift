import SwiftUI

// MHBImagePreviewTabBarHidingModifier 大图预览期间 TabBar 隐藏修饰器
// 核心职责：
// - 消费 mhbImagePreviewPresenting 环境值，预览态显式把 TabBar 置为 hidden
// - 合并可选的额外隐藏条件（如根栈 push 深层），避免多次 `.toolbar(...for: .tabBar)` 覆盖
// 使用场景：
// - 所有持有 NavigationStack 的 Tab 根页面必须挂这个修饰器
// - 否则 mhbImagePreviewHost 的 overlay 盖不住 TabView 的 TabBar
public struct MHBImagePreviewTabBarHidingModifier: ViewModifier {
    @Environment(\.mhbImagePreviewPresenting) private var isImagePreviewPresenting
    private let additionalHideCondition: Bool

    public init(additionalHideCondition: Bool = false) {
        self.additionalHideCondition = additionalHideCondition
    }

    public func body(content: Content) -> some View {
        content.toolbar(
            (isImagePreviewPresenting || additionalHideCondition) ? .hidden : .visible,
            for: .tabBar
        )
    }
}

public extension View {
    // mhbHidesTabBarDuringImagePreview Tab 根页面 TabBar 预览态隐藏
    // 核心职责：
    // - 为 Tab 根页面提供统一的预览态 TabBar 隐藏入口
    // - 可选通过 additionalHideCondition 合并页面自身的额外隐藏条件（OR 关系）
    func mhbHidesTabBarDuringImagePreview(additionalHideCondition: Bool = false) -> some View {
        modifier(MHBImagePreviewTabBarHidingModifier(additionalHideCondition: additionalHideCondition))
    }
}
