import SwiftUI
import MaohuobanDesignSystem

// PetPantryScreen 用户储物柜页面
// 核心职责：
// - 展示用户级食品物资的分类卡片
// - 提供搜索和添加入口
// - 使用入口宠物上下文展示饮食趋势
struct PetPantryScreen<Route: Hashable>: View {
    let context: PetPantryEntryContext
    let currentUserID: String?
    let onNavigate: (PetPantryRoute) -> Route
    var onOpenRoute: (Route) -> Void = { _ in }

    @State private var store = PetFoodInventoryStore()
    @State private var customizations: [PantryCategory: PetPantryLockerCustomization] = [:]

    private var items: [PantryItem] {
        store.pantryItems
    }

    var categoryGroups: [(category: PantryCategory, count: Int, coverImageURL: String?)] {
        var groups: [(PantryCategory, Int, String?)] = []
        for category in PantryCategory.allCases where category != .all {
            let categoryItems = items.filter { $0.category == category }
            if !categoryItems.isEmpty {
                let coverImageURL = categoryItems.first { $0.imageURL != nil }?.imageURL
                groups.append((category, categoryItems.count, coverImageURL))
            }
        }
        return groups
    }

    private var shouldShowEmptyState: Bool {
        !store.isLoading && categoryGroups.isEmpty
    }

    private var shouldShowBottomCTA: Bool {
        !categoryGroups.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    if store.isLoading && categoryGroups.isEmpty {
                        ProgressView()
                            .frame(
                                maxWidth: .infinity,
                                minHeight: max(proxy.size.height - bottomInset, 360),
                                alignment: .center
                            )
                    } else if shouldShowEmptyState {
                        PetPantryEmptyState(
                            presentation: .default,
                            route: onNavigate(.addItem)
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: max(proxy.size.height - bottomInset, 360),
                            alignment: .center
                        )
                    } else {
                        VStack(spacing: MHBTheme.Spacing.s5) {
                            if let sourcePetName = context.sourcePetName,
                               context.sourcePetID != nil,
                               let dietTrendSummary = store.dietTrendSummary {
                                PetPantryDietTrendSection(
                                    petName: sourcePetName,
                                    summary: dietTrendSummary
                                )
                                .padding(.horizontal, MHBTheme.Spacing.s5)
                                .padding(.top, MHBTheme.Spacing.s4)
                            }

                            categoriesGrid
                                .padding(.horizontal, MHBTheme.Spacing.s5)
                                .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                        }
                    }
                }

                if shouldShowBottomCTA {
                    MHBBottomFloatingCTA(
                        title: "添加物品",
                        systemImage: "plus",
                        route: onNavigate(.addItem),
                        bottomInset: bottomInset
                    )
                    .zIndex(2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle("家庭储物柜")
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

    private var categoriesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
                GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
            ],
            spacing: MHBTheme.Spacing.s5
        ) {
            ForEach(categoryGroups, id: \.category) { group in
                let customization = customizations[group.category]
                let isPinned = customization?.isPinned ?? false

                NavigationLink(value: onNavigate(.categoryDetail(group.category))) {
                    PantryCategoryCard(
                        category: group.category,
                        count: group.count,
                        coverImageURL: customization?.coverImageURL ?? group.coverImageURL,
                        customTitle: customization?.title,
                        isPinned: isPinned
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
