import Foundation

// MerchantManagedPetAvatarPresentation 商家宠物头像展示映射
// 核心职责：
// - 将商家在管宠物摘要映射为通用宠物头像主体
// - 复用宠物物种和性别契约作为头像兜底与描边输入
extension MerchantManagedPet {
    var avatarSubject: MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: id,
                name: name,
                source: .empty,
                species: species.avatarSpecies,
                sex: sex.avatarSex
            )
        )
    }
}

private extension PetSpecies {
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

private extension PetSex {
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
