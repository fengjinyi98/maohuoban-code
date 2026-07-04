import SwiftUI

// HomePantryPreviewCard 单个储物柜物品预览卡片
// 核心职责：
// - 渲染首页储物柜预览封面与标题
// - 展示当前宠物饮食角色标注
struct HomePantryPreviewCard: View {
    let item: HomeDashboardSnapshot.PantryPreviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let coverURL = item.coverURL,
               let mediaURL = PantryMediaURLResolver.resolve(coverURL) {
                AsyncImage(url: mediaURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            } else {
                coverPlaceholder
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)

                Text(item.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)

                if let dietRoleLabel = item.dietRoleLabel, !dietRoleLabel.isEmpty {
                    Text(dietRoleLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                        )
                        .frame(maxWidth: 140, alignment: .leading)
                }
            }
        }
        .frame(width: 140)
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
    }
}
