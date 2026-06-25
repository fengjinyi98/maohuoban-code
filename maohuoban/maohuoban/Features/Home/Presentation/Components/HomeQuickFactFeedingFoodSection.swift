import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingFoodSection 喂食品类选择区
// 核心职责：
// - 以互斥展开方式组织喂食分类
// - 展示当前分类下的储物柜物品并支持切换
struct HomeQuickFactFeedingFoodSection: View {
    @Binding var selectedKind: HomeQuickFactFeedingFoodKind
    @Binding var expandedKind: HomeQuickFactFeedingFoodKind?
    @Binding var selectedItemIDs: [HomeQuickFactFeedingFoodKind: String?]
    let foodOptions: [HomeQuickFactFeedingFoodOption]

    var body: some View {
        HomeQuickFactSheetSection(title: "喂了什么") {
            VStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(HomeQuickFactFeedingFoodKind.allCases) { kind in
                    VStack(spacing: MHBTheme.Spacing.s2) {
                        HomeQuickFactFeedingCategoryRow(
                            kind: kind,
                            selectedItemName: selectedItemName(for: kind),
                            isExpanded: expandedKind == kind,
                            action: {
                                expand(kind)
                            }
                        )

                        if expandedKind == kind {
                            HomeQuickFactFeedingPantryList(
                                kind: kind,
                                selectedItemID: selectedItemID(for: kind),
                                foodOptions: foodOptions,
                                onSelectItem: { item in
                                    setSelectedItemID(item.id, for: kind)
                                }
                            )
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            )
                            .clipped()
                        }
                    }
                    .animation(.snappy(duration: 0.24), value: expandedKind)
                    .animation(.snappy(duration: 0.18), value: selectedItemID(for: kind))
                }
            }
        }
    }

    private func expand(_ kind: HomeQuickFactFeedingFoodKind) {
        let previousExpanded = expandedKind
        let nextExpanded = expandedKind == kind ? nil : kind
        selectedKind = kind
        if selectedItemID(for: kind) == nil,
           !HomeQuickFactFeedingFoodSource.hasSelectionEntry(
            for: kind,
            selectedItemIDs: selectedItemIDs
           ) {
            setSelectedItemID(HomeQuickFactFeedingFoodSource.defaultItemID(for: kind, in: foodOptions), for: kind)
        }

        if let previousExpanded, previousExpanded != kind {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                expandedKind = nil
            }
            DispatchQueue.main.async {
                withAnimation(.snappy(duration: 0.24)) {
                    expandedKind = kind
                }
            }
            return
        }

        withAnimation(.snappy(duration: 0.24)) {
            expandedKind = nextExpanded
        }
    }

    private func selectedItemName(for kind: HomeQuickFactFeedingFoodKind) -> String {
        HomeQuickFactFeedingFoodSource.itemName(
            for: selectedItemID(for: kind),
            in: kind,
            options: foodOptions
        )
            ?? HomeQuickFactFeedingFoodSource.defaultItemName(for: kind, in: foodOptions)
            ?? kind.emptySelectionTitle
    }

    private func selectedItemID(for kind: HomeQuickFactFeedingFoodKind) -> String? {
        HomeQuickFactFeedingFoodSource.selectedItemID(
            for: kind,
            selectedItemIDs: selectedItemIDs,
            options: foodOptions
        )
    }

    private func setSelectedItemID(_ itemID: String?, for kind: HomeQuickFactFeedingFoodKind) {
        selectedKind = kind
        selectedItemIDs[kind] = itemID
    }
}
