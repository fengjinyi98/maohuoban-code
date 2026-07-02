import SwiftUI
import MaohuobanDesignSystem

// PetManagementScreen 我的宠物管理页
// 核心职责：
// - 按设计稿展示当前用户的宠物档案列表
// - 转发宠物行与添加入口点击事件给所属 Tab 导航路径
struct PetManagementScreen: View {
    let pets: [PetManagementPet]
    let onOpenPet: (PetManagementPet) -> Void
    let onAddPet: () -> Void

    @State private var sortOrder = PetManagementSortOrder.companionshipDescending

    init(
        pets: [PetManagementPet] = PetManagementPet.mockPets,
        onOpenPet: @escaping (PetManagementPet) -> Void,
        onAddPet: @escaping () -> Void
    ) {
        self.pets = pets
        self.onOpenPet = onOpenPet
        self.onAddPet = onAddPet
    }

    var body: some View {
        MHBScreenScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortOrder.sorted(pets)) { pet in
                    PetManagementPetRow(pet: pet) {
                        onOpenPet(pet)
                    }
                }

                PetManagementAddPetRow(action: onAddPet)
            }
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .navigationTitle("我的宠物")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sortOrder = sortOrder.next
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel(sortOrder.accessibilityLabel)
                .accessibilityIdentifier("pet.management.sortButton")
            }
        }
        .accessibilityIdentifier("pet.management.screen")
    }
}
