import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetAlbumCreateScreen 新建相册页面
// 核心职责：
// - 承载相册封面、名称和私密状态输入
// - 通过模式复用新建相册和编辑相册入口
struct PetAlbumCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isPrivate = false
    @State private var isInputComposing = false
    @State private var isSubmitting = false
    @State private var selectedCoverImage: UIImage?
    @State private var isCoverPickerPresented = false
    @State private var coverCropTarget: MHBIdentifiableUIImage?

    let store: PetAlbumStore
    let mode: PetAlbumCreateMode

    init(
        store: PetAlbumStore,
        mode: PetAlbumCreateMode = .create,
    ) {
        self.store = store
        self.mode = mode
        _name = State(initialValue: mode.initialName)
        _isPrivate = State(initialValue: mode.initialIsPrivate)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s8) {
                MHBCoverImagePickerButton(
                    selectedImage: selectedCoverImage,
                    initialImageAssetName: mode.initialCoverImageAssetName
                ) {
                    isCoverPickerPresented = true
                }
                .accessibilityIdentifier("petAlbum.create.coverButton")

                PetAlbumNameInputSection(
                    name: $name,
                    isInputComposing: $isInputComposing,
                    draft: draft,
                    onSubmit: createIfNeeded
                )

                PetAlbumPrivacySettingRow(isPrivate: $isPrivate)
            }
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .padding(.top, MHBTheme.Spacing.s8)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(mode.submitTitle) {
                    createIfNeeded()
                }
                .font(MHBTheme.Typography.callout.weight(.bold))
                .foregroundStyle(createButtonColor)
                .disabled(!canCreate || isSubmitting)
                .accessibilityIdentifier("petAlbum.create.submitButton")
            }
        }
        .fullScreenCover(isPresented: $isCoverPickerPresented) {
            MHBMediaPickerScreen(
                title: "选择封面",
                onComplete: handleCoverPickerResult,
                onCancel: {
                    isCoverPickerPresented = false
                }
            )
        }
        .fullScreenCover(item: $coverCropTarget) { target in
            MHBRectImageCropScreen(
                originalImage: target.image,
                title: "裁剪相册封面",
                cropAspectRatio: 1,
                onCancel: {
                    coverCropTarget = nil
                },
                onSave: handleCroppedCover
            )
        }
        .accessibilityIdentifier("petAlbum.create.screen")
    }

    private var draft: PetAlbumCreateDraft {
        PetAlbumCreateDraft(name: name, isPrivate: isPrivate)
    }

    private var canCreate: Bool {
        draft.canCreate && !isInputComposing
    }

    private var createButtonColor: Color {
        MHBTheme.ColorToken.labelPrimary.color.opacity(canCreate ? 1 : 0.35)
    }

    private func createIfNeeded() {
        guard canCreate else { return }
        isSubmitting = true
        Task {
            let didSubmit: Bool
            switch mode {
            case .create:
                didSubmit = await store.createAlbum(draft: draft, coverUploadDraft: coverUploadDraft())
            case .edit(let context):
                didSubmit = await store.updateAlbum(albumID: context.albumID, draft: draft)
            }
            isSubmitting = false
            if didSubmit {
                dismiss()
            }
        }
    }

    // coverUploadDraft 构建相册封面上传草稿
    // 核心职责：
    // - 在用户提交事件中将本地封面图编码为上传文件
    // - 复用统一媒资上传编码策略
    private func coverUploadDraft() -> PetMediaUploadDraft? {
        guard let selectedCoverImage,
              let encoded = MHBMediaUploadEncoder.encode(
                image: selectedCoverImage,
                purpose: .ugcImage,
                fileName: "pet-album-cover"
              )
        else {
            return nil
        }

        return PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
    }

    // handleCoverPickerResult 处理封面选择结果
    // 核心职责：
    // - 从相册选择结果提取封面预览图
    // - 将封面选择 sheet 收起
    private func handleCoverPickerResult(_ result: MHBMediaPickerResult) {
        isCoverPickerPresented = false
        if let coverImage = MHBCoverImageSelectionResolver.resolveImage(from: result) {
            coverCropTarget = MHBIdentifiableUIImage(image: coverImage)
        }
    }

    // handleCroppedCover 处理相册封面裁剪结果
    // 核心职责：
    // - 关闭封面裁剪流程
    // - 将裁剪后的正方形图片作为待上传封面
    private func handleCroppedCover(_ image: UIImage) {
        coverCropTarget = nil
        selectedCoverImage = image
    }
}

// PetAlbumNameInputSection 相册名称输入区
// 核心职责：
// - 承载相册名称输入和示例提示
// - 展示 15 字限制和越界状态
private struct PetAlbumNameInputSection: View {
    @Binding var name: String
    @Binding var isInputComposing: Bool
    let draft: PetAlbumCreateDraft
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                MHBStableTextField(
                    "给相册起个名字...",
                    text: $name,
                    isComposing: $isInputComposing,
                    font: .systemFont(ofSize: 24, weight: .bold),
                    textColor: MHBTheme.ColorToken.labelPrimary.uiColor,
                    returnKeyType: .done,
                    onSubmit: onSubmit
                )
                .frame(maxWidth: .infinity, minHeight: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s1)

                Rectangle()
                    .fill(inputUnderlineColor)
                    .frame(height: 2)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("例如：睡颜大赏、成长记录等")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(2)

                Spacer(minLength: MHBTheme.Spacing.s3)

                Text(draft.counterText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(counterColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier("petAlbum.create.nameSection")
    }

    private var inputUnderlineColor: Color {
        draft.isNameLimitExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelPrimary.color
    }

    private var counterColor: Color {
        draft.isNameLimitExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelSecondary.color
    }
}

// PetAlbumPrivacySettingRow 相册私密设置行
// 核心职责：
// - 展示私密相册说明
// - 承载系统 Toggle 开关状态
private struct PetAlbumPrivacySettingRow: View {
    @Binding var isPrivate: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Label {
                    Text("设为私密")
                        .font(MHBTheme.Typography.body.weight(.bold))
                } icon: {
                    Image(systemName: "lock.fill")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                }
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("开启后，仅你自己可以查看此相册")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            Toggle("", isOn: $isPrivate)
                .labelsHidden()
                .tint(MHBTheme.ColorToken.labelPrimary.color)
                .accessibilityLabel("设为私密")
        }
        .padding(.vertical, MHBTheme.Spacing.s5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
        .accessibilityIdentifier("petAlbum.create.privacyRow")
    }
}
