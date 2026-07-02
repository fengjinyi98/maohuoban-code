import SwiftUI
import MaohuobanDesignSystem

// MHBPhotoGridScrollDateBadge 照片网格滚动日期浮层
// 核心职责：
// - 使用 Liquid Glass 展示当前滚动区域的日期
// - 按日期文案自适应容器宽度
struct MHBPhotoGridScrollDateBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MHBTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .frame(height: 28)
            .fixedSize(horizontal: true, vertical: false)
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}
