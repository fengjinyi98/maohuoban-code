import SwiftUI
import MaohuobanDesignSystem

// PetManagementPetAvatar 我的宠物列表头像
// 核心职责：
// - 展示本地或远端宠物头像资源
// - 在头像缺失时按物种提供稳定兜底视觉
struct PetManagementPetAvatar: View {
    let assetName: String?
    let avatarURL: String?
    let species: PetProfileEditProfile.Species

    private let size: CGFloat = 60
    private let cornerRadius: CGFloat = 18
 
    var body: some View {
        ZStack {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL, let url = MHBBackendEndpoint.resolve(avatarURL) {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    fallbackAvatar
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1.5)
        }
    }

    private var fallbackAvatar: some View {
        Image(systemName: species.systemImage)
            .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MHBTheme.ColorToken.primaryBackground.color)
    }
}
