import SwiftUI
import MaohuobanDesignSystem

// PublishTopicSection 发布话题区
// 核心职责：
// - 展示图文草稿已绑定的话题
// - 支持用户手动添加和移除话题
struct PublishTopicSection: View {
    let topicNames: [String]
    @Binding var draftTopicName: String
    let onAddTopic: () -> Void
    let onRemoveTopic: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PublishSectionHeader(
                title: "话题",
                subtitle: "用于聚合经验、搜索和推荐解释"
            )

            if !topicNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        ForEach(topicNames, id: \.self) { topicName in
                            Button {
                                onRemoveTopic(topicName)
                            } label: {
                                MHBTagView("#\(topicName)", systemImage: "xmark", style: .primary, size: .medium)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("移除话题 \(topicName)")
                        }
                    }
                }
            }

            HStack(spacing: MHBTheme.Spacing.s2) {
                TextField("添加话题，例如 肠胃敏感", text: $draftTopicName)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("publish.topicInput")

                Button(action: onAddTopic) {
                    Label("添加", systemImage: "plus")
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("publish.topic.addButton")
            }
            .padding(MHBTheme.Spacing.s3)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .accessibilityIdentifier("publish.topic.section")
    }
}
