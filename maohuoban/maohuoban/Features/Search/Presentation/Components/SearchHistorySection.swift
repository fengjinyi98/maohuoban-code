import SwiftUI
import MaohuobanDesignSystem

// SearchHistorySection 搜索历史区
// 核心职责：
// - 展示历史搜索胶囊标签
// - 提供历史清理入口占位
struct SearchHistorySection: View {
    let keywords: [String]
    let onSelectKeyword: (String) -> Void
    let onClearHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack {
                Text("历史搜索")
                    .font(MHBTheme.Typography.callout.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                Button(action: onClearHistory) {
                    Image(systemName: "trash")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
                        .frame(width: MHBTheme.Spacing.s8, height: MHBTheme.Spacing.s8)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(keywords.isEmpty)
                .accessibilityLabel("清空历史搜索")
            }

            SearchHistoryTagFlow(
                keywords: keywords,
                onSelectKeyword: onSelectKeyword
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.history.section")
    }
}

// SearchHistoryTagFlow 历史搜索标签流
// 核心职责：
// - 使用自适应网格展示胶囊标签
// - 将历史词点击转发给页面搜索框
private struct SearchHistoryTagFlow: View {
    let keywords: [String]
    let onSelectKeyword: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 78), spacing: MHBTheme.Spacing.s2, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(keywords, id: \.self) { keyword in
                Button {
                    onSelectKeyword(keyword)
                } label: {
                    Text(keyword)
                        .font(MHBTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .frame(height: MHBTheme.Spacing.s8)
                        .background(MHBTheme.ColorToken.background.color, in: .capsule)
                        .overlay {
                            Capsule()
                                .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("搜索\(keyword)")
            }
        }
    }
}
