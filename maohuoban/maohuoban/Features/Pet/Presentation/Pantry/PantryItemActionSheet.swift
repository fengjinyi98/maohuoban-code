import SwiftUI
import MaohuobanDesignSystem

// PantryItemActionSheet 物品操作面板
// 核心职责：
// - 展示选定物品的详情摘要
// - 提供状态流转、编辑和删除等操作入口
struct PantryItemActionSheet: View {
    let item: PantryItem
    let onMarkSealed: (String) -> Void
    let onEdit: (PantryItem) -> Void
    let onArchive: (String) -> Void
    let onRestock: (String, Int) -> Void
    let onSetCurrentStaple: (String) -> Void
    let onSetTrying: (String) -> Void
    let onSetUsualTreat: (String) -> Void
    let onSetUsualNutrition: (String) -> Void
    let onSetNotSuitable: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isRestocking = false
    @State private var restockAmount = 1

    init(
        item: PantryItem,
        onMarkSealed: @escaping (String) -> Void = { _ in },
        onEdit: @escaping (PantryItem) -> Void = { _ in },
        onArchive: @escaping (String) -> Void = { _ in },
        onRestock: @escaping (String, Int) -> Void = { _, _ in },
        onSetCurrentStaple: @escaping (String) -> Void = { _ in },
        onSetTrying: @escaping (String) -> Void = { _ in },
        onSetUsualTreat: @escaping (String) -> Void = { _ in },
        onSetUsualNutrition: @escaping (String) -> Void = { _ in },
        onSetNotSuitable: @escaping (String) -> Void = { _ in }
    ) {
        self.item = item
        self.onMarkSealed = onMarkSealed
        self.onEdit = onEdit
        self.onArchive = onArchive
        self.onRestock = onRestock
        self.onSetCurrentStaple = onSetCurrentStaple
        self.onSetTrying = onSetTrying
        self.onSetUsualTreat = onSetUsualTreat
        self.onSetUsualNutrition = onSetUsualNutrition
        self.onSetNotSuitable = onSetNotSuitable
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            actionList
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            Spacer()
        }
        .background(Color.white)
        .alert("移出储物柜", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("移出", role: .destructive) {
                onArchive(item.id)
                dismiss()
            }
        } message: {
            Text("确定要将此物品移出储物柜吗？此操作无法撤销。")
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "E8F0ED"), Color(hex: "D1E0D7")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 42, height: 42)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(width: 60, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "2A2A2A"))
                
                Text("\(item.brand) · \(item.spec ?? "默认规格")")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "999999"))
                
                HStack(spacing: 8) {
                    Text("剩余 \(item.quantity) \(item.unit ?? "件")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "2A2A2A"))
                    
                    if let expiryDate = item.expiryDate {
                        Text("保质期至 \(expiryDate)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: "999999"))
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionList: some View {
        VStack(spacing: 0) {
            actionButton(
                icon: "shippingbox",
                title: "标记为全新未拆封"
            ) {
                onMarkSealed(item.id)
                dismiss()
            }

            dietAssignmentActions
            
            actionButton(
                icon: "plus.circle",
                title: "补充库存 (复购)",
                showArrow: !isRestocking,
                hideDivider: isRestocking
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isRestocking.toggle()
                }
            }
            
            if isRestocking {
                restockStepperView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            actionButton(
                icon: "pencil",
                title: "编辑物品档案",
                showArrow: true
            ) {
                onEdit(item)
                dismiss()
            }
            
            actionButton(
                icon: "trash",
                title: "移出储物柜",
                isDestructive: true
            ) {
                showDeleteConfirmation = true
            }
        }
    }

    private var dietAssignmentActions: some View {
        Group {
            switch item.category {
            case .mainFood, .wetFood:
                actionButton(
                    icon: "takeoutbag.and.cup.and.straw.fill",
                    title: "设为当前主粮"
                ) {
                    onSetCurrentStaple(item.id)
                    dismiss()
                }
                actionButton(
                    icon: "sparkles",
                    title: "标记为尝试中"
                ) {
                    onSetTrying(item.id)
                    dismiss()
                }
            case .treats:
                actionButton(
                    icon: "birthday.cake.fill",
                    title: "设为常用零食"
                ) {
                    onSetUsualTreat(item.id)
                    dismiss()
                }
            case .supplements:
                actionButton(
                    icon: "pills.fill",
                    title: "设为常用营养品"
                ) {
                    onSetUsualNutrition(item.id)
                    dismiss()
                }
            case .other:
                actionButton(
                    icon: "sparkles",
                    title: "标记为尝试中"
                ) {
                    onSetTrying(item.id)
                    dismiss()
                }
            case .all, .catLitter, .medicine:
                EmptyView()
            }
            actionButton(
                icon: "xmark.octagon.fill",
                title: "设为不适合"
            ) {
                onSetNotSuitable(item.id)
                dismiss()
            }
        }
    }
    
    private var restockStepperView: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    if restockAmount > 1 {
                        restockAmount -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(restockAmount > 1 ? Color(hex: "6B9A7A") : Color(hex: "CCCCCC"))
                }
                .buttonStyle(.plain)
                
                Text("\(restockAmount)")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(minWidth: 28, alignment: .center)
                
                Button {
                    restockAmount += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "6B9A7A"))
                }
                .buttonStyle(.plain)
                
                Button("确认") {
                    onRestock(item.id, restockAmount)
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "6B9A7A"))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.03))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func actionButton(
        icon: String,
        title: String,
        showArrow: Bool = false,
        isDestructive: Bool = false,
        hideDivider: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 28)
                    .foregroundStyle(isDestructive ? Color(hex: "E74C3C") : Color(hex: "999999"))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isDestructive ? Color(hex: "E74C3C") : Color(hex: "2A2A2A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "CCCCCC"))
                }
            }
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .buttonStyle(.plain)
        .overlay(
            Group {
                if !hideDivider {
                    Rectangle()
                        .fill(Color.black.opacity(0.03))
                        .frame(height: 1)
                }
            },
            alignment: .bottom
        )
    }
}
