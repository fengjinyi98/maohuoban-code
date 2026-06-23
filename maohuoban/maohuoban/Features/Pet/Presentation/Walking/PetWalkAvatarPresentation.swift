import Foundation

// PetWalkAvatarPresentation 遛弯宠物头像展示映射器
// 核心职责：
// - 将遛弯上下文映射为通用宠物头像主体
// - 收敛远端头像、性别描边和宠物兜底输入
enum PetWalkAvatarPresentation {
    static func avatarSubject(
        id: String,
        name: String,
        url: URL?,
        sex: PetRecordPetSex
    ) -> MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: id,
                name: name,
                source: url.map { .remote($0) } ?? .empty,
                species: .other,
                sex: sex.avatarSex
            )
        )
    }
}

private extension PetRecordPetSex {
    var avatarSex: MHBAvatarSex {
        switch self {
        case .female:
            .female
        case .male:
            .male
        case .unknown:
            .unknown
        }
    }
}
