import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishEventComposerScreen 图文发布页面
// 核心职责：
// - 结合小红书设计风格重构整体布局，去除冗余大间距
// - 保留选择宠物 (`PublishPetContextBar`) 核心上下文入口
// - 保留头部导航栏 `PublishComposerModePicker` 模式切换
// - 将发布/存草稿操作和各个发布配置项融合为流畅的列表与底栏
struct PublishEventComposerScreen: View {
    let context: PublishEntryContext
    let onPrepared: () -> Void

    @State private var store: PublishDraftStore
    @State private var selectedImages: [PublishSelectedImage] = []
    @State private var composerMode: PublishComposerMode = .richText
    @State private var selectedAlbumTitle: String? = "日常相册"
    @State private var isMediaPickerPresented = false
    @State private var activeSheet: PublishComposerSheet?
    @State private var draftTopicName = ""

    // 环境 dismissal 用于支持点击“存草稿”时直接关闭发布页面
    @Environment(\.dismiss) private var dismiss

    // 推荐的常用宠物话题标签
    private let suggestedTags = ["#萌宠日常", "#猫咪成长", "#新手养猫", "#宠物同城", "#铲屎官日常"]

    // 推荐的常用地点
    private var suggestedLocations: [String] {
        let city = context.city ?? "同城"
        return ["\(city)同城", "萌宠公园", "宠物大世界", "爱心宠物医院"]
    }

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
                    // 关联宠物选择条 (选择宠物保持不变)
                    PublishPetContextBar(
                        selectedPetName: store.draft.selectedPetName,
                        source: context.source,
                        onSelectPet: { activeSheet = .pet }
                    )

                    // 编辑器内容表面 (图文与画廊呈现不同排版结构)
                    PublishComposerEditorSurface(
                        mode: composerMode,
                        selectedImages: selectedImages,
                        canAddMore: selectedImages.count < PublishComposerLimits.maxImageCount,
                        title: $draftStore.titleText,
                        bodyText: $draftStore.bodyText,
                        onAddMedia: openMediaPicker,
                        onRemoveMedia: removeImage(_:)
                    )

                    // 推荐话题标签水平滚动栏
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

                    // 互动操作药丸行（# 话题，@ 用户，📊 投票）
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Button {
                            activeSheet = .topic
                        } label: {
                            HStack(spacing: 4) {
                                Text("#")
                                    .font(.system(size: 16, weight: .bold))
                                Text("话题")
                                    .font(MHBTheme.Typography.caption.weight(.medium))
                            }
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .padding(.horizontal, MHBTheme.Spacing.s3)
                            .frame(height: 32)
                            .background(MHBTheme.ColorToken.separatorSoft.color)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("参与话题")

                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Text("@")
                                    .font(.system(size: 14, weight: .bold))
                                Text("用户")
                                    .font(MHBTheme.Typography.caption.weight(.medium))
                            }
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .padding(.horizontal, MHBTheme.Spacing.s3)
                            .frame(height: 32)
                            .background(MHBTheme.ColorToken.separatorSoft.color)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 12))
                                Text("投票")
                                    .font(MHBTheme.Typography.caption.weight(.medium))
                            }
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .padding(.horizontal, MHBTheme.Spacing.s3)
                            .frame(height: 32)
                            .background(MHBTheme.ColorToken.separatorSoft.color)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 表单设置行列表（小红书同款风格）
                VStack(spacing: 0) {
                    Divider()
                        .background(MHBTheme.ColorToken.separatorSoft.color)

                    // 标记地点
                    PublishConfigurationRow(
                        iconName: "mappin.and.ellipse",
                        iconColor: MHBTheme.ColorToken.labelSecondary.color,
                        title: "标记地点",
                        value: resolvedLocationTitle,
                        action: { activeSheet = .location }
                    )

                    // 推荐地点快捷水平滑动栏 (只有未标记地点时展示，匹配小红书细节)
                    if resolvedLocationTitle == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: MHBTheme.Spacing.s2) {
                                ForEach(suggestedLocations, id: \.self) { locName in
                                    Button {
                                        store.selectLocation(city: context.city, localEntityName: locName)
                                    } label: {
                                        Text(locName)
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
                        .padding(.bottom, MHBTheme.Spacing.s2)
                    }

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
        case .topic:
            PublishTopicEditingSheet(
                topicNames: store.draft.topicNames,
                draftTopicName: $draftTopicName,
                onAddTopic: addDraftTopic,
                onRemoveTopic: store.removeTopic(named:)
            )
        case .album:
            PublishAlbumSelectionSheet(
                selectedAlbumTitle: selectedAlbumTitle,
                onSelect: { option in
                    selectedAlbumTitle = option.title
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

    private func appendTag(_ tag: String) {
        let currentText = store.draft.bodyText
        if currentText.isEmpty {
            store.updateBodyText(tag + " ")
        } else if currentText.hasSuffix(" ") {
            store.updateBodyText(currentText + tag + " ")
        } else {
            store.updateBodyText(currentText + " " + tag + " ")
        }
    }
}

// PublishConfigurationRow 小红书风格配置行
private struct PublishConfigurationRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: iconName)
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)

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

// PublishComposerSheet 发布页配置弹层类型
private enum PublishComposerSheet: String, Identifiable {
    case pet
    case location
    case visibility
    case topic
    case album

    var id: String { rawValue }
}

// PublishSelectedImage 发布页本地图片预览模型
struct PublishSelectedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// PublishComposerLimits 发布页本地限制
private enum PublishComposerLimits {
    static let maxImageCount = 9
}
