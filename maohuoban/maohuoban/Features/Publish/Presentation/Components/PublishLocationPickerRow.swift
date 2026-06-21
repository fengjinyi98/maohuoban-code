import SwiftUI
import MaohuobanDesignSystem

// PublishLocationPickerRow 地点选择行
// 核心职责：
// - 渲染地点信息与选中态
// - 提供整行可点击的地点切换入口
struct PublishLocationPickerRow: View {
    let location: PublishLocationOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected
                                    ? Color.clear
                                    : MHBTheme.ColorToken.separator.color,
                                lineWidth: 1
                            )
                            .background(
                                Circle()
                                    .fill(
                                        isSelected
                                            ? MHBTheme.ColorToken.primaryBackground.color
                                            : .clear
                                    )
                            )
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(MHBTheme.ColorToken.primary.color)
                                .frame(width: 12, height: 12)
                        }
                    }

                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                        Text(location.title)
                            .font(MHBTheme.Typography.body)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                        Text(location.subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                            .lineLimit(1)
                    }

                    Spacer(minLength: MHBTheme.Spacing.s2)

                    if location.distance.isEmpty == false {
                        Text(location.distance)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                }
                .padding(.vertical, MHBTheme.Spacing.s3)
                .padding(.horizontal, MHBTheme.Spacing.s4)

                Divider()
                    .padding(.leading, 54)
                    .padding(.trailing, MHBTheme.Spacing.s4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
