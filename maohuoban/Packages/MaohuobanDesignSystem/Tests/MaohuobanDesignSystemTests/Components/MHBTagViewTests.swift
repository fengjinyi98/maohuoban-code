import Testing
import SwiftUI
@testable import MaohuobanDesignSystem

// MHBTagViewTests 标签组件单元测试
// 核心职责：
// - 验证标签组件各 Style 配色的正确性
// - 验证标签大小尺寸对应的字体与间距
@Suite("MHBTagView 标签组件")
struct MHBTagViewTests {
    @Test("验证不同 Style 的自适应颜色")
    func testTagStyleColors() {
        let primaryColors = MHBTagView<EmptyView>.Style.primary.colors
        #expect(primaryColors.foreground != nil)
        #expect(primaryColors.background != nil)

        let successColors = MHBTagView<EmptyView>.Style.success.colors
        #expect(successColors.foreground != nil)
        #expect(successColors.background != nil)

        let whiteTranslucentColors = MHBTagView<EmptyView>.Style.whiteTranslucent.colors
        #expect(whiteTranslucentColors.foreground == .white.opacity(0.6))
        #expect(whiteTranslucentColors.background == .white.opacity(0.08))

        let customColors = MHBTagView<EmptyView>.Style.custom(foreground: .red, background: .blue).colors
        #expect(customColors.foreground == .red)
        #expect(customColors.background == .blue)
    }

    @Test("验证不同 Size 的布局参数")
    func testTagSizes() {
        let smallSize = MHBTagView<EmptyView>.Size.small
        #expect(smallSize.verticalPadding == 3)
        #expect(smallSize.horizontalPadding == 8)
        #expect(smallSize.iconSpacing == 4)

        let mediumSize = MHBTagView<EmptyView>.Size.medium
        #expect(mediumSize.verticalPadding == 4)
        #expect(mediumSize.horizontalPadding == 10)
        #expect(mediumSize.iconSpacing == 4)
    }
}
