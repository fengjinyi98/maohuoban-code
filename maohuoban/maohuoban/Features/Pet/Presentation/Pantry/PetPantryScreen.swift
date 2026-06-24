import SwiftUI
import MaohuobanDesignSystem

// PetPantryRoute 储物柜路由
// 核心职责：
// - 定义储物柜内部导航目标
enum PetPantryRoute: Hashable {
    case addItem
}

// PetPantryScreen 宠物储物柜页面
// 核心职责：
// - 展示宠物食品物资的画廊式双列网格
// - 支持分类筛选
// - 提供搜索和添加入口
struct PetPantryScreen<Route: Hashable>: View {
    let petID: String
    let petName: String
    let onNavigate: (PetPantryRoute) -> Route

    @State private var selectedCategory: PantryCategory = .all
    @State private var items: [PantryItem] = PetPantryMockData.items

    var filteredItems: [PantryItem] {
        if selectedCategory == .all {
            return items
        }
        return items.filter { $0.category == selectedCategory }
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(spacing: 0) {
                        filterBar
                            .padding(.horizontal, MHBTheme.Spacing.s6)
                            .padding(.top, MHBTheme.Spacing.s2)
                            .padding(.bottom, MHBTheme.Spacing.s4)

                        galleryGrid
                            .padding(.horizontal, MHBTheme.Spacing.s5)
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s6) {
                ForEach(PantryCategory.allCases, id: \.self) { category in
                    FilterButton(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
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
                PantryItemCard(item: item)
            }
        }
    }
}

// FilterButton 分类筛选按钮
// 核心职责：
// - 展示分类选项
// - 提供选中态视觉反馈
private struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s1) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? MHBTheme.ColorToken.labelPrimary.color
                            : MHBTheme.ColorToken.labelSecondary.color
                    )
                    .padding(.bottom, MHBTheme.Spacing.s2)

                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(MHBTheme.ColorToken.labelPrimary.color)
                        .frame(width: 12, height: 3)
                }
            }
        }
    }
}

// PantryItemCard 储物柜物品卡片
// 核心职责：
// - 展示单个物品的封面、名称、品牌和状态
// - 复刻设计稿的画廊级视觉效果
private struct PantryItemCard: View {
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

                Button {
                    // TODO: 更多操作
                } label: {
                    Text("•••")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(hex: "D8D8D8"))
                }
                .buttonStyle(.plain)
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
            statusLabel: "# 消耗中"
        ),
        .init(
            id: "2",
            name: "鲜肉双拼主食罐",
            brand: "K9 Feline Natural",
            imageURL: "https://picsum.photos/400/500?random=12",
            category: .wetFood,
            status: .sealed,
            statusDate: "2026/06/15",
            statusLabel: "# 未拆封囤货"
        ),
        .init(
            id: "3",
            name: "风干厚切牛肉片",
            brand: "Ziwi 巅峰 · 零食",
            imageURL: "https://picsum.photos/400/500?random=13",
            category: .treats,
            status: .inUse,
            statusDate: "2026/05/10",
            statusLabel: "# 消耗中"
        ),
        .init(
            id: "4",
            name: "高纯营养化毛膏",
            brand: "Red Dog 红狗",
            imageURL: "https://picsum.photos/400/500?random=14",
            category: .supplements,
            status: .periodic,
            statusDate: "2026/06/24",
            statusLabel: "# 周期喂食"
        ),
        .init(
            id: "5",
            name: "冻干鸡肉粒",
            brand: "Orijen 渴望",
            imageURL: "https://picsum.photos/400/500?random=15",
            category: .treats,
            status: .sealed,
            statusDate: "2026/06/20",
            statusLabel: "# 未拆封囤货"
        ),
        .init(
            id: "6",
            name: "三文鱼主食罐",
            brand: "K9 Feline Natural",
            imageURL: "https://picsum.photos/400/500?random=16",
            category: .wetFood,
            status: .inUse,
            statusDate: "2026/06/18",
            statusLabel: "# 消耗中"
        ),
        .init(
            id: "7",
            name: "益生菌粉",
            brand: "宠立方",
            imageURL: "https://picsum.photos/400/500?random=17",
            category: .supplements,
            status: .periodic,
            statusDate: "2026/06/10",
            statusLabel: "# 周期喂食"
        ),
        .init(
            id: "8",
            name: "鸡肉配方干粮",
            brand: "渴望 Orijen",
            imageURL: "https://picsum.photos/400/500?random=18",
            category: .mainFood,
            status: .sealed,
            statusDate: "2026/06/22",
            statusLabel: "# 未拆封囤货"
        ),
        .init(
            id: "9",
            name: "冻干鹌鹑",
            brand: "Ziwi 巅峰",
            imageURL: "https://picsum.photos/400/500?random=19",
            category: .treats,
            status: .inUse,
            statusDate: "2026/06/12",
            statusLabel: "# 消耗中"
        ),
        .init(
            id: "10",
            name: "牛肉主食罐",
            brand: "K9 Feline Natural",
            imageURL: "https://picsum.photos/400/500?random=20",
            category: .wetFood,
            status: .sealed,
            statusDate: "2026/06/19",
            statusLabel: "# 未拆封囤货"
        ),
        .init(
            id: "11",
            name: "复合维生素片",
            brand: "宠物时代",
            imageURL: "https://picsum.photos/400/500?random=21",
            category: .supplements,
            status: .periodic,
            statusDate: "2026/06/05",
            statusLabel: "# 周期喂食"
        ),
        .init(
            id: "12",
            name: "无谷三文鱼配方",
            brand: "Orijen 渴望",
            imageURL: "https://picsum.photos/400/500?random=22",
            category: .mainFood,
            status: .inUse,
            statusDate: "2026/06/16",
            statusLabel: "# 消耗中"
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
