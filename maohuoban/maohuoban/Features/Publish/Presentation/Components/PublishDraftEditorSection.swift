import SwiftUI
import MaohuobanDesignSystem

// PublishDraftEditorSection 图文发布正文编辑区
// 核心职责：
// - 收集发布标题与正文
// - 保持文本输入与发布提交状态解耦
struct PublishDraftEditorSection: View {
    @Binding var title: String
    @Binding var bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PublishSectionHeader(
                title: "内容",
                subtitle: "正文会进入宠物时间线，也会影响话题和关系推荐"
            )

            HStack(spacing: MHBTheme.Spacing.s3) {
                TextField("写标题更容易被看见", text: $title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .accessibilityIdentifier("publish.titleInput")

                Text("\(title.count)/30")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .monospacedDigit()
            }
            .padding(MHBTheme.Spacing.s3)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(minHeight: 176)
                    .scrollContentBackground(.hidden)
                    .padding(MHBTheme.Spacing.s2)
                    .accessibilityIdentifier("publish.bodyInput")

                if bodyText.isEmpty {
                    Text("记录宠物这次值得分享的瞬间、变化或一次同城体验")
                        .font(MHBTheme.Typography.body)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .padding(MHBTheme.Spacing.s4)
                        .allowsHitTesting(false)
                }
            }
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .accessibilityIdentifier("publish.editor.section")
    }
}
