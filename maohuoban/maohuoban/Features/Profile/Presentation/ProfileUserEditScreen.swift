import SwiftUI
import MaohuobanDesignSystem
import MaohuobanDiagnostics
import UIKit

// ProfileUserEditScreen 用户资料编辑页
// 核心职责：
// - 以首页编辑档案页的 grouped 卡片样式承载用户资料字段
// - 为快速 UI 阶段提供可点击的编辑资料页面壳
struct ProfileUserEditScreen: View {
    let profile: ProfileUserHome
    let currentUserStore: CurrentUserStore
    @State var editedAvatarImage: UIImage?
    @State var editedCoverImage: UIImage?
    @State var editStore: ProfileUserEditStore
    @State var genderEditorDraft: ProfileUserEditGenderOption?
    @State var isGenderVisibleDraft = false
    @State private var editedRegionSelection: ProfileUserEditRegionSelection?
    @State private var isAvatarPreviewPresented = false
    @State private var isBackgroundPreviewPresented = false
    @State var nameEditorDraft = ""
    @State private var isNameEditorPresented = false
    @State private var isNameEditorChevronExpanded = false
    @State private var isMaohuobanIDInfoPresented = false
    @State private var isGenderEditorPresented = false
    @State private var isGenderEditorChevronExpanded = false
    @State private var isRegionPickerPresented = false
    @State private var isRegionChevronExpanded = false
    @State var birthdayEditorDraft = Date.now
    @State private var isBirthdayEditorPresented = false
    @State private var isBirthdayEditorChevronExpanded = false
    @State var bioEditorDraft = ""
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
}
