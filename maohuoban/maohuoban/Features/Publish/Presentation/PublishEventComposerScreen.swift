import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishEventComposerScreen 图文发布页面
// 核心职责：
// - 承载图文模式发布草稿的完整前端编辑体验
// - 组合媒体、正文、话题和发布配置分区
struct PublishEventComposerScreen: View {
    let context: PublishEntryContext
    let onPrepared: () -> Void

    @State private var store: PublishDraftStore
    @State private var selectedImages: [PublishSelectedImage] = []
    @State private var isMediaPickerPresented = false
    @State private var activeSheet: PublishComposerSheet?
    @State private var draftTopicName = ""

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

        MHBScreenScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                if store.phase == .prepared, let successMessage = store.successMessage {
                    PublishPreparedBanner(message: successMessage)
                }

                PublishMediaPickerSection(
                    selectedImages: selectedImages,
                    canAddMore: selectedImages.count < PublishComposerLimits.maxImageCount,
                    onAdd: openMediaPicker,
                    onRemove: removeImage(_:)
                )

                PublishDraftEditorSection(
                    title: $draftStore.titleText,
                    bodyText: $draftStore.bodyText
                )

                PublishTopicSection(
                    topicNames: store.draft.topicNames,
                    draftTopicName: $draftTopicName,
                    onAddTopic: addDraftTopic,
                    onRemoveTopic: store.removeTopic(named:)
                )

                PublishConfigurationSection(
                    selectedPetName: store.draft.selectedPetName,
                    eventType: store.draft.eventType,
                    locationTitle: resolvedLocationTitle,
                    visibility: store.draft.visibility,
                    onSelectPet: { activeSheet = .pet },
                    onSelectEventType: { activeSheet = .eventType },
                    onSelectLocation: { activeSheet = .location },
                    onSelectVisibility: { activeSheet = .visibility }
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("发布动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("发布", action: prepareDraft)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(
                        store.canPrepareDraft
                            ? MHBTheme.ColorToken.primary.color
                            : MHBTheme.ColorToken.labelTertiary.color
                    )
                    .disabled(!store.canPrepareDraft)
            }
        }
        .sheet(isPresented: $isMediaPickerPresented) {
            MHBSystemMediaPicker(
                request: MHBMediaPickerRequest(
                    maxSelectionCount: PublishComposerLimits.maxImageCount - selectedImages.count,
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("publish.eventComposer.screen")
    }

    private var resolvedLocationTitle: String? {
        if let localEntityName = store.draft.localEntityName, !localEntityName.isEmpty {
            return localEntityName
        }
        if let city = store.draft.city, !city.isEmpty {
            return city
        }
        return nil
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
        case .eventType:
            PublishEventTypeSelectionSheet(
                selectedEventType: store.draft.eventType,
                onSelect: { eventType in
                    store.selectEventType(eventType)
                    activeSheet = nil
                }
            )
        case .location:
            PublishLocationSelectionSheet(
                selectedTitle: resolvedLocationTitle,
                onSelect: { option in
                    store.selectLocation(city: option.city, localEntityName: option.title)
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
        }
    }

    private func openMediaPicker() {
        guard selectedImages.count < PublishComposerLimits.maxImageCount else {
            return
        }
        isMediaPickerPresented = true
    }

    private func handleMediaPickerResult(_ result: MHBMediaPickerResult) {
        isMediaPickerPresented = false
        let remainingCount = max(0, PublishComposerLimits.maxImageCount - selectedImages.count)
        let newImages = result.images
            .prefix(remainingCount)
            .map { PublishSelectedImage(image: $0) }
        selectedImages.append(contentsOf: newImages)
        store.updateMediaCount(selectedImages.count)
    }

    private func removeImage(_ id: UUID) {
        selectedImages.removeAll { $0.id == id }
        store.updateMediaCount(selectedImages.count)
    }

    private func addDraftTopic() {
        store.addTopic(named: draftTopicName)
        draftTopicName = ""
    }

    private func prepareDraft() {
        store.prepareDraft()
        if store.phase == .prepared {
            onPrepared()
        }
    }
}

// PublishComposerSheet 发布页配置弹层类型
// 核心职责：
// - 管理发布页配置项弹层的展示状态
private enum PublishComposerSheet: String, Identifiable {
    case pet
    case eventType
    case location
    case visibility

    var id: String { rawValue }
}

// PublishSelectedImage 发布页本地图片预览模型
// 核心职责：
// - 为图文发布媒体横排提供稳定身份
// - 承载本轮前端选择的本地图片
struct PublishSelectedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// PublishComposerLimits 发布页本地限制
// 核心职责：
// - 统一约束图文模式首版媒体数量
private enum PublishComposerLimits {
    static let maxImageCount = 9
}
