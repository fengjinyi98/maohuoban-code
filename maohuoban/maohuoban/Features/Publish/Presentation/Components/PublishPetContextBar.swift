import SwiftUI
import MaohuobanDesignSystem

// PublishPetContextBar 发布宠物上下文条
// 核心职责：
// - 在编辑器顶部展示当前关联宠物主体
// - 提供进入宠物选择弹层的触达入口
struct PublishPetContextBar: View {
    let selectedPetName: String?
    let source: PublishEntrySource
    let onSelectPet: () -> Void

    var body: some View {
        Button(action: onSelectPet) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                ZStack {
                    Circle()
                        .fill(MHBTheme.ColorToken.primaryBackground.color)

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedPetName ?? "选择关联宠物")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(source.publishContextHint)
                        .font(MHBTheme.Typography.section)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.leading, MHBTheme.Spacing.s1)
            .padding(.trailing, MHBTheme.Spacing.s3)
            .frame(height: 42)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("publish.pet.contextBar")
    }
}

private extension PublishEntrySource {
    var publishContextHint: String {
        switch self {
        case .home:
            "首页日常记录"
        case .petWorld:
            "宠物世界动态"
        case .sameCity:
            "同城体验记录"
        case .profile:
            "宠物档案沉淀"
        }
    }
}
