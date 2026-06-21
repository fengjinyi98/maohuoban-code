// MHBSlotTextTests 滚轮文字基础设施测试
// 核心职责：
// - 验证滚轮文字动画参数与参考实现保持一致
// - 验证按字符生成的滚动计划稳定可预测
// - 验证 UIKit 视图可构建并维护当前展示文本

import Testing
import UIKit
@testable import MaohuobanDesignSystem

@Suite("毛伙伴滚轮文字基础设施测试")
struct MHBSlotTextTests {
    @Test("默认参数与 slot-text 参考实现一致")
    func defaultConfigurationMatchesReference() {
        let configuration = MHBSlotTextConfiguration.default

        #expect(configuration.direction == .down)
        #expect(configuration.stagger == 0.045)
        #expect(configuration.duration == 0.300)
        #expect(configuration.exitOffset == 0.050)
        #expect(configuration.bounce == 0.6)
        #expect(configuration.colorFade == 0.280)
        #expect(configuration.skipUnchanged == true)
        #expect(configuration.interrupt == true)
    }

    @Test("彩色渐变按字符索引生成 HSB 色相")
    func chromaticPaletteGeneratesIndexedHue() {
        let palette = MHBSlotTextChromaticPalette(
            from: 20,
            spread: 300,
            saturation: 0.9,
            brightness: 0.7
        )

        let first = palette.color(index: 0, total: 3).resolvedRGBA()
        let middle = palette.color(index: 1, total: 3).resolvedRGBA()
        let last = palette.color(index: 2, total: 3).resolvedRGBA()

        #expect(first != middle)
        #expect(middle != last)
        #expect(last != first)
    }

    @Test("滚动计划跳过相同字符并保留原始索引节奏")
    func transitionPlanSkipsUnchangedCharacters() {
        let configuration = MHBSlotTextConfiguration.default.with(
            direction: .up,
            stagger: 0.040,
            duration: 0.300,
            exitOffset: 0.060,
            bounce: 0
        )
        let plan = MHBSlotTextTransitionPlan(
            from: "Copy",
            to: "Copied",
            lineHeight: 20,
            configuration: configuration
        )

        #expect(plan.transitions.map(\.index) == [3, 4, 5])
        #expect(plan.transitions.map(\.fromCharacter) == ["y", "", ""])
        #expect(plan.transitions.map(\.toCharacter) == ["i", "e", "d"])
        #expect(plan.transitions[0].delay == 0.120)
        #expect(plan.transitions[0].outgoingOffsetY == -20)
        #expect(plan.transitions[0].incomingStartOffsetY == 20)
    }

    @MainActor
    @Test("UIKit 视图初始化后按字符创建 cell")
    func slotTextViewBuildsCellsForInitialText() {
        let view = MHBSlotTextView(text: "重新发送")

        #expect(view.currentText == "重新发送")
        #expect(view.slotCellCount == 4)
        #expect(view.accessibilityLabel == "重新发送")
    }

    @MainActor
    @Test("字符 cell 尺寸约束允许系统临时测量约束优先")
    func slotTextCellSizeConstraintsYieldToTemporaryFittingConstraints() {
        let cell = MHBSlotTextCellView(
            character: "9",
            font: .monospacedDigitSystemFont(ofSize: 14, weight: .medium),
            textColor: .label
        )

        let widthConstraint = cell.constraints.first {
            $0.firstItem === cell && $0.firstAttribute == .width
        }
        let heightConstraint = cell.constraints.first {
            $0.firstItem === cell && $0.firstAttribute == .height
        }

        #expect(widthConstraint?.priority.rawValue ?? 0 < UILayoutPriority.required.rawValue)
        #expect(heightConstraint?.priority.rawValue ?? 0 < UILayoutPriority.required.rawValue)
    }

    @MainActor
    @Test("UIKit 视图可在无动画模式直接更新文本")
    func slotTextViewUpdatesTextWithoutAnimation() {
        let view = MHBSlotTextView(text: "重新发送")

        view.setText("59 秒", animated: false)

        #expect(view.currentText == "59 秒")
        #expect(view.slotCellCount == 4)
        #expect(view.accessibilityLabel == "59 秒")
    }

    @MainActor
    @Test("重复 flash 保留首次回退文本")
    func repeatedFlashPreservesOriginalText() {
        let view = MHBSlotTextView(text: "重新发送")

        view.flash("已发送", revertAfter: 3)
        view.flash("已发送", revertAfter: 3)

        #expect(view.pendingFlashBaseText == "重新发送")
    }
}

private extension UIColor {
    func resolvedRGBA() -> [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return [
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255)),
            Int(round(alpha * 255))
        ]
    }
}
