import SwiftUI
import MaohuobanDesignSystem

// PetPantryCategoryScreen 用户储物柜分类详情页
// 核心职责：
// - 展示用户储物柜中特定分类下的物品列表
// - 在入口携带宠物上下文时提供饮食配置动作
struct PetPantryCategoryScreen<Route: Hashable>: View {
    let context: PetPantryEntryContext
    let category: PantryCategory
    let currentUserID: String?
    let onNavigate: (PetPantryRoute) -> Route
    var onOpenRoute: (Route) -> Void = { _ in }

    @State private var store = PetFoodInventoryStore()
    @State private var selectedItem: PantryItem?

    var filteredItems: [PantryItem] {
        store.pantryItems.filter { $0.category == category }
    }

    init(
        context: PetPantryEntryContext,
        category: PantryCategory,
        currentUserID: String?,
        onNavigate: @escaping (PetPantryRoute) -> Route,
        onOpenRoute: @escaping (Route) -> Void = { _ in }
    ) {
        self.context = context
        self.category = category
        self.currentUserID = currentUserID
        self.onNavigate = onNavigate
        self.onOpenRoute = onOpenRoute
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
            await store.loadItems(currentUserID: currentUserID, contextPetID: context.sourcePetID)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: PetFoodInventoryMutationSignal.notificationName
            )
        ) { _ in
            guard let currentUserID else { return }
            Task {
                await store.loadItems(currentUserID: currentUserID, contextPetID: context.sourcePetID)
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
                allowsDietAssignment: context.sourcePetID != nil,
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
                    selectedItem = nil
                    guard let inventoryItem = store.items.first(where: { $0.id == item.id }) else { return }
                    Task { @MainActor in
                        await Task.yield()
                        onOpenRoute(onNavigate(.editItem(inventoryItem)))
                    }
                },
                onDelete: { itemID in
                    guard let currentUserID else { return }
                    Task {
                        _ = await store.deleteItem(itemID: itemID, currentUserID: currentUserID)
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
                    guard let currentUserID, let sourcePetID = context.sourcePetID else { return }
                    Task {
                        _ = await store.setCurrentStaple(
                            petID: sourcePetID,
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
        guard let currentUserID, let sourcePetID = context.sourcePetID else { return }
        Task {
            _ = await store.setFoodAssignment(
                petID: sourcePetID,
                foodItemID: itemID,
                role: role,
                currentUserID: currentUserID
            )
            selectedItem = nil
        }
    }
}
