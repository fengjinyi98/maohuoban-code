import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileFavoriteFolderCreateScreen 新建收藏夹页面
// 核心职责：
// - 承载收藏夹封面、名称和私密状态输入
// - 通过模式复用新建收藏夹和编辑收藏夹入口
struct ProfileFavoriteFolderCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isPrivate = false
    @State private var isInputComposing = false
    @State private var selectedCoverImage: UIImage?
    @State private var isCoverPickerPresented = false

    let mode: ProfileFavoriteFolderCreateMode
    let onSubmit: (ProfileFavoriteFolderCreateDraft) -> Void

    init(
        mode: ProfileFavoriteFolderCreateMode = .create,
        onSubmit: @escaping (ProfileFavoriteFolderCreateDraft) -> Void = { _ in }
    ) {
        self.mode = mode
        self.onSubmit = onSubmit
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
                .accessibilityIdentifier("profile.favoriteFolder.create.coverButton")

                ProfileFavoriteFolderNameInputSection(
                    name: $name,
                    isInputComposing: $isInputComposing,
                    draft: draft,
                    onSubmit: createIfNeeded
                )

                ProfileFavoriteFolderPrivacySettingRow(isPrivate: $isPrivate)
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
                .disabled(!canCreate)
                .accessibilityIdentifier("profile.favoriteFolder.create.submitButton")
            }
        }
        .sheet(isPresented: $isCoverPickerPresented) {
            MHBPhotoLibraryPickerScreen(
                title: "选择封面",
                onComplete: handleCoverPickerResult,
                onCancel: {
                    isCoverPickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .accessibilityIdentifier("profile.favoriteFolder.create.screen")
    }

    private var draft: ProfileFavoriteFolderCreateDraft {
        ProfileFavoriteFolderCreateDraft(name: name, isPrivate: isPrivate)
    }

    private var canCreate: Bool {
        draft.canCreate && !isInputComposing
    }

    private var createButtonColor: Color {
        MHBTheme.ColorToken.labelPrimary.color.opacity(canCreate ? 1 : 0.35)
    }

    private func createIfNeeded() {
        guard canCreate else { return }
        onSubmit(draft)
        dismiss()
    }

    // handleCoverPickerResult 处理封面选择结果
    // 核心职责：
    // - 从相册选择结果提取封面预览图
    // - 将封面选择 sheet 收起
    private func handleCoverPickerResult(_ result: MHBMediaPickerResult) {
        isCoverPickerPresented = false
        if let coverImage = MHBCoverImageSelectionResolver.resolveImage(from: result) {
            selectedCoverImage = coverImage
        }
    }
}

// ProfileFavoriteFolderNameInputSection 收藏夹名称输入区
// 核心职责：
// - 承载收藏夹名称输入和示例提示
// - 展示 15 字限制和越界状态
private struct ProfileFavoriteFolderNameInputSection: View {
    @Binding var name: String
    @Binding var isInputComposing: Bool
    let draft: ProfileFavoriteFolderCreateDraft
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                MHBStableTextField(
                    "给收藏夹起个名字...",
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
                Text("例如：准备接的猫、新手干货等")
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
        .accessibilityIdentifier("profile.favoriteFolder.create.nameSection")
    }

    private var inputUnderlineColor: Color {
        draft.isNameLimitExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelPrimary.color
    }

    private var counterColor: Color {
        draft.isNameLimitExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelSecondary.color
    }
}

// ProfileFavoriteFolderPrivacySettingRow 收藏夹私密设置行
// 核心职责：
// - 展示私密收藏夹说明
// - 承载系统 Toggle 开关状态
private struct ProfileFavoriteFolderPrivacySettingRow: View {
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

                Text("开启后，仅你自己可以查看此收藏夹")
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
        .accessibilityIdentifier("profile.favoriteFolder.create.privacyRow")
    }
}
