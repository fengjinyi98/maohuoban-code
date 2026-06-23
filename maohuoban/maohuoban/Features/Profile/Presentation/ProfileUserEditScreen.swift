import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileUserEditScreen 用户资料编辑页
// 核心职责：
// - 以首页编辑档案页的 grouped 卡片样式承载用户资料字段
// - 为快速 UI 阶段提供可点击的编辑资料页面壳
struct ProfileUserEditScreen: View {
    let profile: ProfileUserHome
    let currentUserStore: CurrentUserStore
    @State private var editedAvatarImage: UIImage?
    @State private var editedCoverImage: UIImage?
    @State private var editStore: ProfileUserEditStore
    @State private var genderEditorDraft: ProfileUserEditGenderOption?
    @State private var isGenderVisibleDraft = false
    @State private var editedRegionSelection: ProfileUserEditRegionSelection?
    @State private var isAvatarPreviewPresented = false
    @State private var isBackgroundPreviewPresented = false
    @State private var nameEditorDraft = ""
    @State private var isNameEditorPresented = false
    @State private var isNameEditorChevronExpanded = false
    @State private var isMaohuobanIDInfoPresented = false
    @State private var isGenderEditorPresented = false
    @State private var isGenderEditorChevronExpanded = false
    @State private var isRegionPickerPresented = false
    @State private var isRegionChevronExpanded = false
    @State private var birthdayEditorDraft = Date.now
    @State private var isBirthdayEditorPresented = false
    @State private var isBirthdayEditorChevronExpanded = false
    @State private var bioEditorDraft = ""
    @State private var isBioEditorPresented = false
    @State private var isBioEditorChevronExpanded = false

    init(
        profile: ProfileUserHome = .mock,
        currentUserStore: CurrentUserStore,
        editStore: ProfileUserEditStore? = nil
    ) {
        self.profile = profile
        self.currentUserStore = currentUserStore
        _editStore = State(
            initialValue: editStore ?? ProfileUserEditStore(currentUserStore: currentUserStore)
        )
        _genderEditorDraft = State(
            initialValue: ProfileUserEditGenderOption.fromStoredValue(currentUserStore.gender)
        )
        _editedRegionSelection = State(initialValue: nil)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s6) {
                ProfileUserEditAvatarHeader(
                    displayName: displayNameValue,
                    avatarAssetName: currentUserStore.avatarAssetName,
                    avatarURLString: currentUserStore.avatarURLString,
                    localAvatarImage: editedAvatarImage,
                    action: {
                        isAvatarPreviewPresented = true
                    }
                )
                .accessibilityIdentifier("profile.userEdit.avatarButton")

                VStack(spacing: MHBTheme.Spacing.s4) {
                    PetProfileEditSection {
                        PetProfileEditRow(
                            title: "主页背景",
                            action: {
                                isBackgroundPreviewPresented = true
                            }
                        ) {
                            ProfileUserEditCoverValue(
                                assetName: profile.coverAssetName,
                                coverURLString: currentUserStore.coverURLString,
                                localCoverImage: editedCoverImage
                            )
                        }
                        .accessibilityIdentifier("profile.userEdit.backgroundRow")

                        PetProfileEditRow(
                            title: "昵称",
                            isAccessoryExpanded: isNameEditorChevronExpanded,
                            action: {
                                nameEditorDraft = displayNameValue
                                isNameEditorChevronExpanded = true
                                isNameEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: displayNameValue)
                        }
                        .accessibilityIdentifier("profile.userEdit.nameRow")

                        PetProfileEditRow(
                            title: "毛伙伴号",
                            showsSeparator: false,
                            action: {
                                isMaohuobanIDInfoPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: maohuobanIDValue)
                        }
                        .accessibilityIdentifier("profile.userEdit.maohuobanIDRow")
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(
                            title: "性别",
                            isAccessoryExpanded: isGenderEditorChevronExpanded,
                            action: {
                                genderEditorDraft = currentGenderOption
                                isGenderVisibleDraft = currentGenderVisible
                                isGenderEditorChevronExpanded = true
                                isGenderEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(
                                value: ProfileUserEditDisplay.genderText(
                                    for: currentGenderOption,
                                    isVisible: currentGenderVisible
                                )
                            )
                        }
                        .accessibilityIdentifier("profile.userEdit.genderRow")

                        PetProfileEditRow(
                            title: "所在地",
                            isAccessoryExpanded: isRegionChevronExpanded,
                            action: {
                                isRegionChevronExpanded = true
                                isRegionPickerPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: editedRegionSelection?.displayText ?? "未添加")
                        }
                        .accessibilityIdentifier("profile.userEdit.regionRow")

                        PetProfileEditRow(
                            title: "生日",
                            showsSeparator: false,
                            isAccessoryExpanded: isBirthdayEditorChevronExpanded,
                            action: {
                                birthdayEditorDraft = birthdayDateValue ?? Date.now
                                isBirthdayEditorChevronExpanded = true
                                isBirthdayEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(
                                value: birthdayTextValue ?? "未添加"
                            )
                        }
                        .accessibilityIdentifier("profile.userEdit.birthdayRow")
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(
                            title: "个人简介",
                            showsSeparator: false,
                            isAccessoryExpanded: isBioEditorChevronExpanded,
                            action: {
                                bioEditorDraft = bioValue
                                isBioEditorChevronExpanded = true
                                isBioEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: bioValue.isEmpty ? "未添加" : bioValue)
                        }
                        .accessibilityIdentifier("profile.userEdit.bioRow")
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("profile.userEdit.screen")
        .task {
            let loaded = await editStore.load()
            if loaded == false {
                showProfileToast(success: false)
            }
        }
        .navigationDestination(isPresented: $isRegionPickerPresented) {
            ProfileUserRegionPickerScreen(selection: $editedRegionSelection)
                .onDisappear {
                    isRegionChevronExpanded = false
                }
        }
        .alert("毛伙伴号", isPresented: $isMaohuobanIDInfoPresented) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("毛伙伴号是毛伙伴为账号生成的平台内唯一身份编码，当前版本暂不支持修改。当前毛伙伴号：\(maohuobanIDValue)")
        }
        .sheet(
            isPresented: $isNameEditorPresented,
            onDismiss: {
                isNameEditorChevronExpanded = false
            }
        ) {
            ProfileUserNameEditorSheet(
                name: $nameEditorDraft,
                policyText: editStore.displayNameEditPolicyText,
                onWillDismiss: {
                    isNameEditorChevronExpanded = false
                },
                onSave: {
                    saveDisplayName()
                }
            )
        }
        .sheet(
            isPresented: $isGenderEditorPresented,
            onDismiss: {
                isGenderEditorChevronExpanded = false
            }
        ) {
            ProfileUserGenderEditorSheet(
                selectedGender: $genderEditorDraft,
                isGenderVisible: $isGenderVisibleDraft,
                onWillDismiss: {
                    isGenderEditorChevronExpanded = false
                },
                onSave: {
                    saveGender()
                }
            )
        }
        .sheet(
            isPresented: $isBirthdayEditorPresented,
            onDismiss: {
                isBirthdayEditorChevronExpanded = false
            }
        ) {
            PetProfileDateEditorSheet(
                title: "生日",
                date: $birthdayEditorDraft,
                onWillDismiss: {
                    isBirthdayEditorChevronExpanded = false
                },
                onSave: {
                    saveBirthday()
                }
            )
        }
        .sheet(
            isPresented: $isBioEditorPresented,
            onDismiss: {
                isBioEditorChevronExpanded = false
            }
        ) {
            ProfileUserBioEditorSheet(
                bio: $bioEditorDraft,
                policyText: editStore.bioEditPolicyText,
                onWillDismiss: {
                    isBioEditorChevronExpanded = false
                },
                onSave: {
                    saveBio()
                }
            )
        }
        .fullScreenCover(isPresented: $isAvatarPreviewPresented) {
            ProfileUserAvatarPreviewScreen(
                displayName: displayNameValue,
                avatarAssetName: currentUserStore.avatarAssetName,
                avatarURLString: currentUserStore.avatarURLString,
                localAvatarImage: editedAvatarImage,
                onAvatarUpdated: { image in
                    await uploadAvatarImage(image)
                }
            )
        }
        .fullScreenCover(isPresented: $isBackgroundPreviewPresented) {
            ProfileUserBackgroundPreviewScreen(
                displayName: displayNameValue,
                coverAssetName: profile.coverAssetName,
                coverURLString: currentUserStore.coverURLString,
                localCoverImage: editedCoverImage,
                onCoverUpdated: { image in
                    await uploadCoverImage(image)
                }
            )
        }
    }

    private var displayNameValue: String {
        currentUserStore.displayName
    }

    private var maohuobanIDValue: String {
        currentUserStore.maohuobanID
    }

    private var bioValue: String {
        currentUserStore.bio
    }

    private var currentGenderOption: ProfileUserEditGenderOption? {
        ProfileUserEditGenderOption.fromStoredValue(currentUserStore.gender)
    }

    private var currentGenderVisible: Bool {
        currentUserStore.isGenderVisible
    }

    private var birthdayTextValue: String? {
        currentUserStore.birthdayDisplayText ?? currentUserStore.birthday
    }

    private var birthdayDateValue: Date? {
        ProfileUserEditBirthdayDateCodec.date(from: currentUserStore.birthday ?? "")
    }

    private func saveDisplayName() {
        let value = nameEditorDraft
        Task {
            let saved = await editStore.updateDisplayName(value)
            showProfileToast(success: saved)
        }
    }

    private func saveBio() {
        let value = bioEditorDraft
        Task {
            let saved = await editStore.updateBio(value)
            showProfileToast(success: saved)
        }
    }

    private func saveGender() {
        let gender = genderEditorDraft?.rawValue ?? ProfileUserEditGenderOption.unknown.rawValue
        let isVisible = isGenderVisibleDraft
        Task {
            let saved = await editStore.updateGender(gender, isVisible: isVisible)
            showProfileToast(success: saved)
        }
    }

    private func saveBirthday() {
        let birthday = ProfileUserEditBirthdayDateCodec.string(from: birthdayEditorDraft)
        Task {
            let saved = await editStore.updateBirthday(birthday)
            showProfileToast(success: saved)
        }
    }

    private func showProfileToast(success: Bool) {
        guard let message = editStore.toastMessage else { return }
        if success {
            MHBToastPresenter().success(message)
        } else {
            MHBToastPresenter().danger(message)
        }
    }

    @MainActor
    private func uploadAvatarImage(_ image: UIImage) async -> Bool {
        guard let draft = mediaUploadDraft(
            from: image,
            fileName: "profile-avatar.png"
        ) else {
            editStore.toastMessage = "头像保存失败，请重试"
            showProfileToast(success: false)
            return false
        }

        let saved = await editStore.uploadAvatar(draft: draft)
        if saved {
            editedAvatarImage = image
        }
        showProfileToast(success: saved)
        return saved
    }

    @MainActor
    private func uploadCoverImage(_ image: UIImage) async -> Bool {
        guard let draft = mediaUploadDraft(
            from: image,
            fileName: "profile-cover.png"
        ) else {
            editStore.toastMessage = "背景保存失败，请重试"
            showProfileToast(success: false)
            return false
        }

        let saved = await editStore.uploadCover(draft: draft)
        if saved {
            editedCoverImage = image
        }
        showProfileToast(success: saved)
        return saved
    }

    private func mediaUploadDraft(
        from image: UIImage,
        fileName: String
    ) -> CurrentUserProfileMediaUploadDraft? {
        guard let data = image.pngData() else {
            return nil
        }

        return CurrentUserProfileMediaUploadDraft(
            fileName: fileName,
            mimeType: "image/png",
            content: data,
            sourceClient: "ios"
        )
    }
}

// ProfileUserEditAvatarHeader 用户资料编辑头像头部
// 核心职责：
// - 对齐首页编辑档案页顶部头像编辑入口
// - 展示当前用户身份和头像编辑提示
private struct ProfileUserEditAvatarHeader: View {
    let displayName: String
    let avatarAssetName: String
    let avatarURLString: String?
    let localAvatarImage: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 78, height: 78)
                        .background(MHBTheme.ColorToken.cardSolid.color)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                        }

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.78))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                        }
                        .offset(x: 1, y: 1)
                }

                Text(displayName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, MHBTheme.Spacing.s3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑头像")
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let localAvatarImage {
            Image(uiImage: localAvatarImage)
                .resizable()
                .scaledToFill()
        } else if let avatarURLString,
                  let url = MHBBackendEndpoint.resolve(avatarURLString) {
            MHBRemoteImage(url: url, contentMode: .fill) {
                fallbackAvatarImage
            }
        } else {
            fallbackAvatarImage
        }
    }

    private var fallbackAvatarImage: some View {
        Image(avatarAssetName)
            .resizable()
            .scaledToFill()
    }
}

// ProfileUserEditCoverValue 用户资料背景行值
// 核心职责：
// - 在资料编辑行右侧展示主页背景缩略图
// - 使用编辑档案页背景缩略图相同的比例和圆角
private struct ProfileUserEditCoverValue: View {
    let assetName: String
    let coverURLString: String?
    let localCoverImage: UIImage?

    var body: some View {
        Group {
            if let localCoverImage {
                Image(uiImage: localCoverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                remoteOrAssetCover
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var remoteOrAssetCover: some View {
        if let coverURLString,
           let url = MHBBackendEndpoint.resolve(coverURLString) {
            MHBRemoteImage(url: url, contentMode: .fill) {
                assetCover
            }
        } else {
            assetCover
        }
    }

    private var assetCover: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }
}

// ProfileUserEditDisplay 用户资料编辑展示文案
// 核心职责：
// - 将用户主页展示字段转换为编辑页右侧值
// - 保持当前快速 UI 阶段的文案映射集中
private enum ProfileUserEditDisplay {
    nonisolated static func genderText(
        for option: ProfileUserEditGenderOption?,
        isVisible: Bool
    ) -> String {
        guard isVisible else { return "不展示" }
        return option?.displayTitle ?? "未设置"
    }
}
