import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityDetailMissingScreen 同城商品详情缺失页面
// 核心职责：
// - 展示无法找到商品详情时的轻量占位
// - 保持系统导航返回能力可用
struct SameCityCommodityDetailMissingScreen: View {
    var body: some View {
        Text("这条同城动态暂时不可查看")
            .font(MHBTheme.Typography.body)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// SameCityCommodityDetailLayout 同城商品详情布局参数
// 核心职责：
// - 收敛商品详情底部栏和 section 间距
// - 保持沉浸式详情页面底部内容不被操作栏遮挡
enum SameCityCommodityDetailLayout {
    static let contentHorizontalPadding: CGFloat = MHBTheme.Spacing.s5
    static let sectionSpacing: CGFloat = MHBTheme.Spacing.s6
    static let dividerHorizontalPadding: CGFloat = MHBTheme.Spacing.s5
    static let bottomPrimaryButtonHeight: CGFloat = 44
    static let bottomBarTopPadding: CGFloat = MHBTheme.Spacing.s3

    static func bottomBarReservedHeight(bottomSafeArea: CGFloat) -> CGFloat {
        bottomPrimaryButtonHeight + bottomBarTopPadding + bottomSafeArea + MHBTheme.Spacing.s6
    }
}
