import UIKit

// MHBColorMetrics 色彩指标工具
// 核心职责：
// - 提供跨页面复用的颜色亮度计算能力
// - 为基于图片主色的界面模式判定提供稳定输入
enum MHBColorMetrics {
    static func relativeLuminance(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 1
        }

        let linearRed = linearizedSRGBComponent(red)
        let linearGreen = linearizedSRGBComponent(green)
        let linearBlue = linearizedSRGBComponent(blue)

        return 0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue
    }

    private static func linearizedSRGBComponent(_ component: CGFloat) -> CGFloat {
        if component <= 0.03928 {
            return component / 12.92
        }

        return pow((component + 0.055) / 1.055, 2.4)
    }
}
