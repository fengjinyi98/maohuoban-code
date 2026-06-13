// MHBToast.swift Toast提示数据模型
// 核心职责：
// - 封装单个 Dynamic Island 风格 Toast 提示的完整数据状态
// - 支持唯一标识与值相等性校验，适配两种初始化方式（原始字段与类型便捷映射）

import SwiftUI

public struct MHBToast: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var symbol: String
    public var symbolFont: Font
    public var symbolForegroundStyleColor1: Color
    public var symbolForegroundStyleColor2: Color
    public var title: String
    public var message: String
    public var duration: TimeInterval?

    public var symbolForegroundStyle: (Color, Color) {
        (symbolForegroundStyleColor1, symbolForegroundStyleColor2)
    }

    public static func == (lhs: MHBToast, rhs: MHBToast) -> Bool {
        lhs.id == rhs.id &&
        lhs.symbol == rhs.symbol &&
        lhs.title == rhs.title &&
        lhs.message == rhs.message &&
        lhs.duration == rhs.duration
    }

    // 与参考项目 Toast 字段对齐的初始化方法
    public init(
        id: UUID = UUID(),
        symbol: String,
        symbolFont: Font = .system(size: 35),
        symbolForegroundStyle: (Color, Color),
        title: String,
        message: String,
        duration: TimeInterval? = 3.0
    ) {
        self.id = id
        self.symbol = symbol
        self.symbolFont = symbolFont
        self.symbolForegroundStyleColor1 = symbolForegroundStyle.0
        self.symbolForegroundStyleColor2 = symbolForegroundStyle.1
        self.title = title
        self.message = message
        self.duration = duration
    }

    // 兼容原 MHBToastType 输入的便利初始化方法
    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        type: MHBToastType = .info,
        duration: TimeInterval? = 3.0,
        dismissible: Bool = true,      // 保留参数适配原有调用
        action: MHBToastAction? = nil  // 保留参数适配原有调用
    ) {
        self.id = id
        self.title = title
        self.message = description ?? ""
        self.duration = duration
        self.symbolFont = .system(size: 35)

        switch type {
        case .success:
            self.symbol = "checkmark.seal.fill"
            self.symbolForegroundStyleColor1 = .white
            self.symbolForegroundStyleColor2 = .green
        case .danger:
            self.symbol = "xmark.seal.fill"
            self.symbolForegroundStyleColor1 = .white
            self.symbolForegroundStyleColor2 = .red
        case .warning:
            self.symbol = "exclamationmark.triangle.fill"
            self.symbolForegroundStyleColor1 = .white
            self.symbolForegroundStyleColor2 = .orange
        case .info, .loading:
            self.symbol = "info.circle.fill"
            self.symbolForegroundStyleColor1 = .white
            self.symbolForegroundStyleColor2 = .blue
        }
    }
}
