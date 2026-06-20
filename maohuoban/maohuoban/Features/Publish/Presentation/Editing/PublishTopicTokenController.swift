import Foundation
import UIKit
import MaohuobanDesignSystem

// PublishTopicTokenReconcileResult 话题 token 协调结果
// 核心职责：
// - 返回当前正文识别到的话题名称列表
// - 保留话题高亮扫描后的编辑器状态信号
struct PublishTopicTokenReconcileResult: Equatable {
    let activeAnchorLocation: Int?
    let topicNames: [String]
}

// PublishTopicTokenController 发布正文话题 token 控制器
// 核心职责：
// - 负责在正文里插入结构化井号 token
// - 负责扫描、提取并高亮用户输入的多个话题 token
enum PublishTopicTokenController {
    static let topicAttributeKey = NSAttributedString.Key("maohuoban.publish.topic.token")

    static func insertTopicMarker(
        in attributedText: NSMutableAttributedString,
        at location: Int
    ) -> NSRange {
        let safeLocation = max(0, min(location, attributedText.length))
        let topicMarker = NSAttributedString(
            string: "#",
            attributes: [
                topicAttributeKey: true,
                .foregroundColor: MHBTheme.ColorToken.primary.publishUIKitColor,
            ]
        )
        attributedText.insert(topicMarker, at: safeLocation)
        return NSRange(location: safeLocation, length: 1)
    }

    static func reconcileTopics(
        in attributedText: NSMutableAttributedString,
        defaultColor: UIColor? = nil
    ) -> PublishTopicTokenReconcileResult {
        let string = attributedText.string as NSString
        clearTopicStyling(in: attributedText)

        if let defaultColor, attributedText.length > 0 {
            attributedText.addAttribute(
                .foregroundColor,
                value: defaultColor,
                range: NSRange(location: 0, length: attributedText.length)
            )
        }

        var topicNames: [String] = []
        var seenTopicNames = Set<String>()
        let ranges = topicTokenRanges(in: string)
        for tokenRange in ranges {
            guard let topicName = makeTopicName(from: string.substring(with: tokenRange)) else {
                continue
            }
            attributedText.addAttributes(
                [
                    topicAttributeKey: true,
                    .foregroundColor: MHBTheme.ColorToken.primary.publishUIKitColor,
                ],
                range: tokenRange
            )

            if seenTopicNames.insert(topicName).inserted {
                topicNames.append(topicName)
            }
        }

        return .init(activeAnchorLocation: nil, topicNames: topicNames)
    }

    nonisolated static func topicTokenRangeForDeletion(
        in attributedText: NSAttributedString,
        affectedRange: NSRange
    ) -> NSRange? {
        let string = attributedText.string as NSString
        return topicTokenRanges(in: string).first { tokenRange in
            tokenRange.contains(affectedRange)
        }
    }

    nonisolated static func topicTokenRangeForTap(
        in attributedText: NSAttributedString,
        location: Int
    ) -> NSRange? {
        let string = attributedText.string as NSString
        return topicTokenRanges(in: string).first { tokenRange in
            tokenRange.containsCaret(location)
        }
    }

    private static func clearTopicStyling(in attributedText: NSMutableAttributedString) {
        guard attributedText.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: attributedText.length)
        attributedText.removeAttribute(topicAttributeKey, range: fullRange)
    }

    nonisolated private static func makeTopicName(from rawToken: String) -> String? {
        let canonicalName = rawToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard canonicalName.isEmpty == false else { return nil }
        return canonicalName
    }

    nonisolated private static func topicTokenRanges(in string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var cursor = 0

        while cursor < string.length {
            let character = string.substring(with: NSRange(location: cursor, length: 1))
            guard character == "#" else {
                cursor += 1
                continue
            }

            let tokenStart = cursor
            var tokenEnd = tokenStart + 1

            while tokenEnd < string.length {
                let candidate = string.substring(with: NSRange(location: tokenEnd, length: 1))
                if candidate.isPublishTopicBoundary || candidate == "#" {
                    break
                }
                tokenEnd += 1
            }

            let tokenRange = NSRange(location: tokenStart, length: tokenEnd - tokenStart)
            if makeTopicName(from: string.substring(with: tokenRange)) != nil {
                ranges.append(tokenRange)
            }

            cursor = max(tokenEnd, tokenStart + 1)
        }

        return ranges
    }
}

extension MHBTheme.ColorToken {
    var publishUIKitColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha)
            } else {
                UIColor(red: red, green: green, blue: blue, alpha: alpha)
            }
        }
    }
}

private extension String {
    nonisolated var isPublishTopicBoundary: Bool {
        if rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return true
        }
        let punctuationScalars = CharacterSet(charactersIn: "，。！？；：、,.!?;:()[]{}<>《》“”‘’\"'\\/|+-=*…")
        return unicodeScalars.allSatisfy { punctuationScalars.contains($0) }
    }
}

private extension NSRange {
    nonisolated func containsCaret(_ location: Int) -> Bool {
        location >= self.location && location <= self.location + self.length
    }

    nonisolated func contains(_ other: NSRange) -> Bool {
        other.location >= location && other.location + other.length <= location + length
    }
}
