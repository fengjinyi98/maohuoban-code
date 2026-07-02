// MHBSlotText SwiftUI 桥接视图
// 核心职责：
// - 将 UIKit 滚轮文字组件暴露给 SwiftUI 页面
// - 保持 SwiftUI 侧输入简单且不持有动画状态

import SwiftUI
import UIKit

// MHBSlotText SwiftUI 桥接视图
// 核心职责：
// - 根据文本变化转发到 UIKit 滚轮文字视图
// - 支持业务页面配置字体、颜色和动画参数
public struct MHBSlotText: UIViewRepresentable {
    private let text: String
    private let configuration: MHBSlotTextConfiguration
    private let font: UIFont
    private let textColor: UIColor
    private let animated: Bool

    public init(
        _ text: String,
        configuration: MHBSlotTextConfiguration = .default,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        animated: Bool = true
    ) {
        self.text = text
        self.configuration = configuration
        self.font = font
        self.textColor = textColor
        self.animated = animated
    }

    public func makeUIView(context: Context) -> MHBSlotTextView {
        MHBSlotTextView(
            text: text,
            configuration: configuration,
            font: font,
            textColor: textColor
        )
    }

    public func updateUIView(_ uiView: MHBSlotTextView, context: Context) {
        uiView.configuration = configuration
        uiView.font = font
        uiView.textColor = textColor
        uiView.setText(text, animated: animated, configuration: configuration)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MHBSlotTextView,
        context: Context
    ) -> CGSize? {
        uiView.intrinsicContentSize
    }
}

