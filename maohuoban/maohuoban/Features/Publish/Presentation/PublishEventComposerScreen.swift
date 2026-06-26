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

    @State var store: PublishDraftStore
    @State var selectedImages: [PublishSelectedImage] = []
    @State var articleBlocks: [PublishArticleBlock] = []
    @State var composerMode: PublishComposerMode = .gallery
    @State var selectedAlbumTitle: String? = "日常相册"
    @State var isMediaPickerPresented = false
    @State var activeSheet: PublishComposerSheet?
    @State var pendingInsertedArticleMediaIDs: [UUID] = []
    @State var replacingArticleBlockID: UUID?
    @State var pendingTopicInsertionNonce = 0
    @State var pendingMentionInsertionNonce = 0
    @State var pendingMentionInsertionText: String?

    @Environment(\.dismiss) var dismiss

    let suggestedTags = ["#萌宠日常", "#猫咪日常", "#新手养猫", "#宠物同城", "#铲屎官日常"]

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
            MHBMediaPickerScreen(
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

    var resolvedLocationTitle: String? {
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

    var mediaPickerMaxSelectionCount: Int {
        if replacingArticleBlockID != nil {
            return 1
        }
        return max(0, PublishComposerLimits.maxImageCount - selectedImages.count)
    }

    @ViewBuilder
    func optionSheet(for sheet: PublishComposerSheet) -> some View {
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

}
