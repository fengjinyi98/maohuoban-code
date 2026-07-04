import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailScreen 储物柜物品详情页
// 核心职责：
// - 加载并展示单个物品的后端详情读模型
// - 承载右上角更多菜单操作入口
struct PantryItemDetailScreen<Route: Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let itemID: String
    let context: PetPantryEntryContext
    let currentUserID: String?
    let onNavigate: (PetPantryRoute) -> Route
    var onOpenRoute: (Route) -> Void = { _ in }

    @State private var store = PetFoodInventoryItemDetailStore()
    @State private var isDeleteConfirmationPresented = false
    @State private var isRestockSheetPresented = false
    @State private var restockAmount = 1

    var body: some View {
        MHBScreenScrollView {
            PantryItemDetailPhaseView(
                phase: store.phase,
                onOpenFeedingRecord: { entry in
                    let recordContext = PetRecordEntryContext(
                        petID: entry.petID,
                        petName: entry.petName
                    )
                    onOpenRoute(onNavigate(.feedingRecordDetail(
                        recordID: entry.eventID,
                        context: recordContext
                    )))
                }
            )
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.top, MHBTheme.Spacing.s5)
                .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("物品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .loaded(let detail) = store.phase {
                    PantryItemDetailMoreMenu(
                        item: PantryItem(foodInventoryItem: detail.item),
                        allowsDietAssignment: context.sourcePetID != nil,
                        isDisabled: store.isMutating,
                        onMarkSealed: {
                            Task {
                                await store.markItemStatus(
                                    itemID: detail.item.id,
                                    status: .sealed,
                                    currentUserID: currentUserID
                                )
                            }
                        },
                        onRestock: {
                            isRestockSheetPresented = true
                        },
                        onEdit: {
                            onOpenRoute(onNavigate(.editItem(PantryItem(foodInventoryItem: detail.item))))
                        },
                        onDelete: {
                            isDeleteConfirmationPresented = true
                        },
                        onSetCurrentStaple: {
                            setCurrentStaple(itemID: detail.item.id)
                        },
                        onSetTrying: {
                            setFoodAssignment(itemID: detail.item.id, role: .trying)
                        },
                        onSetUsualTreat: {
                            setFoodAssignment(itemID: detail.item.id, role: .usualTreat)
                        },
                        onSetUsualNutrition: {
                            setFoodAssignment(itemID: detail.item.id, role: .usualNutrition)
                        },
                        onSetNotSuitable: {
                            setFoodAssignment(itemID: detail.item.id, role: .notSuitable)
                        }
                    )
                }
            }
        }
        .alert("移出储物柜", isPresented: $isDeleteConfirmationPresented) {
            Button("移出", role: .destructive) {
                Task {
                    if await store.deleteItem(itemID: itemID, currentUserID: currentUserID) {
                        dismiss()
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要将此物品移出储物柜吗？此操作无法撤销。")
        }
        .sheet(isPresented: $isRestockSheetPresented) {
            PantryItemRestockSheet(
                restockAmount: $restockAmount,
                isSubmitting: store.isMutating,
                onSubmit: {
                    Task {
                        await store.restockItem(
                            itemID: itemID,
                            quantity: restockAmount,
                            currentUserID: currentUserID
                        )
                        isRestockSheetPresented = false
                    }
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .task(id: itemID) {
            await store.load(itemID: itemID, currentUserID: currentUserID)
        }
    }

    private func setCurrentStaple(itemID: String) {
        guard let sourcePetID = context.sourcePetID else { return }
        Task {
            await store.setCurrentStaple(
                petID: sourcePetID,
                foodItemID: itemID,
                currentUserID: currentUserID
            )
        }
    }

    private func setFoodAssignment(itemID: String, role: PetDietAssignmentRole) {
        guard let sourcePetID = context.sourcePetID else { return }
        Task {
            await store.setFoodAssignment(
                petID: sourcePetID,
                foodItemID: itemID,
                role: role,
                currentUserID: currentUserID
            )
        }
    }
}
