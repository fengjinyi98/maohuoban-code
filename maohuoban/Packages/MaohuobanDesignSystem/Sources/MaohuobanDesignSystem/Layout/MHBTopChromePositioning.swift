import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBTopChromePositionResolver 顶部自定义 chrome 定位解析器
// 核心职责：
// - 为自定义顶部栏提供统一的顶部避让真值
// - 在 overlay / 全屏容器里用 window safe area 兜底 geometry 安全区失真
// - 让业务页复用同一套顶部定位规则，避免重复调整魔法值
public enum MHBTopChromePositionResolver {
    @MainActor
    public static func resolvedTopInset(geometrySafeAreaTop: CGFloat) -> CGFloat {
#if canImport(UIKit)
        let windowSafeAreaTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        return max(geometrySafeAreaTop, windowSafeAreaTop)
#else
        geometrySafeAreaTop
#endif
    }
}

// MHBTopChromeAlignedModifier 顶部自定义 chrome 对齐修饰器
// 核心职责：
// - 统一把自定义顶部栏吸附到系统顶部安全区基线
// - 只处理位置，不处理字号、按钮尺寸、材质等样式
private struct MHBTopChromeAlignedModifier: ViewModifier {
    let geometrySafeAreaTop: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.top, MHBTopChromePositionResolver.resolvedTopInset(geometrySafeAreaTop: geometrySafeAreaTop))
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

public extension View {
    // mhbTopChromeAligned 顶部自定义 chrome 统一定位入口
    // 核心职责：
    // - 让业务页直接复用统一顶部定位规则
    // - 避免在页面里手写 safeArea / window inset / 魔法值
    func mhbTopChromeAligned(geometrySafeAreaTop: CGFloat) -> some View {
        modifier(MHBTopChromeAlignedModifier(geometrySafeAreaTop: geometrySafeAreaTop))
    }
}
