import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileUserEditScreen 用户资料编辑页
// 核心职责：
// - 以首页编辑档案页的 grouped 卡片样式承载用户资料字段
// - 为快速 UI 阶段提供可点击的编辑资料页面壳
struct ProfileUserEditScreen: View {
    let profile: ProfileUserHome

    init(profile: ProfileUserHome = .mock) {
        self.profile = profile
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s6) {
                ProfileUserEditAvatarHeader(
                    displayName: profile.displayName,
                    avatarAssetName: profile.avatarAssetName
                )

                VStack(spacing: MHBTheme.Spacing.s4) {
                    PetProfileEditSection {
                        PetProfileEditRow(title: "头像") {
                            ProfileUserEditAvatarValue(assetName: profile.avatarAssetName)
                        }

                        PetProfileEditRow(title: "主页背景") {
                            ProfileUserEditCoverValue(assetName: profile.coverAssetName)
                        }

                        PetProfileEditRow(title: "昵称") {
                            PetProfileEditValueText(value: profile.displayName)
                        }

                        PetProfileEditRow(title: "毛伙伴号", showsSeparator: false) {
                            PetProfileEditValueText(value: profile.petID)
                        }
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(title: "性别") {
                            PetProfileEditValueText(value: ProfileUserEditDisplay.genderText(for: profile.genderSystemImage))
                        }

                        PetProfileEditRow(title: "所在地") {
                            PetProfileEditValueText(value: "未添加")
                        }

                        PetProfileEditRow(title: "生日", showsSeparator: false) {
                            PetProfileEditValueText(value: "未添加")
                        }
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(title: "个人简介", showsSeparator: false) {
                            PetProfileEditValueText(value: profile.bio)
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
    }
}

// ProfileUserEditAvatarHeader 用户资料编辑头像头部
// 核心职责：
// - 对齐首页编辑档案页顶部头像编辑入口
// - 展示当前用户身份和头像编辑提示
private struct ProfileUserEditAvatarHeader: View {
    let displayName: String
    let avatarAssetName: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            ZStack(alignment: .bottomTrailing) {
                Image(avatarAssetName)
                    .resizable()
                    .scaledToFill()
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
        .accessibilityElement(children: .combine)
    }
}

// ProfileUserEditAvatarValue 用户资料头像行值
// 核心职责：
// - 在资料编辑行右侧展示当前头像缩略图
// - 保持与编辑档案页媒体值的紧凑尺度一致
private struct ProfileUserEditAvatarValue: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: 42, height: 42)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
            }
    }
}

// ProfileUserEditCoverValue 用户资料背景行值
// 核心职责：
// - 在资料编辑行右侧展示主页背景缩略图
// - 使用编辑档案页背景缩略图相同的比例和圆角
private struct ProfileUserEditCoverValue: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: 54, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// ProfileUserEditDisplay 用户资料编辑展示文案
// 核心职责：
// - 将用户主页展示字段转换为编辑页右侧值
// - 保持当前快速 UI 阶段的文案映射集中
private enum ProfileUserEditDisplay {
    nonisolated static func genderText(for systemImage: String) -> String {
        switch systemImage {
        case "person.fill":
            return "未设置"
        case "figure.dress.line.vertical.figure":
            return "女"
        default:
            return "未设置"
        }
    }
}
