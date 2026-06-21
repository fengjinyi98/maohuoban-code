import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetAvatar AI 页面宠物头像
// 核心职责：
// - 在 AI 页面系统导航栏展示当前宠物上下文
// - 使用与首页一致的圆形远端头像和物种兜底图标
struct AIAssistantPetAvatar: View {
    let avatarURL: String?
    let species: AIAssistantPetSpecies
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(MHBTheme.ColorToken.primaryBackground.color)

            if let url = resolvedURL {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    fallbackIcon
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(MHBTheme.ColorToken.primary.color, lineWidth: 2)
        }
        .accessibilityIdentifier("ai.assistant.petAvatar")
    }

    private var fallbackIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: max(size * 0.42, 13), weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .frame(width: size, height: size)
    }

    private var iconName: String {
        switch species {
        case .dog: "pawprint.fill"
        case .cat: "cat.fill"
        case .other: "heart.fill"
        }
    }

    private var resolvedURL: URL? {
        guard let avatarURL, avatarURL.isEmpty == false else {
            return nil
        }

        return MHBBackendEndpoint.resolve(avatarURL)
    }
}
