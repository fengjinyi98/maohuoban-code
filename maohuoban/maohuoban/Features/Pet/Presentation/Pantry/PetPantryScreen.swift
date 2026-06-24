import SwiftUI
import MaohuobanDesignSystem

// PetPantryRoute 储物柜路由
// 核心职责：
// - 定义储物柜内部导航目标
enum PetPantryRoute: Hashable {
    case addItem
    case categoryDetail(PantryCategory)
}

// PetPantryScreen 宠物储物柜页面
// 核心职责：
// - 展示宠物食品物资的分类卡片
// - 提供搜索和添加入口
struct PetPantryLockerCustomization: Equatable {
    var title: String?
    var coverImageURL: String?
    var isPinned: Bool = false
}

struct PetPantryScreen<Route: Hashable>: View {
    let petID: String
    let petName: String
    let onNavigate: (PetPantryRoute) -> Route

    @State private var items: [PantryItem] = PetPantryMockData.items
    @State private var customizations: [PantryCategory: PetPantryLockerCustomization] = [:]
    
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

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(spacing: 0) {
                        categoriesGrid
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
        .navigationTitle("\(petName)的储物柜")
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
                let hasTitle = customization?.title != nil

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
                .contextMenu {
                    Button {
                        // TODO: 实际应弹出编辑页面，此处为 Mock 演示交互
                        if hasTitle {
                            customizations[group.category]?.title = nil
                        } else {
                            var cust = customizations[group.category] ?? PetPantryLockerCustomization()
                            cust.title = "自定: " + group.category.displayName
                            customizations[group.category] = cust
                        }
                    } label: {
                        Label(hasTitle ? "编辑标题和封面" : "添加标题和封面", systemImage: "pencil")
                    }
                    
                    Button {
                        var cust = customizations[group.category] ?? PetPantryLockerCustomization()
                        cust.isPinned.toggle()
                        customizations[group.category] = cust
                    } label: {
                        Label(isPinned ? "取消固定" : "固定", systemImage: isPinned ? "pin.slash" : "pin")
                    }
                    
                    Button(role: .destructive) {
                        // TODO: 删除储物柜逻辑
                    } label: {
                        Label("删除储物柜", systemImage: "trash")
                    }
                }
            }
        }
    }
}

// PantryCategoryCard 储物柜分类卡片
// 核心职责：
// - 展示分类封面、名称和物品数量
// - 复刻相册叠放视觉效果
struct PantryCategoryCard: View {
    let category: PantryCategory
    let count: Int
    let coverImageURL: String?
    let customTitle: String?
    let isPinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            PantryCategoryCover(imageURL: coverImageURL, isPinned: isPinned)

            VStack(alignment: .leading, spacing: 2) {
                if let customTitle = customTitle {
                    Text(customTitle)
                        .font(MHBTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                    
                    Text("\(category.displayName) · \(count) 件物品")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                } else {
                    Text(category.displayName)
                        .font(MHBTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(count) 件物品")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// PantryCategoryCover 分类叠放封面
// 核心职责：
// - 绘制相册纸张叠放效果
// - 展示分类首图
private struct PantryCategoryCover: View {
    let imageURL: String?
    let isPinned: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .top) {
                // 底部第三层纸张
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .offset(y: -MHBTheme.Spacing.s3)

                // 底部第二层纸张
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color)
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .offset(y: -MHBTheme.Spacing.s3 / 2)

                // 主封面图片
                Group {
                    if let imageURL = imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                placeholderIcon
                            @unknown default:
                                placeholderIcon
                            }
                        }
                    } else {
                        placeholderIcon
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MHBTheme.ColorToken.labelQuaternary.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                        .strokeBorder(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                        .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
            }
            
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: MHBTheme.Spacing.s6, height: MHBTheme.Spacing.s6)
                    .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.42), in: Circle())
                    .padding(MHBTheme.Spacing.s3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, MHBTheme.Spacing.s3)
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.06), radius: 10, y: 6)
    }

    private var placeholderIcon: some View {
        Image(systemName: "archivebox")
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// PantryItemCard 储物柜物品卡片
// 核心职责：
// - 展示单个物品的封面、名称、品牌和状态
// - 复刻设计稿的画廊级视觉效果
struct PantryItemCard: View {
    let item: PantryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverArea

            infoArea
        }
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private var coverArea: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    coverGradient

                    if let imageURL = item.imageURL {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .failure, .empty:
                                placeholderIcon
                            @unknown default:
                                placeholderIcon
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(MHBTheme.Spacing.s4)
                    } else {
                        placeholderIcon
                    }
                }

                Text(item.statusLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        item.status.isGrayTag
                            ? Color(hex: "888888")
                            : Color(hex: "6B9A7A")
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s2)
                    .padding(.vertical, MHBTheme.Spacing.s1)
                    .background(
                        item.status.isGrayTag
                            ? Color(hex: "F5F5F5")
                            : Color(hex: "F0F5F2")
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(MHBTheme.Spacing.s2)
            }
            
            // 数量角标
            if item.quantity > 1 {
                Text("x\(item.quantity)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
        .aspectRatio(4/5, contentMode: .fill)
        .frame(maxWidth: .infinity)
    }

    private var coverGradient: some View {
        LinearGradient(
            colors: coverColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var coverColors: [Color] {
        let hash = abs(item.id.hashValue)
        let index = hash % 4

        switch index {
        case 0: return [Color(hex: "E8F0ED"), Color(hex: "D1E0D7")]
        case 1: return [Color(hex: "EDF1F6"), Color(hex: "D7DFEA")]
        case 2: return [Color(hex: "1C2331"), Color(hex: "0F141E")]
        default: return [Color(hex: "F5F1EB"), Color(hex: "E6DFD3")]
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(2)

            Text(item.brand)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)

            Spacer(minLength: MHBTheme.Spacing.s1)

            HStack(alignment: .center) {
                Text("\(item.statusDate) · \(statusAction(for: item.status))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                Spacer()
            }
        }
        .padding(MHBTheme.Spacing.s4)
    }

    private func statusAction(for status: PantryStatus) -> String {
        switch status {
        case .inUse: "启封"
        case .sealed: "入库"
        case .periodic: "入库"
        }
    }
}

// PetPantryMockData 储物柜 Mock 数据
// 核心职责：
// - 提供测试和演示用的物品数据
enum PetPantryMockData {
    static let items: [PantryItem] = [
        .init(
            id: "1",
            name: "原味六种鱼",
            brand: "Orijen 渴望",
            imageURL: "https://picsum.photos/400/500?random=11",
            category: .mainFood,
            status: .inUse,
            statusDate: "2026/06/21",
            statusLabel: "# 消耗中",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "2",
            name: "鲜肉双拼主食罐",
            brand: "K9 Feline Natural",
            imageURL: "https://picsum.photos/400/500?random=12",
            category: .wetFood,
            status: .sealed,
            statusDate: "2026/06/15",
            statusLabel: "# 未拆封囤货",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "3",
            name: "风干厚切牛肉片",
            brand: "Ziwi 巅峰 · 零食",
            imageURL: "https://picsum.photos/400/500?random=13",
            category: .treats,
            status: .inUse,
            statusDate: "2026/05/10",
            statusLabel: "# 消耗中",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "4",
            name: "高纯营养化毛膏",
            brand: "Red Dog 红狗",
            imageURL: "https://picsum.photos/400/500?random=14",
            category: .supplements,
            status: .periodic,
            statusDate: "2026/06/24",
            statusLabel: "# 周期喂食",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "5",
            name: "冻干鸡肉粒",
            brand: "Orijen 渴望",
            imageURL: "https://picsum.photos/400/500?random=15",
            category: .treats,
            status: .sealed,
            statusDate: "2026/06/20",
            statusLabel: "# 未拆封囤货",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "6",
            name: "三文鱼主食罐",
            brand: "K9 Feline Natural",
            imageURL: "https://picsum.photos/400/500?random=16",
            category: .wetFood,
            status: .inUse,
            statusDate: "2026/06/18",
            statusLabel: "# 消耗中",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "7",
            name: "益生菌粉",
            brand: "宠立方",
            imageURL: "https://picsum.photos/400/500?random=17",
            category: .supplements,
            status: .periodic,
            statusDate: "2026/06/10",
            statusLabel: "# 周期喂食",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "8",
            name: "鸡肉配方干粮",
            brand: "渴望 Orijen",
            imageURL: "https://picsum.photos/400/500?random=18",
            category: .mainFood,
            status: .sealed,
            statusDate: "2026/06/22",
            statusLabel: "# 未拆封囤货",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "9",
            name: "冻干鹌鹑",
            brand: "Ziwi 巅峰",
            imageURL: "https://picsum.photos/400/500?random=19",
            category: .treats,
            status: .inUse,
            statusDate: "2026/06/12",
            statusLabel: "# 消耗中",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "10",
            name: "牛肉主食罐",
            brand: "K9 Feline Natural",
            imageURL: "https://picsum.photos/400/500?random=20",
            category: .wetFood,
            status: .sealed,
            statusDate: "2026/06/19",
            statusLabel: "# 未拆封囤货",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "11",
            name: "复合维生素片",
            brand: "宠物时代",
            imageURL: "https://picsum.photos/400/500?random=21",
            category: .supplements,
            status: .periodic,
            statusDate: "2026/06/05",
            statusLabel: "# 周期喂食",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        ),
        .init(
            id: "12",
            name: "无谷三文鱼配方",
            brand: "Orijen 渴望",
            imageURL: "https://picsum.photos/400/500?random=22",
            category: .mainFood,
            status: .inUse,
            statusDate: "2026/06/16",
            statusLabel: "# 消耗中",
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            expiryDate: "2027/05"
        )
    ]
}

// Color Hex 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
