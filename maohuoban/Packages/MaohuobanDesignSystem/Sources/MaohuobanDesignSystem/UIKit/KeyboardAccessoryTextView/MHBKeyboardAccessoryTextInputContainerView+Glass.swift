import SwiftUI
import UIKit

// MHBKeyboardAccessoryTextInputContainerView 毛玻璃工厂方法
// 核心职责：
// - 提供键盘附属输入容器的仿融合毛玻璃背景
// - 提供键盘附属面板的圆角毛玻璃背景
extension MHBKeyboardAccessoryTextInputContainerView {
    static func makeFusionGlassView() -> UIView & UIContentView {
        let configuration = UIHostingConfiguration {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        }
        .margins(.all, 0)
        let view = configuration.makeContentView()
        view.backgroundColor = .clear
        return view
    }

    static func makePanelGlassView() -> UIView & UIContentView {
        let configuration = UIHostingConfiguration {
            Color.clear
                .glassEffect(
                    .regular,
                    in: UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: 28,
                            bottomLeading: 0,
                            bottomTrailing: 0,
                            topTrailing: 28
                        )
                    )
                )
        }
        .margins(.all, 0)
        let view = configuration.makeContentView()
        view.backgroundColor = .clear
        return view
    }
}
