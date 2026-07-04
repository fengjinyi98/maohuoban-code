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
                    onOpenRoute(onNavigate(.itemDetail(itemID: item.id)))
                } label: {
                    PantryItemCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
