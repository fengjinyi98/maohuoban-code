import SwiftUI
import MaohuobanDesignSystem

// HomeImmersiveUserAvatarButton 首页沉浸式用户头像按钮
// 核心职责：
// - 展示当前登录用户头像入口
// - 将点击事件转发给上层导航协调器
struct HomeImmersiveUserAvatarButton: View {
    let avatarURL: String?
    let fallbackAssetName: String
    let displayName: String
    let action: () -> Void

    private let size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HomeImmersiveUserAvatarImage(
                avatarURL: avatarURL,
                fallbackAssetName: fallbackAssetName
            )
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(MHBTheme.ColorToken.primaryBackground.color)
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(MHBTheme.ColorToken.primary.color, lineWidth: 2)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开我的主页，\(displayName)")
        .accessibilityIdentifier("home.userAvatarButton")
    }
}

// HomeImmersiveUserAvatarImage 首页用户头像图片
// 核心职责：
// - 优先渲染远端头像
// - 在头像缺失或加载失败时使用本地 mock 资源兜底
private struct HomeImmersiveUserAvatarImage: View {
    let avatarURL: String?
    let fallbackAssetName: String

    var body: some View {
        if let url = resolvedURL {
            MHBRemoteImage(url: url, contentMode: .fill) {
                Image(fallbackAssetName)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            Image(fallbackAssetName)
                .resizable()
                .scaledToFill()
        }
    }

    private var resolvedURL: URL? {
        guard let avatarURL, avatarURL.isEmpty == false else {
            return nil
        }

        return MHBBackendEndpoint.resolve(avatarURL)
    }
}
