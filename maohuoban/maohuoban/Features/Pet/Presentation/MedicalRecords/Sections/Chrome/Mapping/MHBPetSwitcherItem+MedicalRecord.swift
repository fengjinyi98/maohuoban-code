import MaohuobanDesignSystem

// MHBPetSwitcherItem 病历记录宠物切换映射
// 核心职责：
// - 将记录入口宠物上下文转换为宠物切换组件展示模型
// - 保持病历记录页复用统一宠物切换基础设施
extension MHBPetSwitcherItem {
    init(medicalRecordPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(medicalRecordSpecies: pet.species),
            sex: MHBPetSwitcherSex(medicalRecordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(medicalRecordSpecies species: PetRecordPetSpecies) {
        switch species {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBPetSwitcherSex {
    init(medicalRecordSex sex: PetRecordPetSex) {
        switch sex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
