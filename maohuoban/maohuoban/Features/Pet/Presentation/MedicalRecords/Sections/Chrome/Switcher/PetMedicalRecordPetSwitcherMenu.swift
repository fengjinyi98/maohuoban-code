import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordPetSwitcherMenu 病历记录宠物切换菜单
// 核心职责：
// - 在顶部栏右侧展示当前宠物
// - 使用原生 Menu 承载多宠切换动作
struct PetMedicalRecordPetSwitcherMenu: View {
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
                isDisabled: false
            )
        }
        .disabled(isDisabled)
        .accessibilityIdentifier("pet.medicalRecord.petSwitcherButton")
    }
}
