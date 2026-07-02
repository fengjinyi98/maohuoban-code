// MHBSlotTextConfiguration 滚轮文字动画配置
// 核心职责：
// - 定义滚轮文字动画的方向、节奏和中断策略
// - 提供彩色入场所需的固定色和彩虹渐变配置

import UIKit

// MHBSlotTextDirection 字符滚动方向
// 核心职责：
// - 表达新字符从上方或下方进入
// - 为滚动计划生成位移方向
public enum MHBSlotTextDirection: Equatable, Sendable {
    case up
    case down
}

// MHBSlotTextChromaticPalette 彩色渐变配置
// 核心职责：
// - 根据字符索引生成稳定的 HSB 色相
// - 支持短文本按字符做彩虹扫色入场
public struct MHBSlotTextChromaticPalette: Equatable, Sendable {
    public var from: CGFloat
    public var spread: CGFloat
    public var saturation: CGFloat
    public var brightness: CGFloat

    public init(
        from: CGFloat = 0,
        spread: CGFloat = 320,
        saturation: CGFloat = 0.92,
        brightness: CGFloat = 0.60
    ) {
        self.from = from
        self.spread = spread
        self.saturation = saturation
        self.brightness = brightness
    }

    public func color(index: Int, total: Int) -> UIColor {
        let progress = total <= 1 ? 0 : CGFloat(index) / CGFloat(total - 1)
        let hue = (from + progress * spread).truncatingRemainder(dividingBy: 360) / 360

        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            alpha: 1
        )
    }
}

// MHBSlotTextColorStyle 彩色入场样式
// 核心职责：
// - 描述字符入场时的临时颜色来源
// - 允许动画结束后回落到视图原始文字颜色
public enum MHBSlotTextColorStyle {
    case none
    case fixed(UIColor)
    case chromatic(MHBSlotTextChromaticPalette)

    func color(index: Int, total: Int) -> UIColor? {
        switch self {
        case .none:
            return nil
        case let .fixed(color):
            return color
        case let .chromatic(palette):
            return palette.color(index: index, total: total)
        }
    }
}

extension MHBSlotTextColorStyle: Equatable {
    public static func == (lhs: MHBSlotTextColorStyle, rhs: MHBSlotTextColorStyle) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.fixed(lhsColor), .fixed(rhsColor)):
            return lhsColor.isEqual(rhsColor)
        case let (.chromatic(lhsPalette), .chromatic(rhsPalette)):
            return lhsPalette == rhsPalette
        default:
            return false
        }
    }
}

extension MHBSlotTextColorStyle: @unchecked Sendable {}

// MHBSlotTextConfiguration 滚轮文字动画配置
// 核心职责：
// - 对齐 slot-text 参考项目的默认动画参数
// - 为 UIKit 视图提供可复用的动画输入
public struct MHBSlotTextConfiguration: Equatable {
    public var direction: MHBSlotTextDirection
    public var stagger: TimeInterval
    public var duration: TimeInterval
    public var exitOffset: TimeInterval
    public var bounce: CGFloat
    public var colorStyle: MHBSlotTextColorStyle
    public var colorFade: TimeInterval
    public var skipUnchanged: Bool
    public var interrupt: Bool

    public static let `default` = MHBSlotTextConfiguration()

    public init(
        direction: MHBSlotTextDirection = .down,
        stagger: TimeInterval = 0.045,
        duration: TimeInterval = 0.300,
        exitOffset: TimeInterval = 0.050,
        bounce: CGFloat = 0.6,
        colorStyle: MHBSlotTextColorStyle = .none,
        colorFade: TimeInterval = 0.280,
        skipUnchanged: Bool = true,
        interrupt: Bool = true
    ) {
        self.direction = direction
        self.stagger = stagger
        self.duration = duration
        self.exitOffset = exitOffset
        self.bounce = bounce
        self.colorStyle = colorStyle
        self.colorFade = colorFade
        self.skipUnchanged = skipUnchanged
        self.interrupt = interrupt
    }

    public func with(
        direction: MHBSlotTextDirection? = nil,
        stagger: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        exitOffset: TimeInterval? = nil,
        bounce: CGFloat? = nil,
        colorStyle: MHBSlotTextColorStyle? = nil,
        colorFade: TimeInterval? = nil,
        skipUnchanged: Bool? = nil,
        interrupt: Bool? = nil
    ) -> MHBSlotTextConfiguration {
        MHBSlotTextConfiguration(
            direction: direction ?? self.direction,
            stagger: stagger ?? self.stagger,
            duration: duration ?? self.duration,
            exitOffset: exitOffset ?? self.exitOffset,
            bounce: bounce ?? self.bounce,
            colorStyle: colorStyle ?? self.colorStyle,
            colorFade: colorFade ?? self.colorFade,
            skipUnchanged: skipUnchanged ?? self.skipUnchanged,
            interrupt: interrupt ?? self.interrupt
        )
    }
}

extension MHBSlotTextConfiguration: @unchecked Sendable {}
