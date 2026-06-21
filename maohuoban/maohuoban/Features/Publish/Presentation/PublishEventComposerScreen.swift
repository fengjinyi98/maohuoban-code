import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishEventComposerScreen 图文发布页面
// 核心职责：
// - 结合小红书设计风格重构整体布局，去除冗余大间距
// - 在系统导航栏承载发布模式切换和关联宠物入口
// - 将发布/存草稿操作和各个发布配置项融合为流畅的列表与底栏
struct PublishEventComposerScreen: View {
    let context: PublishEntryContext
    let onPrepared: () -> Void

    @State private var store: PublishDraftStore
    @State private var selectedImages: [PublishSelectedImage] = []
    @State private var articleBlocks: [PublishArticleBlock] = []
    @State private var composerMode: PublishComposerMode = .gallery
    @State private var selectedAlbumTitle: String? = "日常相册"
    @State private var isMediaPickerPresented = false
    @State private var activeSheet: PublishComposerSheet?
    @State private var pendingInsertedArticleMediaIDs: [UUID] = []
    @State private var replacingArticleBlockID: UUID?
    @State private var pendingTopicInsertionNonce = 0
    @State private var pendingMentionInsertionNonce = 0
    @State private var pendingMentionInsertionText: String?

    // 环境 dismissal 用于支持点击“存草稿”时直接关闭发布页面
    @Environment(\.dismiss) private var dismiss

    // 话题候选策略 发布页话题预选数据
    // 核心职责：
    // - 当前前端阶段使用冷启动占位话题，展示基础宠物日常话题
    // - 后端接入后仅在有活动时展示活动推荐话题，否则优先展示用户上次输入过的话题
    // - 用户数据积累后由后端替换为基于正文输入和历史行为的智能推荐
    private let suggestedTags = ["#萌宠日常", "#猫咪日常", "#新手养猫", "#宠物同城", "#铲屎官日常"]

    init(
        context: PublishEntryContext,
        onPrepared: @escaping () -> Void = {}
    ) {
        self.context = context
        self.onPrepared = onPrepared
        _store = State(initialValue: PublishDraftStore(context: context))
    }

    var body: some View {
        @Bindable var draftStore = store

        GeometryReader { geometry in
            MHBScreenScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                    if store.phase == .prepared, let successMessage = store.successMessage {
                        PublishPreparedBanner(message: successMessage)
                    }

                    // 紧凑的内容编辑组合区
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                        // 编辑器内容表面 (图文与画廊呈现不同排版结构)
                        PublishComposerEditorSurface(
                            mode: composerMode,
                            selectedImages: selectedImages,
                            canAddMore: selectedImages.count < PublishComposerLimits.maxImageCount,
                            pendingInsertedArticleMediaIDs: pendingInsertedArticleMediaIDs,
                            pendingTopicInsertionNonce: pendingTopicInsertionNonce,
                            pendingMentionInsertionNonce: pendingMentionInsertionNonce,
                            pendingMentionInsertionText: pendingMentionInsertionText,
                            title: $draftStore.titleText,
                            bodyText: $draftStore.bodyText,
                            articleBlocks: $articleBlocks,
                            onPendingArticleMediaInsertionHandled: handlePendingArticleMediaInsertionHandled(_:),
                            onPendingTopicInsertionHandled: handlePendingTopicInsertionHandled,
                            onPendingMentionInsertionHandled: handlePendingMentionInsertionHandled,
                            onTopicsChange: handleTopicsChange(_:),
                            onAddMedia: openMediaPicker,
                            onInsertTopic: insertTopic,
                            onMentionUser: openMentionUserPicker,
                            onDismissKeyboard: dismissKeyboard,
                            onRemoveMedia: removeImage(_:),
                            onRemoveArticleImageBlock: removeArticleImageBlock(_:),
                            onReplaceArticleImageBlock: replaceArticleImageBlock(_:)
                        )

                        // 话题候选水平滚动栏
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: MHBTheme.Spacing.s2) {
                                ForEach(suggestedTags, id: \.self) { tag in
                                    Button {
                                        appendTag(tag)
                                    } label: {
                                        Text(tag)
                                            .font(MHBTheme.Typography.caption)
                                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                                            .padding(.horizontal, MHBTheme.Spacing.s3)
                                            .padding(.vertical, 6)
                                            .background(MHBTheme.ColorToken.separatorSoft.color)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, MHBTheme.Spacing.s4)
                        }
                        .padding(.horizontal, -MHBTheme.Spacing.s4)
                    }

                    // 表单设置行列表（小红书同款风格）
                    VStack(spacing: 0) {
                        Divider()
                            .background(MHBTheme.ColorToken.separatorSoft.color)

                        // 标记地点
                        PublishConfigurationRow(
                            assetIconName: "IconLocationPin",
                            iconColor: MHBTheme.ColorToken.labelSecondary.color,
                            title: "标记地点",
                            value: resolvedLocationTitle,
                            action: { activeSheet = .location }
                        )

                        Divider()
                            .background(MHBTheme.ColorToken.separatorSoft.color)

                        // 公开可见 (可见范围)
                        PublishConfigurationRow(
                            iconName: "eye.fill",
                            iconColor: MHBTheme.ColorToken.labelSecondary.color,
                            title: "公开可见",
                            value: store.draft.visibility.title,
                            action: { activeSheet = .visibility }
                        )

                        Divider()
                            .background(MHBTheme.ColorToken.separatorSoft.color)

                        // 同步存入相册 (点击打开选择相册的 Sheet，不再是 Switch 开关)
                        PublishConfigurationRow(
                            iconName: "folder.fill",
                            iconColor: MHBTheme.ColorToken.labelSecondary.color,
                            title: "存入宠物相册",
                            value: selectedAlbumTitle,
                            action: { activeSheet = .album }
                        )
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, 40 + MHBTheme.Spacing.s2 * 2 + geometry.safeAreaInsets.bottom + MHBTheme.Spacing.s4)
            }
            .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
            .overlay(alignment: .bottom) {
            // 底部固定操作栏（小红书同款非对称宽度设计，发动态宽，存草稿窄，和帖子详情页底部操作栏一样贯通至屏幕底部，不单独把安全区域分离）
            HStack(spacing: MHBTheme.Spacing.s3) {
                Button {
                    // 存草稿：直接 dismiss 返回
                    dismiss()
                } label: {
                    Text("存草稿")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 110)
                        .frame(height: 40)
                        .background(MHBTheme.ColorToken.cardSolid.color)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("publish.action.saveDraft")

                Button {
                    prepareDraft()
                } label: {
                    Text("发布动态")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            store.canPrepareDraft
                                ? MHBTheme.ColorToken.primary.color
                                : MHBTheme.ColorToken.primary.color.opacity(0.5)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!store.canPrepareDraft)
                .accessibilityIdentifier("publish.action.submit")
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s2)
            .padding(.bottom, MHBTheme.Spacing.s2 + geometry.safeAreaInsets.bottom)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 0))
            .ignoresSafeArea(edges: .bottom)
        }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                PublishComposerModePicker(selection: $composerMode)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .pet
                } label: {
                    Text("关联宠物")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(
                            store.draft.selectedPetID == nil
                                ? MHBTheme.ColorToken.labelSecondary.color
                                : MHBTheme.ColorToken.primary.color
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关联宠物")
            }
        }
        .sheet(isPresented: $isMediaPickerPresented) {
            MHBSystemMediaPicker(
                request: MHBMediaPickerRequest(
                    maxSelectionCount: mediaPickerMaxSelectionCount,
                    filter: .images
                ),
                onComplete: handleMediaPickerResult(_:),
                onCancel: {
                    isMediaPickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $activeSheet) { sheet in
            optionSheet(for: sheet)
                .presentationDetents(sheet.presentationDetents)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: composerMode) { _, newMode in
            if newMode == .richText {
                seedArticleBlocksFromDraftIfNeeded()
            } else {
                syncDraftBodyTextFromArticleBlocksIfNeeded()
            }
        }
        .onChange(of: articleBlocks) { _, _ in
            syncDraftBodyTextFromArticleBlocksIfNeeded()
        }
        .accessibilityIdentifier("publish.eventComposer.screen")
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var resolvedLocationTitle: String? {
        if let locationName = store.draft.location?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
           !locationName.isEmpty {
            return locationName
        }
        if let localEntityName = store.draft.localEntityName, !localEntityName.isEmpty {
            return localEntityName
        }
        if let city = store.draft.city, !city.isEmpty {
            return city
        }
        return nil
    }

    private var mediaPickerMaxSelectionCount: Int {
        if replacingArticleBlockID != nil {
            return 1
        }
        return max(0, PublishComposerLimits.maxImageCount - selectedImages.count)
    }

    @ViewBuilder
    private func optionSheet(for sheet: PublishComposerSheet) -> some View {
        switch sheet {
        case .pet:
            PublishPetSelectionSheet(
                selectedPetID: store.draft.selectedPetID,
                onSelect: { option in
                    store.selectPet(id: option.id, name: option.title)
                    activeSheet = nil
                }
            )
        case .location:
            PublishLocationPickerSheet(
                selectedLocation: store.draft.location,
                onSelectLocation: store.selectLocation(_:),
                onDismiss: {
                    activeSheet = nil
                }
            )
        case .visibility:
            PublishVisibilitySelectionSheet(
                selectedVisibility: store.draft.visibility,
                onSelect: { visibility in
                    store.selectVisibility(visibility)
                    activeSheet = nil
                }
            )
        case .album:
            PublishAlbumSelectionSheet(
                selectedAlbumTitle: selectedAlbumTitle,
                onSelect: { option in
                    selectedAlbumTitle = option.title
                    activeSheet = nil
                }
            )
        case .mentionUser:
            PublishMentionUserSelectionSheet(
                onCancel: {
                    activeSheet = nil
                },
                onConfirm: { users in
                    insertMentions(users)
                    activeSheet = nil
                }
            )
        }
    }

    private func openMediaPicker() {
        replacingArticleBlockID = nil
        guard selectedImages.count < PublishComposerLimits.maxImageCount else {
            return
        }
        isMediaPickerPresented = true
    }

    private func handleMediaPickerResult(_ result: MHBMediaPickerResult) {
        isMediaPickerPresented = false
        if let replacingArticleBlockID {
            handleArticleImageReplacement(
                blockID: replacingArticleBlockID,
                image: result.images.first
            )
            return
        }

        let remainingCount = max(0, PublishComposerLimits.maxImageCount - selectedImages.count)
        let newImages = result.images
            .prefix(remainingCount)
            .map { PublishSelectedImage(image: $0) }
        selectedImages.append(contentsOf: newImages)
        if composerMode == .richText {
            pendingInsertedArticleMediaIDs.append(contentsOf: newImages.map(\.id))
        }
        store.updateMediaCount(selectedImages.count)
    }

    private func removeImage(_ id: UUID) {
        selectedImages.removeAll { $0.id == id }
        articleBlocks.removeAll { $0.mediaID == id }
        pendingInsertedArticleMediaIDs.removeAll { $0 == id }
        store.updateMediaCount(selectedImages.count)
    }

    private func removeArticleImageBlock(_ blockID: UUID) {
        guard let block = articleBlocks.first(where: { $0.id == blockID }) else { return }
        articleBlocks.removeAll { $0.id == blockID }
        if let mediaID = block.mediaID {
            selectedImages.removeAll { $0.id == mediaID }
            pendingInsertedArticleMediaIDs.removeAll { $0 == mediaID }
        }
        store.updateMediaCount(selectedImages.count)
    }

    private func replaceArticleImageBlock(_ blockID: UUID) {
        replacingArticleBlockID = blockID
        isMediaPickerPresented = true
    }

    private func handleArticleImageReplacement(blockID: UUID, image: UIImage?) {
        defer {
            replacingArticleBlockID = nil
            store.updateMediaCount(selectedImages.count)
        }
        guard let image,
              let blockIndex = articleBlocks.firstIndex(where: { $0.id == blockID })
        else {
            return
        }

        let previousMediaID = articleBlocks[blockIndex].mediaID
        let replacement = PublishSelectedImage(image: image)
        if let previousMediaID,
           let imageIndex = selectedImages.firstIndex(where: { $0.id == previousMediaID }) {
            selectedImages[imageIndex] = replacement
        } else {
            selectedImages.append(replacement)
        }
        articleBlocks[blockIndex].mediaID = replacement.id
    }

    private func prepareDraft() {
        store.prepareDraft()
        if store.phase == .prepared {
            onPrepared()
        }
    }

    private func insertTopic() {
        pendingTopicInsertionNonce += 1
    }

    private func openMentionUserPicker() {
        activeSheet = .mentionUser
    }

    private func dismissKeyboard() {
        MHBKeyboardDismissal.dismissActiveKeyboard()
    }

    private func insertMentions(_ users: [PublishMentionUserOption]) {
        let insertionText = users
            .map { "@\($0.name) " }
            .joined()
        guard insertionText.isEmpty == false else { return }
        pendingMentionInsertionText = insertionText
        pendingMentionInsertionNonce += 1
    }

    private func handlePendingArticleMediaInsertionHandled(_ mediaIDs: [UUID]) {
        pendingInsertedArticleMediaIDs.removeAll { mediaIDs.contains($0) }
    }

    private func handlePendingTopicInsertionHandled() {}

    private func handlePendingMentionInsertionHandled() {
        pendingMentionInsertionText = nil
    }

    private func handleTopicsChange(_ topicNames: [String]) {
        store.updateTopics(topicNames)
    }

    private func appendTag(_ tag: String) {
        guard composerMode == .gallery else {
            appendTagToArticleBlocks(tag)
            store.addTopic(named: tag)
            return
        }

        let currentText = store.draft.bodyText
        if currentText.isEmpty {
            store.updateBodyText(tag + " ")
        } else if currentText.hasSuffix(" ") {
            store.updateBodyText(currentText + tag + " ")
        } else {
            store.updateBodyText(currentText + " " + tag + " ")
        }
        store.addTopic(named: tag)
    }

    private func appendTagToArticleBlocks(_ tag: String) {
        if let index = articleBlocks.lastIndex(where: { $0.kind == .text }) {
            let currentText = articleBlocks[index].text
            if currentText.isEmpty {
                articleBlocks[index].text = tag + " "
            } else if currentText.hasSuffix(" ") || currentText.hasSuffix("\n") {
                articleBlocks[index].text = currentText + tag + " "
            } else {
                articleBlocks[index].text = currentText + " " + tag + " "
            }
        } else {
            articleBlocks.append(PublishArticleBlock(kind: .text, text: tag + " "))
        }
    }

    private func seedArticleBlocksFromDraftIfNeeded() {
        guard articleBlocks.isEmpty else { return }

        var nextBlocks: [PublishArticleBlock] = []
        let bodyText = store.draft.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if bodyText.isEmpty == false {
            nextBlocks.append(PublishArticleBlock(kind: .text, text: bodyText))
        }

        for selectedImage in selectedImages {
            nextBlocks.append(
                PublishArticleBlock(
                    kind: .image,
                    mediaID: selectedImage.id
                )
            )
        }

        articleBlocks = nextBlocks
    }

    private func syncDraftBodyTextFromArticleBlocksIfNeeded() {
        guard composerMode == .richText else { return }
        let nextBodyText = articleBlocksPlainText()
        guard store.draft.bodyText != nextBodyText else { return }
        store.updateBodyText(nextBodyText)
    }

    private func articleBlocksPlainText() -> String {
        articleBlocks.compactMap { block in
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        .joined(separator: "\n")
    }
}

// PublishConfigurationIcon 发布配置行图标来源
// 核心职责：
// - 区分系统 SF Symbol 和项目资产图标
// - 为发布配置行提供统一的图标渲染入口
private enum PublishConfigurationIcon {
    case system(String)
    case asset(String)
}

// PublishConfigurationRow 小红书风格配置行
// 核心职责：
// - 渲染发布页配置入口的图标、标题和值
// - 承载点击后打开对应配置弹层的入口
private struct PublishConfigurationRow: View {
    let icon: PublishConfigurationIcon
    let iconColor: Color
    let title: String
    let value: String?
    let action: () -> Void

    init(
        iconName: String,
        iconColor: Color,
        title: String,
        value: String?,
        action: @escaping () -> Void
    ) {
        self.icon = .system(iconName)
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.action = action
    }

    init(
        assetIconName: String,
        iconColor: Color,
        title: String,
        value: String?,
        action: @escaping () -> Void
    ) {
        self.icon = .asset(assetIconName)
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PublishConfigurationIconView(icon: icon, color: iconColor)

                Text(title)
                    .font(MHBTheme.Typography.body.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                if let value {
                    Text(value)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// PublishConfigurationIconView 发布配置行图标视图
// 核心职责：
// - 根据图标来源渲染统一尺寸的行内图标
// - 保持资产图标和系统图标的主题色一致
private struct PublishConfigurationIconView: View {
    let icon: PublishConfigurationIcon
    let color: Color

    var body: some View {
        ZStack {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(color)
            case .asset(let name):
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .frame(width: MHBTheme.IconSize.small, height: MHBTheme.IconSize.small)
            }
        }
        .frame(width: 24, height: 24)
    }
}

// PublishComposerSheet 发布页配置弹层类型
private enum PublishComposerSheet: String, Identifiable {
    case pet
    case location
    case visibility
    case album
    case mentionUser

    var id: String { rawValue }

    var presentationDetents: Set<PresentationDetent> {
        switch self {
        case .location, .mentionUser:
            [.large]
        case .pet, .visibility, .album:
            [.medium]
        }
    }
}

// PublishSelectedImage 发布页本地图片预览模型
struct PublishSelectedImage: Identifiable {
    let id: UUID
    let image: UIImage

    init(id: UUID = UUID(), image: UIImage) {
        self.id = id
        self.image = image
    }
}

// PublishComposerLimits 发布页本地限制
private enum PublishComposerLimits {
    static let maxImageCount = 9
}
