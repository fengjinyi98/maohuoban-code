import SwiftUI

// MHBScreenScrollView 普通页面纵向滚动容器
// 核心职责：
// - 为普通页面提供统一的纵向 ScrollView 入口
// - 默认使用柔和滚动边缘效果，保持 iOS 26 风格体验
struct MHBScreenScrollView<Content: View>: View {
    let showsIndicators: Bool
    @ViewBuilder let content: () -> Content

    init(
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showsIndicators) {
            content()
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
