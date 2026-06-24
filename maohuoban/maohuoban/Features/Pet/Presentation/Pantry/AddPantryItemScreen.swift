import SwiftUI
import MaohuobanDesignSystem

// AddPantryItemScreen 添加储物柜物品页面
// 核心职责：
// - 提供新物品入库表单
// - 支持封面上传、基本信息、分类和库存管理
struct AddPantryItemScreen: View {
    @State private var draft = PantryItemDraft()
    @State private var showImagePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s5) {
                coverUploadSection

                basicInfoGroup

                categoryGroup

                stockInfoGroup
            }
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .padding(.top, MHBTheme.Spacing.s5)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("新物品入库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    saveDraft()
                }
                .foregroundStyle(
                    draft.isValid
                        ? MHBTheme.ColorToken.primary.color
                        : MHBTheme.ColorToken.labelTertiary.color
                )
                .disabled(!draft.isValid)
            }
        }
    }

    private var coverUploadSection: some View {
        Button {
            showImagePicker = true
        } label: {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(hex: "EDF1F6"), Color(hex: "D7DFEA")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: MHBTheme.Spacing.s3) {
                    Image(systemName: "camera")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color(hex: "7F8C8D"))

                    Text("点击拍摄封面")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "7F8C8D"))
                        .kerning(0.5)
                }

                HStack(spacing: MHBTheme.Spacing.s1) {
                    Image(systemName: "barcode")
                        .font(.system(size: 11, weight: .semibold))

                    Text("扫条形码识别")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(.horizontal, MHBTheme.Spacing.s2 + MHBTheme.Spacing.s1)
                .padding(.vertical, MHBTheme.Spacing.s1)
                .background(
                    Color.white.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.bottom, MHBTheme.Spacing.s3)
            }
        }
        .frame(width: 160, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
        .buttonStyle(.plain)
    }

    private var basicInfoGroup: some View {
        VStack(spacing: 0) {
            FormRowView(label: "物品名称", placeholder: "例如：原味六种鱼全期粮", text: $draft.name)
            Divider()
                .padding(.leading, 96)
            FormRowView(label: "品牌名称", placeholder: "例如：ORIJEN 渴望", text: $draft.brand)
            Divider()
                .padding(.leading, 96)
            FormRowView(label: "单品规格", placeholder: "例如：5.4kg 或 170g", text: $draft.specification)
        }
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }

    private var categoryGroup: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                Text("资产分类")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                FlowLayout(spacing: MHBTheme.Spacing.s2) {
                    ForEach([PantryCategory.mainFood, .wetFood, .treats, .supplements], id: \.self) { category in
                        Button {
                            draft.category = category
                        } label: {
                            Text(category.displayName)
                                .font(.system(size: 12, weight: draft.category == category ? .semibold : .medium))
                                .foregroundStyle(
                                    draft.category == category
                                        ? Color(hex: "6B9A7A")
                                        : MHBTheme.ColorToken.labelSecondary.color
                                )
                                .padding(.horizontal, MHBTheme.Spacing.s3)
                                .padding(.vertical, MHBTheme.Spacing.s1 + MHBTheme.Spacing.s1 / 2)
                                .background(
                                    draft.category == category
                                        ? Color(hex: "F0F5F2")
                                        : Color(hex: "F5F5F5"),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(MHBTheme.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                Text("初始状态")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                FlowLayout(spacing: MHBTheme.Spacing.s2) {
                    ForEach(PantryItemInitialStatus.allCases, id: \.self) { status in
                        Button {
                            draft.initialStatus = status
                        } label: {
                            Text(status.displayName)
                                .font(.system(size: 12, weight: draft.initialStatus == status ? .semibold : .medium))
                                .foregroundStyle(
                                    draft.initialStatus == status
                                        ? MHBTheme.ColorToken.primary.color
                                        : MHBTheme.ColorToken.labelSecondary.color
                                )
                                .padding(.horizontal, MHBTheme.Spacing.s3)
                                .padding(.vertical, MHBTheme.Spacing.s1 + MHBTheme.Spacing.s1 / 2)
                                .background(
                                    draft.initialStatus == status
                                        ? Color(hex: "E6F4FA")
                                        : Color(hex: "F5F5F5"),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(MHBTheme.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }

    private var stockInfoGroup: some View {
        VStack(spacing: 0) {
            FormRowView(label: "初始库存", placeholder: "例如：1 袋 或 6 罐", text: $draft.initialStock)
            Divider()
                .padding(.leading, 96)
            FormRowView(label: "保质期限", placeholder: "例如：18 个月 或 填到期日", text: $draft.expiryInfo)
        }
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }

    private func saveDraft() {
        guard draft.isValid else { return }
        // TODO: 保存物品到储物柜
        dismiss()
    }
}

// FormRowView 表单行视图
// 核心职责：
// - 提供统一的标签+输入框行布局
private struct FormRowView: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 80, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// FlowLayout 流式布局
// 核心职责：
// - 支持标签自动换行布局
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        let width = proposal.replacingUnspecifiedDimensions().width
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let itemSize = subviews[item.index].sizeThatFits(.unspecified)
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(itemSize)
                )
                x += itemSize.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        let maxWidth = proposal.replacingUnspecifiedDimensions().width

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && !currentRow.items.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }

            currentRow.items.append(Item(index: index, size: size))
            currentRow.height = max(currentRow.height, size.height)
            x += size.width + spacing
        }

        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private struct Row {
        var items: [Item] = []
        var height: CGFloat = 0
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }
}
