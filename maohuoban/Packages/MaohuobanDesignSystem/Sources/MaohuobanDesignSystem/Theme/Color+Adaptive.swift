import SwiftUI

// Color 自适应扩展
// 核心职责：
// - 提供 light/dark 双色初始化，通过 UIColor dynamicProvider 实现系统级自动切换
// - 所有 ColorToken 的 color 属性通过此入口获得自适应能力
extension Color {
    /// 创建自适应颜色，自动跟随系统 light/dark 模式切换
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        // macOS 等平台回退到 light
        self = light
        #endif
    }
}
