// MHBToastAction.swift Toast操作按钮动作
// 核心职责：
// - 封装 Toast 中的交互动作属性与点击回调
// - 支持 Swift 现代并发特性 (Sendable)

import Foundation

public struct MHBToastAction: Sendable {
    public let label: String
    public let handler: @Sendable () -> Void

    public init(label: String, handler: @escaping @Sendable () -> Void) {
        self.label = label
        self.handler = handler
    }
}

extension MHBToastAction: Equatable {
    public static func == (lhs: MHBToastAction, rhs: MHBToastAction) -> Bool {
        lhs.label == rhs.label
    }
}
