import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldRollingCountText 宠物世界滚动计数字符
// 核心职责：
// - 复用 DesignSystem 滚轮文字组件展示互动计数变化
// - 根据计数增减方向切换向上或向下滚动动画
struct PetWorldRollingCountText: View {
    let value: Int
    let textColor: UIColor

    @State private var displayedValue: Int
    @State private var displayedText: String
    @State private var configuration: MHBSlotTextConfiguration

    init(value: Int, textColor: UIColor) {
        self.value = value
        self.textColor = textColor

        let initialText = PetWorldCompactCountFormatter.string(for: value)
        _displayedValue = State(initialValue: value)
        _displayedText = State(initialValue: initialText)
        _configuration = State(initialValue: Self.configuration(direction: .up))
    }

    var body: some View {
        MHBSlotText(
            displayedText,
            configuration: configuration,
            font: Self.font,
            textColor: textColor
        )
        .fixedSize(horizontal: true, vertical: true)
        .onChange(of: value) { _, newValue in
            updateDisplayedValue(newValue)
        }
    }

    private func updateDisplayedValue(_ newValue: Int) {
        guard newValue != displayedValue else {
            return
        }

        configuration = Self.configuration(
            direction: newValue > displayedValue ? .up : .down
        )
        displayedValue = newValue
        displayedText = PetWorldCompactCountFormatter.string(for: newValue)
    }

    private static let font = UIFont.monospacedDigitSystemFont(
        ofSize: 14,
        weight: .medium
    )

    private static func configuration(direction: MHBSlotTextDirection) -> MHBSlotTextConfiguration {
        .default.with(
            direction: direction,
            stagger: 0.045,
            duration: 0.420,
            exitOffset: 0.060,
            bounce: 0.50,
            skipUnchanged: true,
            interrupt: true
        )
    }
}
