import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileEditSelectionMenuOverlay 编辑资料锚点选择菜单浮层
// 核心职责：
// - 使用统一锚点浮动面板承载资料字段选择项
// - 根据 row 位置将菜单放置在触发入口附近
struct PetProfileEditSelectionMenuOverlay: View {
    let isPresented: Bool
    let containerWidth: CGFloat
    let rowFrame: CGRect
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    private let menuWidth: CGFloat = 168

    private var offset: CGSize {
        let horizontalMargin = MHBTheme.Spacing.s4
        let x = min(
            max(rowFrame.maxX - menuWidth, horizontalMargin),
            max(horizontalMargin, containerWidth - menuWidth - horizontalMargin)
        )
        let y = rowFrame.maxY + MHBTheme.Spacing.s1

        return CGSize(width: x, height: y)
    }

    var body: some View {
        MHBAnchoredFloatingPanel(
            isPresented: isPresented && rowFrame != .zero,
            offset: offset,
            scaleAnchor: .topTrailing
        ) {
            PetProfileEditSelectionMenu(
                selectedValue: selectedValue,
                options: options,
                onSelect: onSelect
            )
        }
        .animation(.snappy(duration: 0.22), value: isPresented)
    }
}

// PetProfileEditSelectionMenu 编辑资料选择菜单
// 核心职责：
// - 展示字段可选值
// - 使用勾选标识表达当前值
struct PetProfileEditSelectionMenu: View {
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    PetProfileEditSelectionMenuRow(
                        title: option,
                        isSelected: option == selectedValue
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MHBTheme.Spacing.s2)
        .frame(width: 168)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
    }
}

// PetProfileEditSelectionMenuRow 编辑资料选择菜单行
// 核心职责：
// - 展示单个选择项标题
// - 为当前选中项展示勾选标识
struct PetProfileEditSelectionMenuRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Image(systemName: "checkmark")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color.opacity(isSelected ? 1 : 0))
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
