import SwiftUI
import MaohuobanDesignSystem

// AddPantryItemScreen 添加储物柜物品页面
// 核心职责：
// - 提供新物品入库表单
// - 支持封面上传、基本信息、分类和库存管理
struct AddPantryItemScreen: View {
    @State private var draft = PantryItemDraft()
    @State private var expiryDate = Date()
    @State private var showImagePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: 0) {
                smartScanCard
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                dividerRow
                    .padding(.horizontal, 24)
                
                coverUploadSection
                
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
        .navigationTitle("新资产入库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    saveDraft()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    draft.isValid
                        ? Color(hex: "0093DD")
                        : MHBTheme.ColorToken.labelTertiary.color
                )
                .disabled(!draft.isValid)
            }
        }
    }

    private var smartScanCard: some View {
        Button {
            // TODO: 扫码录入
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "E6F4FA"))
                        .frame(width: 44, height: 44)
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "0093DD"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("扫描条形码智能录入")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "2A2A2A"))
                        .kerning(0.5)
                    Text("自动解析品牌、品名与保质期")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "888888"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "CCCCCC"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 1)
            Text("或者手动建立档案")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "CCCCCC"))
                .kerning(1)
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 1)
        }
        .padding(.vertical, 28)
    }

    private var coverUploadSection: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "camera")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color(hex: "7F8C8D"))
                
                Text("添加画廊封面")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "7F8C8D"))
                    .kerning(0.5)
            }
            .frame(width: 140, height: 175)
            .background(
                LinearGradient(
                    colors: [Color(hex: "EDF1F6"), Color(hex: "D7DFEA")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 24, x: 0, y: 8)
            .padding(.bottom, 32)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var basicInfoGroup: some View {
        VStack(spacing: 0) {
            FormRowView(label: "物品名称", placeholder: "例如：原味六种鱼全期粮", text: $draft.name)
            Divider()
            FormRowView(label: "品牌名称", placeholder: "例如：ORIJEN 渴望", text: $draft.brand)
            Divider()
            FormRowView(label: "单品规格", placeholder: "例如：5.4kg 或 170g", text: $draft.specification)
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
                FlowLayout(spacing: 8) {
                    ForEach(PantryCategory.allCases.filter { $0 != .all }, id: \.self) { category in
                        InteractiveTag(
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
            
            tagSelectorRow(title: "初始状态") {
                FlowLayout(spacing: 8) {
                    ForEach(PantryItemInitialStatus.allCases, id: \.self) { status in
                        InteractiveTag(
                            title: status.displayName,
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
            FormRowView(label: "初始库存", placeholder: "输入入库数量 (如: 1)", text: $draft.initialStock)
            Divider()
            HStack(alignment: .center, spacing: 0) {
                Text("保质期限")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "888888"))
                    .frame(width: 80, alignment: .leading)

                DatePicker("", selection: $expiryDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: expiryDate) { oldValue, newValue in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        draft.expiryInfo = formatter.string(from: newValue)
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

    private func saveDraft() {
        guard draft.isValid else { return }
        // TODO: 保存物品到储物柜
        dismiss()
    }
}

private struct FormRowView: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "888888"))
                .frame(width: 80, alignment: .leading)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color(hex: "CCCCCC")))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "2A2A2A"))
        }
        .padding(.vertical, 16)
    }
}

private enum TagStyle {
    case green, blue
}

private struct InteractiveTag: View {
    let title: String
    let isActive: Bool
    let style: TagStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var textColor: Color {
        if !isActive { return Color(hex: "888888") }
        switch style {
        case .green: return Color(hex: "6B9A7A")
        case .blue: return Color(hex: "0093DD")
        }
    }
    
    private var bgColor: Color {
        if !isActive { return Color(hex: "F5F5F5") }
        switch style {
        case .green: return Color(hex: "F0F5F2")
        case .blue: return Color(hex: "E6F4FA")
        }
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
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
