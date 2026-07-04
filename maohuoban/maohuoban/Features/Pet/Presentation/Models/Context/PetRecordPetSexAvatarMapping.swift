// PetRecordPetSexAvatarMapping 记录宠物性别头像映射
// 核心职责：
// - 将记录上下文性别转换为头像基础设施性别
// - 避免记录详情页面重复散写性别映射
extension PetRecordPetSex {
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
