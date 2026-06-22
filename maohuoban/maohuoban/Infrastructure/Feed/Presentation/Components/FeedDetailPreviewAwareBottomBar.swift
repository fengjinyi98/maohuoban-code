import SwiftUI
import MaohuobanDesignSystem

// FeedDetailPreviewAwareBottomBar Feed 详情底部栏预览态保护容器
// 核心职责：
// - 在大图预览打开时隐藏业务底部操作栏
// - 避免页面内 overlay 穿透到图片预览层
struct FeedDetailPreviewAwareBottomBar<Content: View>: View {
    @Environment(\.mhbImagePreviewPresenting) private var isImagePreviewPresenting

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(isImagePreviewPresenting ? 0 : 1)
            .allowsHitTesting(!isImagePreviewPresenting)
    }
}
