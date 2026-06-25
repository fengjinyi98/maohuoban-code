import SwiftUI
import MaohuobanDesignSystem

// EditPantryItemScreen 编辑储物柜物品页面
// 核心职责：
// - 承载食品资产编辑表单
// - 通过 Store 提交真实后端更新命令
struct EditPantryItemScreen: View {
    let item: PantryItem
    let currentUserID: String?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: FoodInventoryDraft
    @State private var store = PetFoodInventoryStore()

    init(
        item: PantryItem,
        currentUserID: String?,
        onSaved: @escaping () -> Void = {}
    ) {
        self.item = item
        self.currentUserID = currentUserID
        self.onSaved = onSaved
        self._draft = State(initialValue: FoodInventoryDraft(pantryItem: item))
    }

    var body: some View {
        NavigationStack {
            MHBScreenScrollView {
                VStack(spacing: MHBTheme.Spacing.s5) {
                    editTextField(title: "名称", text: $draft.name)
                    editTextField(title: "品牌", text: $draft.brand)
                    editTextField(title: "规格", text: $draft.spec)
                    editTextField(title: "单位", text: $draft.unit)
                    editNumberField
                    categoryPicker
                    statusPicker
                    editTextField(title: "保质期", text: $draft.expiryDate)
                    editTextField(title: "备注", text: $draft.note)
                }
                .padding(MHBTheme.Spacing.s5)
            }
            .navigationTitle("编辑物品档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    private func editTextField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var editNumberField: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("库存数量")
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            Stepper(value: $draft.quantity, in: 0...999) {
                Text("\(draft.quantity)")
                    .font(MHBTheme.Typography.body.weight(.semibold))
            }
        }
    }

    private var categoryPicker: some View {
        Picker("分类", selection: $draft.category) {
            ForEach(FoodInventoryCategory.allCases, id: \.rawValue) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(.menu)
    }

    private var statusPicker: some View {
        Picker("库存状态", selection: $draft.initialStatus) {
            ForEach(FoodInventoryStatus.editableCases, id: \.rawValue) { status in
                Text(status.displayLabel).tag(status)
            }
        }
        .pickerStyle(.menu)
    }

    private func save() {
        guard let currentUserID else { return }
        Task {
            let updated = await store.updateItem(
                itemID: item.id,
                draft: draft,
                currentUserID: currentUserID
            )
            guard updated != nil else { return }
            onSaved()
            dismiss()
        }
    }
}
