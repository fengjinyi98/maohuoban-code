import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileAddAvatarHeader 添加宠物头像入口
// 核心职责：
// - 展示添加页顶部头像占位
// - 承接添加页头像预览和选择入口
struct PetProfileAddAvatarHeader: View {
    let species: PetSpecies
    let localAvatarImage: UIImage?
    let uploadState: PetMediaUploadSlotState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                ZStack(alignment: .bottomTrailing) {
                    avatarContent
                        .overlay {
                            PetMediaUploadProgressOverlay(state: uploadState)
                        }
                        .clipShape(Circle())

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
                }

                Text(localAvatarImage == nil ? "添加头像" : "查看头像")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, MHBTheme.Spacing.s2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let localAvatarImage {
            Image(uiImage: localAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(MHBTheme.ColorToken.primaryBackground.color)
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: speciesSystemImage)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
        }
    }

    private var speciesSystemImage: String {
        switch species {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .other: "pawprint.fill"
        }
    }
}
