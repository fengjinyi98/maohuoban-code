import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileUserEditScreen 用户资料编辑页
// 核心职责：
// - 以首页编辑档案页的 grouped 卡片样式承载用户资料字段
// - 为快速 UI 阶段提供可点击的编辑资料页面壳
struct ProfileUserEditScreen: View {
    let profile: ProfileUserHome
    @State private var editedAvatarImage: UIImage?
    @State private var editedCoverImage: UIImage?
    @State private var editedDisplayName: String
    @State private var editedGender: ProfileUserEditGenderOption?
    @State private var isGenderVisible = true
    @State private var editedRegionSelection: ProfileUserEditRegionSelection?
    @State private var editedBirthday: Date?
    @State private var editedBio: String
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

    init(profile: ProfileUserHome = .mock) {
        self.profile = profile
        _editedDisplayName = State(initialValue: profile.displayName)
        _editedGender = State(initialValue: ProfileUserEditGenderOption.fromSystemImage(profile.genderSystemImage))
        _editedRegionSelection = State(initialValue: nil)
        _editedBirthday = State(initialValue: nil)
        _editedBio = State(initialValue: profile.bio)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s6) {
                ProfileUserEditAvatarHeader(
                    displayName: editedDisplayName,
                    avatarAssetName: profile.avatarAssetName,
                    localAvatarImage: editedAvatarImage,
                    action: {
                        isAvatarPreviewPresented = true
                    }
                )

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
                                localCoverImage: editedCoverImage
                            )
                        }

                        PetProfileEditRow(
                            title: "昵称",
                            isAccessoryExpanded: isNameEditorChevronExpanded,
                            action: {
                                nameEditorDraft = editedDisplayName
                                isNameEditorChevronExpanded = true
                                isNameEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: editedDisplayName)
                        }

                        PetProfileEditRow(
                            title: "毛伙伴号",
                            showsSeparator: false,
                            action: {
                                isMaohuobanIDInfoPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: profile.maohuobanID)
                        }
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(
                            title: "性别",
                            isAccessoryExpanded: isGenderEditorChevronExpanded,
                            action: {
                                isGenderEditorChevronExpanded = true
                                isGenderEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(
                                value: ProfileUserEditDisplay.genderText(
                                    for: editedGender,
                                    isVisible: isGenderVisible
                                )
                            )
                        }

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

                        PetProfileEditRow(
                            title: "生日",
                            showsSeparator: false,
                            isAccessoryExpanded: isBirthdayEditorChevronExpanded,
                            action: {
                                birthdayEditorDraft = editedBirthday ?? Date.now
                                isBirthdayEditorChevronExpanded = true
                                isBirthdayEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(
                                value: editedBirthday.map(ProfileUserEditBirthdayDateCodec.string) ?? "未添加"
                            )
                        }
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(
                            title: "个人简介",
                            showsSeparator: false,
                            isAccessoryExpanded: isBioEditorChevronExpanded,
                            action: {
                                bioEditorDraft = editedBio
                                isBioEditorChevronExpanded = true
                                isBioEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: editedBio.isEmpty ? "未添加" : editedBio)
                        }
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
        .navigationDestination(isPresented: $isRegionPickerPresented) {
            ProfileUserRegionPickerScreen(selection: $editedRegionSelection)
                .onDisappear {
                    isRegionChevronExpanded = false
                }
        }
        .alert("毛伙伴号", isPresented: $isMaohuobanIDInfoPresented) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("毛伙伴号是毛伙伴为账号生成的平台内唯一身份编码，当前版本暂不支持修改。当前毛伙伴号：\(profile.maohuobanID)")
        }
        .sheet(
            isPresented: $isNameEditorPresented,
            onDismiss: {
                isNameEditorChevronExpanded = false
            }
        ) {
            ProfileUserNameEditorSheet(
                name: $nameEditorDraft,
                onWillDismiss: {
                    isNameEditorChevronExpanded = false
                },
                onSave: {
                    editedDisplayName = nameEditorDraft
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
                selectedGender: $editedGender,
                isGenderVisible: $isGenderVisible,
                onWillDismiss: {
                    isGenderEditorChevronExpanded = false
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
                    editedBirthday = birthdayEditorDraft
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
                onWillDismiss: {
                    isBioEditorChevronExpanded = false
                },
                onSave: {
                    editedBio = bioEditorDraft
                }
            )
        }
        .fullScreenCover(isPresented: $isAvatarPreviewPresented) {
            ProfileUserAvatarPreviewScreen(
                displayName: editedDisplayName,
                avatarAssetName: profile.avatarAssetName,
                localAvatarImage: editedAvatarImage,
                onAvatarUpdated: { image in
                    editedAvatarImage = image
                    return true
                }
            )
        }
        .fullScreenCover(isPresented: $isBackgroundPreviewPresented) {
            ProfileUserBackgroundPreviewScreen(
                displayName: editedDisplayName,
                coverAssetName: profile.coverAssetName,
                localCoverImage: editedCoverImage,
                onCoverUpdated: { image in
                    editedCoverImage = image
                    return true
                }
            )
        }
    }
}

// ProfileUserEditAvatarHeader 用户资料编辑头像头部
// 核心职责：
// - 对齐首页编辑档案页顶部头像编辑入口
// - 展示当前用户身份和头像编辑提示
private struct ProfileUserEditAvatarHeader: View {
    let displayName: String
    let avatarAssetName: String
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
        } else {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
        }
    }
}

// ProfileUserEditCoverValue 用户资料背景行值
// 核心职责：
// - 在资料编辑行右侧展示主页背景缩略图
// - 使用编辑档案页背景缩略图相同的比例和圆角
private struct ProfileUserEditCoverValue: View {
    let assetName: String
    let localCoverImage: UIImage?

    var body: some View {
        Group {
            if let localCoverImage {
                Image(uiImage: localCoverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
