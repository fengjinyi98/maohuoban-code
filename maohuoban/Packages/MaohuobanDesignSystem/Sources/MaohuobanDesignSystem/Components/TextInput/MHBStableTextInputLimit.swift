import SwiftUI
import UIKit

// MHBStableTextInputLimit 稳定输入长度限制
// 核心职责：
// - 为业务输入框提供统一计数规则和越界判断
// - 支持中文输入法稳定提交后的限制态展示
public struct MHBStableTextInputLimit: Equatable {
    public enum CountingRule: Equatable {
        case allCharacters
        case nonWhitespace
    }

    public let maxCount: Int
    public let countingRule: CountingRule

    public init(
        maxCount: Int,
        countingRule: CountingRule = .allCharacters
    ) {
        self.maxCount = maxCount
        self.countingRule = countingRule
    }

    public func state(for text: String) -> MHBStableTextInputLimitState {
        let count = switch countingRule {
        case .allCharacters:
            text.count
        case .nonWhitespace:
            text.filter { !$0.isWhitespace }.count
        }

        return MHBStableTextInputLimitState(
            count: count,
            maxCount: maxCount
        )
    }
}

// MHBStableTextInputLimitState 稳定输入长度状态
// 核心职责：
// - 表达当前输入计数和限制是否越界
// - 供业务层禁用保存、展示计数和错误边框
public struct MHBStableTextInputLimitState: Equatable {
    public let count: Int
    public let maxCount: Int

    public var isExceeded: Bool {
        count > maxCount
    }
}

public extension View {
    // mhbStableTextInputContainer 稳定输入容器样式
    // 核心职责：
    // - 统一输入框背景、圆角和错误边框
    // - 让业务输入只传入当前限制态
    func mhbStableTextInputContainer(
        isError: Bool,
        backgroundColor: Color = Color(uiColor: .secondarySystemGroupedBackground),
        cornerRadius: CGFloat = MHBTheme.Radius.large
    ) -> some View {
        background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isError ? MHBTheme.ColorToken.danger.color : Color.clear,
                        lineWidth: 1
                    )
            }
    }
}
