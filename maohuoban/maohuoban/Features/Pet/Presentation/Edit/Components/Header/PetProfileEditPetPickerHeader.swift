import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileEditPetPickerHeader 编辑资料宠物切换头部
// 核心职责：
// - 横向展示当前可编辑宠物头像入口
// - 承载宠物切换和添加宠物入口
struct PetProfileEditPetPickerHeader: View {
    let profiles: [PetProfileEditProfile]
    let selectedProfileID: String
    let displayName: (PetProfileEditProfile) -> String
    let displaySexText: (PetProfileEditProfile) -> String
    let avatarImage: (PetProfileEditProfile) -> UIImage?
    let avatarUploadState: PetMediaUploadSlotState
    let onSelectProfile: (String) -> Void
    let onPreviewSelectedAvatar: (String) -> Void
    let onAddPet: () -> Void

    private let avatarSize: CGFloat = 78

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
                ForEach(profiles) { profile in
                    PetProfileEditPetPickerItem(
                        profile: profile,
                        displayName: displayName(profile),
                        sexText: displaySexText(profile),
                        localAvatarImage: avatarImage(profile),
                        uploadState: profile.id == selectedProfileID ? avatarUploadState : .idle,
                        isSelected: profile.id == selectedProfileID,
                        avatarSize: avatarSize,
                        action: {
                            if profile.id == selectedProfileID {
                                onPreviewSelectedAvatar(profile.id)
                            } else {
                                onSelectProfile(profile.id)
                            }
                        }
                    )
                    .accessibilityIdentifier("pet.profileEdit.petPicker.\(profile.id)")
                }

                PetProfileEditAddPetItem(
                    avatarSize: avatarSize,
                    action: onAddPet
                )
                .accessibilityIdentifier("pet.profileEdit.addPet")
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
        }
        .padding(.horizontal, -MHBTheme.Spacing.s4)
        .padding(.top, MHBTheme.Spacing.s3)
    }
}

// PetProfileEditPetPickerItem 编辑资料宠物头像切换项
// 核心职责：
// - 展示单只宠物的头像和名称
// - 通过选中态表达当前正在编辑的宠物档案
struct PetProfileEditPetPickerItem: View {
    let profile: PetProfileEditProfile
    let displayName: String
    let sexText: String
    let localAvatarImage: UIImage?
    let uploadState: PetMediaUploadSlotState
    let isSelected: Bool
    let avatarSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                avatar

                Text(displayName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: avatarSize + 12)
                    .opacity(isSelected ? 0 : 1)
                    .accessibilityHidden(isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "预览并编辑\(displayName)头像" : "切换到\(displayName)")
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            PetProfileEditAvatarImage(
                avatarURL: profile.avatarURL,
                localAvatarImage: localAvatarImage,
                species: profile.species,
                size: avatarSize
            )
            .overlay {
                PetMediaUploadProgressOverlay(state: uploadState)
                    .clipShape(Circle())
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        PetProfileEditAvatarBorderSex(sexText: sexText).color,
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }

            if isSelected {
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
        }
    }
}

// PetProfileEditAvatarBorderSex 编辑头像边框性别样式
// 核心职责：
// - 归一化编辑页性别文案
// - 为头像边框提供稳定性别色
enum PetProfileEditAvatarBorderSex: Hashable {
    case male
    case female
    case unknown

    init(sexText: String) {
        switch sexText.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "公", "男":
            self = .male
        case "母", "女":
            self = .female
        default:
            self = .unknown
        }
    }

    var color: Color {
        switch self {
        case .male:
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case .female:
            Color(red: 244 / 255, green: 63 / 255, blue: 94 / 255)
        case .unknown:
            MHBTheme.ColorToken.separatorSoft.color
        }
    }
}

// PetProfileEditAddPetItem 编辑资料添加宠物入口
// 核心职责：
// - 在宠物头像横滑区域展示添加入口
// - 为后续接入创建宠物流程保留点击边界
struct PetProfileEditAddPetItem: View {
    let avatarSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                Circle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }

                Text("添加宠物")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .frame(width: avatarSize + 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加宠物")
    }
}
