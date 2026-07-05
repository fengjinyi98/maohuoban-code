import SwiftUI
import UIKit
import MaohuobanDesignSystem

// AddPantryItemScreen 储物柜物品表单页面
// 核心职责：
// - 根据入口模式承载添加物品和编辑物品信息
// - 选择照片后立即上传媒资并把 coverAssetID 写入草稿
// - 保存时按模式提交创建或编辑命令
struct AddPantryItemScreen: View {
    let mode: PantryItemFormMode
    let currentUserID: String?
    let onSaved: () -> Void

    @State private var draft: FoodInventoryDraft
    @State private var store = PetFoodInventoryStore()
    @State private var expiryDate: Date
    @State private var showImagePicker = false
    @State private var selectedCoverImage: UIImage?
    @State private var uploadedCoverURL: String?
    @Environment(\.dismiss) private var dismiss

    init(
        mode: PantryItemFormMode = .create,
        currentUserID: String? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.currentUserID = currentUserID
        self.onSaved = onSaved
        let initialDraft = mode.initialDraft
        self._draft = State(initialValue: initialDraft)
        self._expiryDate = State(initialValue: Self.parseDate(initialDraft.expiryDate) ?? Date())
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: 0) {
                PantryItemCoverInput(
                    imageURL: uploadedCoverURL ?? mode.existingImageURL,
                    selectedImage: selectedCoverImage,
                    uploadProgress: store.coverUploadProgress,
                    onTap: {
                        showImagePicker = true
                    }
                )
                .padding(.top, 24)

                VStack(spacing: 24) {
                    basicInfoGroup
                    categoryGroup
                    stockInfoGroup
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "F7F8FA"))
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showImagePicker) {
            MHBMediaPickerScreen(
                title: "选择物品照片",
                request: MHBMediaPickerRequest(
                    maxSelectionCount: 1,
                    filter: .images,
                    autoConfirmSingleSelection: true,
                    showsCameraEntry: true
                ),
                onComplete: handleCoverPickerResult(_:),
                onCancel: {
                    showImagePicker = false
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(mode.saveTitle) {
                    save()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    canSave
                        ? Color(hex: "0093DD")
                        : MHBTheme.ColorToken.labelTertiary.color
                )
                .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        draft.isValid && store.coverUploadProgress == nil
    }

    private var basicInfoGroup: some View {
        VStack(spacing: 0) {
            PantryFormRow(label: "物品名称", placeholder: "例如：原味六种鱼全期粮", text: $draft.name)
            Divider()
            PantryFormRow(label: "品牌名称", placeholder: "例如：ORIJEN 渴望", text: $draft.brand)
            Divider()
            PantryFormRow(label: "单品规格", placeholder: "例如：5.4kg 或 170g", text: $draft.spec)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 4)
    }

    private var categoryGroup: some View {
        VStack(spacing: 0) {
            tagSelectorRow(title: "资产分类") {
                MHBFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(FoodInventoryCategory.allCases, id: \.rawValue) { category in
                        PantryInteractiveTag(
                            title: category.displayName,
                            isActive: draft.category == category,
                            style: .green
                        ) {
                            draft.category = category
                        }
                    }
                }
            }

            Divider()

            tagSelectorRow(title: "库存状态") {
                MHBFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(FoodInventoryStatus.editableCases, id: \.rawValue) { status in
                        PantryInteractiveTag(
                            title: status.displayLabel,
                            isActive: draft.initialStatus == status,
                            style: .blue
                        ) {
                            draft.initialStatus = status
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 4)
    }

    private var stockInfoGroup: some View {
        VStack(spacing: 0) {
            PantryFormRow(label: "库存数量", placeholder: "输入入库数量 (如: 1)", text: quantityText)
            Divider()
            HStack(alignment: .center, spacing: 0) {
                Text("保质期限")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "888888"))
                    .frame(width: 80, alignment: .leading)

                DatePicker("", selection: $expiryDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: expiryDate) { _, newValue in
                        draft.expiryDate = Self.formatDate(newValue)
                    }

                Spacer()
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 4)
    }

    private var quantityText: Binding<String> {
        Binding(
            get: { "\(draft.quantity)" },
            set: { value in
                draft.quantity = Int(value.filter(\.isNumber)) ?? 0
            }
        )
    }

    private func tagSelectorRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "888888"))
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
        .padding(.vertical, 12)
    }

    private func handleCoverPickerResult(_ result: MHBMediaPickerResult) {
        showImagePicker = false
        guard let image = result.images.first,
              let currentUserID,
              let uploadDraft = PantryCoverUploadDraftFactory.makeDraft(from: image)
        else {
            return
        }

        Task {
            let result = await store.uploadCover(draft: uploadDraft, currentUserID: currentUserID)
            guard let result else { return }
            draft.coverAssetID = result.asset.id
            uploadedCoverURL = result.asset.url
            selectedCoverImage = image
        }
    }

    private func save() {
        guard canSave, let currentUserID else { return }
        Task {
            let savedItem: FoodInventoryItem?
            switch mode {
            case .create:
                savedItem = await store.createItem(draft: draft, currentUserID: currentUserID)
            case .edit(let item):
                savedItem = await store.updateItem(itemID: item.id, draft: draft, currentUserID: currentUserID)
            }
            guard savedItem != nil else { return }
            onSaved()
            dismiss()
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return dateFormatter.date(from: value)
    }

    private static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
