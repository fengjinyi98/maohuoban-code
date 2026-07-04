import MaohuobanDesignSystem

// PetRecordPetSpeciesAvatarMapping 记录宠物物种头像映射
// 核心职责：
// - 将记录上下文物种转换为头像基础设施物种
// - 避免记录详情页面重复散写物种映射
extension PetRecordPetSpecies {
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
