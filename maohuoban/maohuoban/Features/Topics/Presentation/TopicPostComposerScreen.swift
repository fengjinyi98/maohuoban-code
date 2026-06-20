import SwiftUI
import MaohuobanDesignSystem

// TopicPostComposerScreen 话题发布原型页
// 核心职责：
// - 承载快速 UI 阶段的 UGC 发布话题选择骨架
// - 支持用户手动输入并创建新话题后加入发布草稿
struct TopicPostComposerScreen: View {
    let seedTopicID: String?
    let store: TopicStore

    @State private var bodyText = ""
    @State private var draftTopicName = ""
    @State private var selectedTopicIDs: Set<String>
    @State private var didPrepareDraft = false

    init(seedTopicID: String?, store: TopicStore) {
        self.seedTopicID = seedTopicID
        self.store = store
        _selectedTopicIDs = State(initialValue: Set(seedTopicID.map { [$0] } ?? []))
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                if didPrepareDraft {
                    TopicComposerPreparedBanner()
                }

                TopicComposerBodySection(bodyText: $bodyText)

                TopicComposerSelectedTopicsSection(
                    topics: selectedTopics,
                    onRemove: removeTopic(_:)
                )

                TopicCreatePanel(
                    draftName: $draftTopicName,
                    title: "手动添加话题",
                    prompt: "输入已有或新的话题名；本地没有时会创建新话题并加入草稿。",
                    buttonTitle: "添加",
                    onSubmit: addTypedTopic
                )

                TopicComposerSuggestedTopicsSection(
                    topics: Array(store.selectableTopics(excluding: selectedTopicIDs).prefix(8)),
                    onSelect: addExistingTopic(_:)
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("发布动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("发布", action: prepareDraft)
                    .disabled(!canPrepareDraft)
            }
        }
        .accessibilityIdentifier("topics.composer")
    }

    private var selectedTopics: [TopicSummary] {
        store.topics.filter { selectedTopicIDs.contains($0.id) }
    }

    private var canPrepareDraft: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedTopicIDs.isEmpty
    }

    private func addTypedTopic() {
        guard let topic = store.createOrFollowTopic(named: draftTopicName) else {
            return
        }

        selectedTopicIDs.insert(topic.id)
        draftTopicName = ""
        didPrepareDraft = false
    }

    private func addExistingTopic(_ topic: TopicSummary) {
        selectedTopicIDs.insert(topic.id)
        didPrepareDraft = false
    }

    private func removeTopic(_ topicID: String) {
        selectedTopicIDs.remove(topicID)
        didPrepareDraft = false
    }

    private func prepareDraft() {
        didPrepareDraft = true
    }
}

// TopicComposerPreparedBanner 发布草稿准备完成提示
// 核心职责：
// - 在快速 UI 阶段反馈发布动作已经形成草稿
private struct TopicComposerPreparedBanner: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(MHBTheme.ColorToken.success.color)

            Text("发布草稿已准备好")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .padding(MHBTheme.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// TopicComposerBodySection 发布正文输入区
// 核心职责：
// - 收集用户发布正文
// - 与话题选择区保持独立状态边界
private struct TopicComposerBodySection: View {
    @Binding var bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("正文")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(MHBTheme.Typography.body)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(MHBTheme.Spacing.s2)

                if bodyText.isEmpty {
                    Text("记录宠物这次值得分享的瞬间")
                        .font(MHBTheme.Typography.body)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .padding(MHBTheme.Spacing.s4)
                        .allowsHitTesting(false)
                }
            }
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicComposerSelectedTopicsSection 已选话题区
// 核心职责：
// - 展示发布草稿当前绑定的话题
// - 允许用户移除误选话题
private struct TopicComposerSelectedTopicsSection: View {
    let topics: [TopicSummary]
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack {
                Text("已选话题")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                Text("\(topics.count)")
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            if topics.isEmpty {
                Text("至少添加一个话题，后续内容分类和 RAG 才能使用这个结构化信号。")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        ForEach(topics) { topic in
                            Button {
                                onRemove(topic.id)
                            } label: {
                                MHBTagView(topic.displayName, systemImage: "xmark", style: .primary, size: .medium)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicComposerSuggestedTopicsSection 候选话题区
// 核心职责：
// - 展示当前可选话题
// - 支持用户从已有话题中快速加入发布草稿
private struct TopicComposerSuggestedTopicsSection: View {
    let topics: [TopicSummary]
    let onSelect: (TopicSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("可选话题")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            if topics.isEmpty {
                Text("当前没有更多可选话题")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            } else {
                VStack(spacing: MHBTheme.Spacing.s2) {
                    ForEach(topics) { topic in
                        TopicComposerSuggestedTopicRow(topic: topic) {
                            onSelect(topic)
                        }
                    }
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicComposerSuggestedTopicRow 候选话题行
// 核心职责：
// - 展示候选话题名称和更新信息
// - 提供添加到发布草稿的按钮
private struct TopicComposerSuggestedTopicRow: View {
    let topic: TopicSummary
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            TopicAvatarView(assetName: topic.thumbnailAssetName, showUnreadDot: false)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(topic.displayName)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text(topic.updateText)
                    .font(MHBTheme.Typography.section)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onSelect()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: MHBTheme.Spacing.s8, height: MHBTheme.Spacing.s8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加话题")
        }
    }
}
