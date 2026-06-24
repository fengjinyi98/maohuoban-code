import SwiftUI
import MaohuobanDesignSystem

// PetPantryCategoryScreen 宠物储物柜分类详情页
// 核心职责：
// - 展示特定分类下的物品列表
struct PetPantryCategoryScreen<Route: Hashable>: View {
    let petID: String
    let petName: String
    let category: PantryCategory
    let onNavigate: (PetPantryRoute) -> Route

    @State private var items: [PantryItem] = PetPantryMockData.items
    @State private var selectedItem: PantryItem?

    var filteredItems: [PantryItem] {
        items.filter { $0.category == category }
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(spacing: 0) {
                        galleryGrid
                            .padding(.horizontal, MHBTheme.Spacing.s5)
                            .padding(.top, MHBTheme.Spacing.s4)
                            .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
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
            PantryItemActionSheet(item: item)
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
    }
}
