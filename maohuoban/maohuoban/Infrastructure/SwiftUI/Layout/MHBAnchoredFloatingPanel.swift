import SwiftUI

// MHBAnchoredFloatingPanel 锚点浮动面板
// 核心职责：
// - 统一浮动菜单从触发按钮锚点展开与收起的转场
// - 让业务菜单只关注面板内容和自身布局
struct MHBAnchoredFloatingPanel<Content: View>: View {
    let isPresented: Bool
    let offset: CGSize
    let scale: CGFloat
    let scaleAnchor: UnitPoint
    let content: () -> Content

    init(
        isPresented: Bool,
        offset: CGSize,
        scale: CGFloat = 0.82,
        scaleAnchor: UnitPoint,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isPresented = isPresented
        self.offset = offset
        self.scale = scale
        self.scaleAnchor = scaleAnchor
        self.content = content
    }

    var body: some View {
        if isPresented {
            content()
                .offset(offset)
                .transition(.scale(scale: scale, anchor: scaleAnchor).combined(with: .opacity))
        }
    }
}
