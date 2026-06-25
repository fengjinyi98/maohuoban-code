import SwiftUI
import MaohuobanDesignSystem

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
