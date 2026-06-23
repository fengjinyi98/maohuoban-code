import Foundation

// MHBAvatarDisplayResolver 头像展示决策器
// 核心职责：
// - 固化宠物 Feed 和评论头像优先展示人宠融合的业务规则
// - 将业务选择从 SwiftUI 渲染组件中拆出为纯函数
nonisolated enum MHBAvatarDisplayResolver {
    static func feedAuthorSubject(
        user: MHBAvatarUser,
        pets: [MHBAvatarPet],
        preferredPetID: String?
    ) -> MHBAvatarSubject {
        guard pets.isEmpty == false else {
            return .user(user)
        }

        if let preferredPetID,
           let preferredPet = pets.first(where: { $0.id == preferredPetID }) {
            return .petWithUser(pet: preferredPet, user: user)
        }

        return .petWithUser(pet: pets[0], user: user)
    }
}
