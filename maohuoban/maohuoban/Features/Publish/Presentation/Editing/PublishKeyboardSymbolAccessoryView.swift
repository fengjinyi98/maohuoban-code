import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishKeyboardSymbolAccessoryView 发布键盘符号工具栏
// 核心职责：
// - 用 SwiftUI Liquid Glass 承载键盘上方的发布符号入口
// - 将 # 和 @ 作为同一个左侧工具组暴露给 UIKit 输入控件
@MainActor
final class PublishKeyboardSymbolAccessoryView: UIView {
    private static let contentHeight: CGFloat = 60

    private let hostingController: UIHostingController<PublishKeyboardSymbolAccessoryContent>

    init(
        onInsertTopic: @escaping () -> Void,
        onInsertMention: @escaping () -> Void
    ) {
        hostingController = UIHostingController(
            rootView: PublishKeyboardSymbolAccessoryContent(
                onInsertTopic: onInsertTopic,
                onInsertMention: onInsertMention
            )
        )
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: Self.contentHeight))
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth]

        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.contentHeight)
    }
}

// PublishKeyboardSymbolAccessoryContent 键盘符号工具栏内容
// 核心职责：
// - 以单个 Liquid Glass 胶囊承载两个符号按钮
// - 保持工具组贴近键盘左侧并预留底部视觉间距
private struct PublishKeyboardSymbolAccessoryContent: View {
    let onInsertTopic: () -> Void
    let onInsertMention: () -> Void

    var body: some View {
        HStack {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    PublishKeyboardSymbolButton(
                        symbol: "#",
                        accessibilityLabel: "插入话题",
                        action: onInsertTopic
                    )

                    PublishKeyboardSymbolButton(
                        symbol: "@",
                        accessibilityLabel: "提及用户",
                        action: onInsertMention
                    )
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(Color.clear)
    }
}

// PublishKeyboardSymbolButton 键盘符号按钮
// 核心职责：
// - 提供和系统导航图标接近的符号尺寸
// - 固定命中区域避免键盘工具栏布局跳动
private struct PublishKeyboardSymbolButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
