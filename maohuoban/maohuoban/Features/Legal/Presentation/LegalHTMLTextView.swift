import SwiftUI
import UIKit
import MaohuobanDesignSystem

// LegalHTMLTextView 法务 HTML 富文本视图
// 核心职责：
// - 使用原生 UITextView 展示后端托管的法务文档
// - 将受支持的 HTML 文档块转换为稳定的原生富文本
struct LegalHTMLTextView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.alwaysBounceVertical = false
        textView.bounces = false
        textView.contentInsetAdjustmentBehavior = .never
        textView.accessibilityIdentifier = "legal.documentTextView"
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.textContainerInset = UIEdgeInsets(
            top: MHBTheme.Spacing.s5,
            left: MHBTheme.Spacing.s5,
            bottom: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4,
            right: MHBTheme.Spacing.s5
        )

        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        uiView.attributedText = attributedText(from: html)
    }

    // attributedText 生成法务文档对应的原生富文本
    // 核心职责：
    // - 按后端文档块顺序提取标题、正文、元信息和列表项
    // - 避免系统 HTML 导入器参与对象生命周期管理
    private func attributedText(from html: String) -> NSAttributedString {
        let pattern = #"<(h1|h2|h3|p|li|span)\b[^>]*>([\s\S]*?)</\1>"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return fallbackAttributedText(from: html)
        }

        let sourceRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let result = NSMutableAttributedString()

        expression.enumerateMatches(in: html, range: sourceRange) { match, _, _ in
            guard
                let match,
                let tagRange = Range(match.range(at: 1), in: html),
                let contentRange = Range(match.range(at: 2), in: html)
            else {
                return
            }

            let tag = html[tagRange].lowercased()
            let content = normalizedText(from: String(html[contentRange]))
            guard !content.isEmpty else { return }

            let block = LegalTextBlock(tag: tag, content: content)
            result.append(
                NSAttributedString(
                    string: block.displayText,
                    attributes: attributes(for: block.kind)
                )
            )
        }

        guard result.length > 0 else {
            return fallbackAttributedText(from: html)
        }

        return result
    }

    // attributes 提供法务文档块的原生排版属性
    // 核心职责：
    // - 复用 DesignSystem 语义颜色
    // - 为标题、正文、元信息和列表项建立稳定层级
    private func attributes(for kind: LegalTextBlock.Kind) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        switch kind {
        case .title:
            paragraphStyle.paragraphSpacing = 14
            return [
                .font: UIFont.preferredFont(forTextStyle: .largeTitle),
                .foregroundColor: MHBTheme.ColorToken.labelPrimary.uiColor,
                .paragraphStyle: paragraphStyle
            ]
        case .sectionTitle:
            paragraphStyle.paragraphSpacingBefore = 14
            paragraphStyle.paragraphSpacing = 8
            return [
                .font: UIFont.preferredFont(forTextStyle: .title3).bold,
                .foregroundColor: MHBTheme.ColorToken.labelPrimary.uiColor,
                .paragraphStyle: paragraphStyle
            ]
        case .metadata:
            paragraphStyle.paragraphSpacing = 2
            return [
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
                .foregroundColor: MHBTheme.ColorToken.labelTertiary.uiColor,
                .paragraphStyle: paragraphStyle
            ]
        case .paragraph, .listItem:
            paragraphStyle.paragraphSpacing = 10
            return [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: MHBTheme.ColorToken.labelSecondary.uiColor,
                .paragraphStyle: paragraphStyle
            ]
        }
    }

    // fallbackAttributedText 生成 HTML 解析失败时的纯文本展示
    // 核心职责：
    // - 保证法务文档在异常 HTML 下仍可阅读
    // - 使用系统动态字体和 DesignSystem 语义颜色
    private func fallbackAttributedText(from html: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        return NSAttributedString(
            string: plainText(from: html),
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: MHBTheme.ColorToken.labelSecondary.uiColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    // normalizedText 归一法务文档块中的内联 HTML
    // 核心职责：
    // - 移除内联标签并保留换行语义
    // - 解码法务文档使用的常见 HTML 实体
    private func normalizedText(from html: String) -> String {
        html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: .caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // plainText 提取 HTML 兜底文本
    // 核心职责：
    // - 去除样式、脚本和标签内容
    // - 保留用户可阅读的正文字符
    private func plainText(from html: String) -> String {
        html
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    final class Coordinator {
        var loadedHTML: String?
    }
}

// LegalTextBlock 法务文档原生文本块
// 核心职责：
// - 表达 HTML 文档块对应的原生排版层级
// - 为列表符号和段落换行提供统一输出
private struct LegalTextBlock {
    enum Kind {
        case title
        case sectionTitle
        case metadata
        case paragraph
        case listItem
    }

    let kind: Kind
    let content: String

    init(tag: String, content: String) {
        self.content = content

        switch tag {
        case "h1":
            kind = .title
        case "h2", "h3":
            kind = .sectionTitle
        case "span":
            kind = .metadata
        case "li":
            kind = .listItem
        default:
            kind = .paragraph
        }
    }

    var displayText: String {
        switch kind {
        case .listItem:
            "• \(content)\n"
        default:
            "\(content)\n"
        }
    }
}

private extension UIFont {
    var bold: UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
