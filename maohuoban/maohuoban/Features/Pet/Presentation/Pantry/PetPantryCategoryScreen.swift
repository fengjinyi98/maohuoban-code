import SwiftUI
import MaohuobanDesignSystem

// PetPantryCategoryScreen 宠物储物柜分类详情页
// 核心职责：
// - 展示特定分类下的物品列表
struct PetPantryCategoryScreen<Route: Hashable>: View {
    let petID: String
    let petName: String
    let category: PantryCategory
    let currentUserID: String?
    let onNavigate: (PetPantryRoute) -> Route

    @State private var store = PetFoodInventoryStore()
    @State private var selectedItem: PantryItem?
    @State private var editingItem: PantryItem?

    var filteredItems: [PantryItem] {
        store.pantryItems.filter { $0.category == category }
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(spacing: MHBTheme.Spacing.s5) {
                        galleryGrid
                            .padding(.horizontal, MHBTheme.Spacing.s5)
                            .padding(.top, MHBTheme.Spacing.s4)

                        if !store.archivedPantryItems(for: category).isEmpty {
                            PetPantryArchivedRestoreSection(
                                items: store.archivedPantryItems(for: category),
                                restoreTitle: "恢复到未拆封",
                                onRestore: { itemID in
                                    guard let currentUserID else { return }
                                    Task {
                                        _ = await store.restoreItem(
                                            itemID: itemID,
                                            status: .sealed,
                                            currentUserID: currentUserID
                                        )
                                    }
                                }
                            )
                            .padding(.horizontal, MHBTheme.Spacing.s5)
                        }

                        Spacer(minLength: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                    }
                }

                MHBBottomFloatingCTA(
                    title: "添加物品",
                    systemImage: "plus",
                    route: onNavigate(.addItem),
                    bottomInset: bottomInset
                )
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: currentUserID) {
            guard let currentUserID else { return }
            await store.loadItems(currentUserID: currentUserID, petID: petID)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: PetFoodInventoryMutationSignal.notificationName
            )
        ) { _ in
            guard let currentUserID else { return }
            Task {
                await store.loadItems(currentUserID: currentUserID, petID: petID)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // TODO: 搜索功能
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                }
            }
        }
        .sheet(item: $editingItem) { item in
            EditPantryItemScreen(
                item: item,
                currentUserID: currentUserID,
                onSaved: {
                    guard let currentUserID else { return }
                    Task {
                        await store.loadItems(currentUserID: currentUserID, petID: petID)
                    }
                }
            )
        }
    }

    private var galleryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
                GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
            ],
            spacing: MHBTheme.Spacing.s4
        ) {
            ForEach(filteredItems) { item in
                Button {
                    selectedItem = item
                } label: {
                    PantryItemCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $selectedItem) { item in
            PantryItemActionSheet(
                item: item,
                onMarkSealed: { itemID in
                    guard let currentUserID else { return }
                    Task {
                        _ = await store.markItemStatus(
                            itemID: itemID,
                            status: .sealed,
                            currentUserID: currentUserID
                        )
                        selectedItem = nil
                    }
                },
                onEdit: { item in
                    editingItem = item
                    selectedItem = nil
                },
                onArchive: { itemID in
                    guard let currentUserID else { return }
                    Task {
                        _ = await store.archiveItem(itemID: itemID, currentUserID: currentUserID)
                        selectedItem = nil
                    }
                },
                onRestock: { itemID, quantity in
                    guard let currentUserID else { return }
                    Task {
                        _ = await store.restockItem(itemID: itemID, quantity: quantity, currentUserID: currentUserID)
                        selectedItem = nil
                    }
                },
                onSetCurrentStaple: { itemID in
                    guard let currentUserID else { return }
                    Task {
                        _ = await store.setCurrentStaple(
                            petID: petID,
                            foodItemID: itemID,
                            currentUserID: currentUserID
                        )
                        selectedItem = nil
                    }
                },
                onSetTrying: { itemID in
                    setFoodAssignment(itemID: itemID, role: .trying)
                },
                onSetUsualTreat: { itemID in
                    setFoodAssignment(itemID: itemID, role: .usualTreat)
                },
                onSetUsualNutrition: { itemID in
                    setFoodAssignment(itemID: itemID, role: .usualNutrition)
                },
                onSetNotSuitable: { itemID in
                    setFoodAssignment(itemID: itemID, role: .notSuitable)
                }
            )
                .presentationDetents([.height(540)])
                .presentationDragIndicator(.visible)
        }
    }

    private func setFoodAssignment(itemID: String, role: PetDietAssignmentRole) {
        guard let currentUserID else { return }
        Task {
            _ = await store.setFoodAssignment(
                petID: petID,
                foodItemID: itemID,
                role: role,
                currentUserID: currentUserID
            )
            selectedItem = nil
        }
    }
}
