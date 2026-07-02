import SwiftUI
import MaohuobanDesignSystem

// PublishComposerMode 发布编辑模式
// 核心职责：
// - 表达发布页当前使用的内容组织方式
// - 为顶部模式切换控件提供稳定选项
enum PublishComposerMode: String, CaseIterable, Identifiable {
    case gallery
    case richText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gallery: "画廊模式"
        case .richText: "图文模式"
        }
    }
}

// PublishComposerModePicker 发布模式切换控件
// 核心职责：
// - 在系统导航栏中提供发布模式切换
// - 使用稳定尺寸避免顶部布局跳动
struct PublishComposerModePicker: View {
    @Binding var selection: PublishComposerMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PublishComposerMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.title)
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(
                            selection == mode
                                ? MHBTheme.ColorToken.labelPrimary.color
                                : MHBTheme.ColorToken.labelSecondary.color
                        )
                        .frame(width: 76, height: 32)
                        .background {
                            if selection == mode {
                                Capsule()
                                    .fill(MHBTheme.ColorToken.cardSolid.color)
                                    .shadow(
                                        color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.08),
                                        radius: 8,
                                        x: 0,
                                        y: 2
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MHBTheme.Spacing.s1)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(Capsule())
        .accessibilityIdentifier("publish.modePicker")
    }
}
