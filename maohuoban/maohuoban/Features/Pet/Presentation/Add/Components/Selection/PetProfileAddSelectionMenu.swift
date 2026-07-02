import SwiftUI
import MaohuobanDesignSystem

// PetProfileAddSelectionMenuOverlay 添加宠物锚点选择菜单浮层
// 核心职责：
// - 将选择菜单定位在触发 row 附近
// - 使用统一锚点浮动面板承载展开转场
struct PetProfileAddSelectionMenuOverlay: View {
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
            PetProfileAddSelectionMenu(
                selectedValue: selectedValue,
                options: options,
                onSelect: onSelect
            )
        }
        .animation(.snappy(duration: 0.22), value: isPresented)
    }
}

// PetProfileAddSelectionMenu 添加宠物字段选择菜单
// 核心职责：
// - 展示字段可选项
// - 使用勾选图标表达当前值
struct PetProfileAddSelectionMenu: View {
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    PetProfileAddSelectionMenuRow(
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

// PetProfileAddSelectionMenuRow 添加宠物选择菜单行
// 核心职责：
// - 展示单个选择项标题
// - 为选中项显示主题化勾选标识
struct PetProfileAddSelectionMenuRow: View {
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
