import SwiftUI
import MaohuobanDesignSystem

// MHBBottomFloatingCTA 底部悬浮 CTA 按钮
// 核心职责：
// - 提供跨页面复用的底部悬浮操作入口
// - 自动处理安全区适配和 Liquid Glass 材质
// - 支持导航路由或自定义动作
struct MHBBottomFloatingCTA<Route: Hashable>: View {
    private let config: Configuration
    private let bottomInset: CGFloat
    
    init(
        title: String,
        systemImage: String? = nil,
        route: Route,
        bottomInset: CGFloat = 0
    ) {
        self.config = .navigation(
            title: title,
            systemImage: systemImage,
            route: route
        )
        self.bottomInset = bottomInset
    }
    
    var body: some View {
        Group {
            switch config {
            case let .navigation(title, systemImage, route):
                NavigationLink(value: route) {
                    buttonContent(title: title, systemImage: systemImage)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s5 + bottomInset)
    }
    
    @ViewBuilder
    private func buttonContent(title: String, systemImage: String?) -> some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(MHBTheme.Typography.callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.primary.color, in: Capsule())
        .glassEffect(.regular.interactive(), in: .capsule)
    }
    
    private enum Configuration {
        case navigation(title: String, systemImage: String?, route: Route)
    }
}

// MHBBottomFloatingActionCTA 底部悬浮动作按钮（无路由版本）
// 核心职责：
// - 提供基于闭包动作的底部悬浮按钮
// - 用于非导航场景，例如提交表单、触发弹窗
struct MHBBottomFloatingActionCTA: View {
    private let title: String
    private let systemImage: String?
    private let bottomInset: CGFloat
    private let action: () -> Void
    
    init(
        title: String,
        systemImage: String? = nil,
        bottomInset: CGFloat = 0,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.bottomInset = bottomInset
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(MHBTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.primary.color, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s5 + bottomInset)
    }
}
