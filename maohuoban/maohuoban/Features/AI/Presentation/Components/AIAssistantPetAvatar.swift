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
    var shape: MHBAvatarShape = .circle

    var body: some View {
        MHBAvatar(
            subject: AIAssistantPetAvatarPresentation.avatarSubject(
                avatarURL: avatarURL,
                species: species
            ),
            size: .custom(size),
            shape: shape
        )
        .accessibilityIdentifier("ai.assistant.petAvatar")
    }
}

// AIAssistantPetAvatarPresentation AI 宠物头像展示映射器
// 核心职责：
// - 将 AI 宠物上下文映射为通用宠物头像主体
// - 收敛远端头像、物种兜底和未知性别输入
enum AIAssistantPetAvatarPresentation {
    static func avatarSubject(
        avatarURL: String?,
        species: AIAssistantPetSpecies
    ) -> MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: "ai-assistant-pet",
                name: "当前宠物",
                source: avatarSource(avatarURL: avatarURL),
                species: species.avatarSpecies,
                sex: .unknown
            )
        )
    }

    private static func avatarSource(avatarURL: String?) -> MHBAvatarSource {
        guard let avatarURL,
              avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let url = MHBBackendEndpoint.resolve(avatarURL) else {
            return .empty
        }

        return .remote(url)
    }
}

private extension AIAssistantPetSpecies {
    var avatarSpecies: MHBAvatarSpecies {
        switch self {
        case .dog:
            .dog
        case .cat:
            .cat
        case .other:
            .other
        }
    }
}
