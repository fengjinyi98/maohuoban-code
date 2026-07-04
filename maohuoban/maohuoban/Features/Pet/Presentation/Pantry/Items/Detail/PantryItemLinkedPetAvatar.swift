import SwiftUI
import MaohuobanDesignSystem

// PantryItemLinkedPetAvatar 关联宠物头像
// 核心职责：
// - 通过头像基础设施展示关联宠物头像
// - 保持物种兜底图标和性别边框一致
struct PantryItemLinkedPetAvatar: View {
    let petID: String
    let petName: String
    let avatarURLString: String?
    let species: PetRecordPetSpecies
    let sex: PetRecordPetSex

    var body: some View {
        MHBAvatar(
            subject: .pet(
                MHBAvatarPet(
                    id: petID,
                    name: petName,
                    source: avatarSource,
                    species: species.avatarSpecies,
                    sex: sex.avatarSex
                )
            ),
            size: .custom(40),
            shape: .circle
        )
    }

    private var avatarSource: MHBAvatarSource {
        guard let avatarURLString,
              let url = PantryMediaURLResolver.resolve(avatarURLString) else {
            return .empty
        }

        return .remote(url)
    }
}
