import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordPetSwitcherToolbarItem 异常记录宠物切换工具栏控件
// 核心职责：
// - 在系统导航栏右侧展示当前宠物
// - 使用原生 Menu 承载多宠切换动作
struct PetAbnormalRecordPetSwitcherToolbarItem: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    Label(item.name, systemImage: item.isSelected ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: selectedItem,
                isDisabled: false,
                chrome: .toolbar
            )
        }
        .disabled(isDisabled)
        .accessibilityIdentifier("pet.abnormalRecord.petSwitcherButton")
    }
}

extension MHBPetSwitcherItem {
    init(abnormalRecordPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(abnormalRecordSpecies: pet.species),
            sex: MHBPetSwitcherSex(abnormalRecordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(abnormalRecordSpecies species: PetRecordPetSpecies) {
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
    init(abnormalRecordSex sex: PetRecordPetSex) {
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
