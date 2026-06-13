// MHBSlotTextTransitionPlan 滚轮文字动画计划
// 核心职责：
// - 将前后文本拆成逐字符滚动步骤
// - 计算每个字符的延迟、位移、时长和落地倾角

import CoreGraphics
import Foundation

// MHBSlotTextCharacterTransition 单字符滚动步骤
// 核心职责：
// - 描述单个字符从旧值切换到新值的动画参数
// - 为 UIKit cell 提供确定性的动画输入
struct MHBSlotTextCharacterTransition: Equatable {
    let index: Int
    let fromCharacter: String
    let toCharacter: String
    let delay: TimeInterval
    let duration: TimeInterval
    let outgoingOffsetY: CGFloat
    let incomingStartOffsetY: CGFloat
    let tiltDegrees: CGFloat
    let colorFade: TimeInterval
    let totalCharacterCount: Int
}

// MHBSlotTextTransitionPlan 文本滚动计划
// 核心职责：
// - 对齐参考实现的 skipUnchanged、stagger 和 tail 节奏
// - 汇总整段动画完成时间用于收尾重建
struct MHBSlotTextTransitionPlan: Equatable {
    let from: String
    let to: String
    let lineHeight: CGFloat
    let transitions: [MHBSlotTextCharacterTransition]
    let totalDuration: TimeInterval

    init(
        from: String,
        to: String,
        lineHeight: CGFloat,
        configuration: MHBSlotTextConfiguration
    ) {
        self.from = from
        self.to = to
        self.lineHeight = lineHeight

        let fromCharacters = from.slotTextCharacters
        let toCharacters = to.slotTextCharacters
        let maxLength = max(fromCharacters.count, toCharacters.count)
        let outgoingOffsetY = configuration.direction == .down ? lineHeight : -lineHeight
        let incomingStartOffsetY = configuration.direction == .down ? -lineHeight : lineHeight

        var transitions: [MHBSlotTextCharacterTransition] = []
        var maxEnd: TimeInterval = 0

        for index in 0..<maxLength {
            let fromCharacter = fromCharacters[safe: index] ?? ""
            let toCharacter = toCharacters[safe: index] ?? ""

            if fromCharacter == toCharacter && (configuration.skipUnchanged || fromCharacter.isEmpty) {
                continue
            }

            let isTail = toCharacter.isEmpty
            let duration = Self.roundToMilliseconds(
                configuration.duration
                    * (isTail ? 0.75 : 1)
                    * TimeInterval(1 + configuration.bounce * 0.45 * Self.wobble(index: index, salt: 1))
            )
            let staggerIndex: CGFloat

            if isTail {
                staggerIndex = CGFloat(toCharacters.count) * 0.5
                    + CGFloat(index - toCharacters.count) * 0.25
            } else {
                staggerIndex = CGFloat(index)
            }

            let delay = Self.roundToMilliseconds(
                TimeInterval(
                    staggerIndex
                        * CGFloat(configuration.stagger)
                        * (1 + configuration.bounce * 0.25 * Self.wobble(index: index, salt: 2))
                )
            )
            let tilt = Self.roundToHundredths(
                configuration.bounce * 5 * Self.wobble(index: index, salt: 3)
            )
            let transition = MHBSlotTextCharacterTransition(
                index: index,
                fromCharacter: fromCharacter,
                toCharacter: toCharacter,
                delay: delay,
                duration: duration,
                outgoingOffsetY: outgoingOffsetY,
                incomingStartOffsetY: incomingStartOffsetY,
                tiltDegrees: tilt,
                colorFade: configuration.colorFade,
                totalCharacterCount: maxLength
            )

            transitions.append(transition)
            maxEnd = max(
                maxEnd,
                delay + configuration.exitOffset + duration + configuration.colorFade
            )
        }

        self.transitions = transitions
        self.totalDuration = Self.roundToMilliseconds(maxEnd + 0.080)
    }

    private static func wobble(index: Int, salt: CGFloat) -> CGFloat {
        let seed = sin((CGFloat(index) + 1) * 12.9898 + salt * 78.233) * 43758.5453
        return (seed - floor(seed)) * 2 - 1
    }

    private static func roundToMilliseconds(_ value: TimeInterval) -> TimeInterval {
        (value * 1000).rounded() / 1000
    }

    private static func roundToHundredths(_ value: CGFloat) -> CGFloat {
        (value * 100).rounded() / 100
    }
}

private extension String {
    var slotTextCharacters: [String] {
        Array(self).map(String.init)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
