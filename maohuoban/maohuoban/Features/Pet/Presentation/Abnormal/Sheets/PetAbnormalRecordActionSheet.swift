import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetAbnormalRecordDetailTimelineSections

// PetAbnormalRecordActionSheet 异常事件动作表单
// 核心职责：
// - 承载追加观察和标记恢复的表单输入
// - 通过 PetAbnormalDetailStore 提交真实事件
struct PetAbnormalRecordActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let action: PetAbnormalRecordDetailAction
    let store: PetAbnormalDetailStore
    @Binding var observationNote: String
    @Binding var recoveryNote: String
    let petID: String?
    let currentUserID: String?
    @State private var attachmentStore = PetEventAttachmentUploadStore()
    @State private var isPhotoPickerPresented = false
    @State private var selectedPresentationDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let bottomInset = proxy.safeAreaInsets.bottom

                ZStack(alignment: .topLeading) {
                    MHBTheme.ColorToken.background.color
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                            PetAbnormalRecordActionSheetHeader(action: action)

                            PetAbnormalActionFormField(
                                action: action,
                                observationNote: $observationNote,
                                recoveryNote: $recoveryNote
                            )

                            if action == .addObservation {
                                HomeQuickFactOptionalPhotoSection(
                                    title: "照片（可选）",
                                    attachments: attachmentStore.attachments,
                                    canAddMore: attachmentStore.canAddMore,
                                    onAdd: {
                                        isPhotoPickerPresented = true
                                    },
                                    onRemove: attachmentStore.removeAttachment(id:),
                                    onRetry: { id in
                                        Task {
                                            await attachmentStore.retryAttachment(
                                                id: id,
                                                currentUserID: currentUserID
                                            )
                                        }
                                    }
                                )
                            }

                            if let message = actionMessage {
                                Text(message)
                                    .font(MHBTheme.Typography.caption)
                                    .foregroundStyle(
                                        store.actionPhase == .failed(message) ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.success.color
                                    )
                            }
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, topContentPadding)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .zIndex(0)

                    MHBBottomFloatingActionCTA(
                        title: submitTitle,
                        systemImage: store.isSubmitting ? nil : "checkmark",
                        bottomInset: bottomInset
                    ) {
                        Task { await submit() }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .zIndex(2)

                    PetAbnormalRecordActionSheetTopChrome(
                        title: action.title,
                        onClose: { dismiss() }
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, Self.topChromeTopPadding)
                    .zIndex(3)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large], selection: $selectedPresentationDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .interactiveDismissDisabled(store.isSubmitting)
        .fullScreenCover(isPresented: $isPhotoPickerPresented) {
            MHBMediaPickerScreen(
                title: "添加照片",
                request: MHBMediaPickerRequest(
                    maxSelectionCount: attachmentStore.remainingSelectionCount,
                    filter: .images,
                    autoConfirmSingleSelection: attachmentStore.remainingSelectionCount == 1,
                    showsCameraEntry: false
                ),
                onComplete: handlePhotoPickerResult(_:),
                onCancel: {
                    isPhotoPickerPresented = false
                }
            )
        }
    }

    private var topContentPadding: CGFloat {
        Self.topChromeTopPadding + Self.topChromeHeight + MHBTheme.Spacing.s5
    }

    private static var topChromeTopPadding: CGFloat {
        MHBTheme.Spacing.s4
    }

    private static var topChromeHeight: CGFloat {
        48
    }

    private var submitTitle: String {
        if store.isSubmitting {
            return "提交中"
        }
        if attachmentStore.isUploading {
            return "照片上传中"
        }
        if attachmentStore.hasFailedUploads {
            return "照片需处理"
        }
        return switch action {
        case .addObservation: "追加观察"
        case .linkClinicVisit: "关联就诊"
        case .markRecovered: "标记恢复"
        }
    }

    private var actionMessage: String? {
        switch store.actionPhase {
        case .succeeded(let msg): msg
        case .failed(let msg): msg
        default: nil
        }
    }

    private func submit() async {
        guard !store.isSubmitting,
              !attachmentStore.isUploading,
              !attachmentStore.hasFailedUploads,
              let petID
        else { return }

        switch action {
        case .addObservation:
            await store.addObservation(
                petID: petID,
                note: observationNote,
                currentUserID: currentUserID,
                lifeStatus: nil,
                attachmentAssetIDs: attachmentStore.uploadedAssetIDs
            )
        case .markRecovered:
            await store.markRecovered(
                petID: petID,
                note: recoveryNote,
                currentUserID: currentUserID,
                lifeStatus: nil
            )
        case .linkClinicVisit:
            break
        }
    }

    private func handlePhotoPickerResult(_ result: MHBMediaPickerResult) {
        isPhotoPickerPresented = false
        Task {
            await attachmentStore.uploadPickedImages(
                result.images,
                localIdentifiers: result.imageLocalIdentifiers,
                currentUserID: currentUserID
            )
        }
    }
}

// PetAbnormalRecordActionSheetTopChrome 异常动作弹层顶部控件
// 核心职责：
// - 在原生 sheet 顶部固定标题和关闭入口
// - 对齐首页喂食 sheet 的自定义顶部 chrome 布局
private struct PetAbnormalRecordActionSheetTopChrome: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("关闭")

                Spacer()
            }
        }
        .frame(height: 48)
    }
}

// PetAbnormalRecordActionSheetHeader 异常动作弹层头部
// 核心职责：
// - 展示当前动作的图标、标题和说明
// - 作为滚动内容的一部分，避免与系统导航栏重叠
private struct PetAbnormalRecordActionSheetHeader: View {
    let action: PetAbnormalRecordDetailAction

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: action.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(action.tint)
                .frame(width: 56, height: 56)
                .background(action.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(action.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(action.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// PetAbnormalActionFormField 动作表单输入
// 核心职责：
// - 根据动作类型展示不同的表单字段
struct PetAbnormalActionFormField: View {
    let action: PetAbnormalRecordDetailAction
    @Binding var observationNote: String
    @Binding var recoveryNote: String

    var body: some View {
        switch action {
        case .addObservation:
            HomeQuickFactSheetSection(title: "观察内容") {
                TextField(
                    "观察内容",
                    text: $observationNote,
                    prompt: Text("例如 精神、食欲、排便变化"),
                    axis: .vertical
                )
                    .lineLimit(4...7)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                            .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
            }
        case .markRecovered:
            HomeQuickFactSheetSection(title: "恢复表现") {
                TextField(
                    "恢复表现",
                    text: $recoveryNote,
                    prompt: Text("例如 精神恢复、食欲变好"),
                    axis: .vertical
                )
                    .lineLimit(4...7)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                            .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
            }
        case .linkClinicVisit:
            Text("关联就诊功能将在后续版本接入")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
    }
}
