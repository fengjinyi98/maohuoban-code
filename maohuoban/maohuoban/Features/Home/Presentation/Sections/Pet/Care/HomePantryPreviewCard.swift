import SwiftUI

// HomePantryPreviewCard 单个储物柜物品预览卡片
// 核心职责：
// - 渲染首页储物柜预览封面与标题
// - 展示当前宠物饮食角色标注
struct HomePantryPreviewCard: View {
    let item: HomeDashboardSnapshot.PantryPreviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let coverURL = item.coverURL,
                   let mediaURL = PantryMediaURLResolver.resolve(coverURL) {
                    AsyncImage(url: mediaURL) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.white.opacity(0.1))
                    }
                } else {
                    Rectangle().fill(Color.white.opacity(0.1))
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .overlay(alignment: .topTrailing) {
                if let dietRoleLabel = item.dietRoleLabel, !dietRoleLabel.isEmpty {
                    Text(dietRoleLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .padding(6)
                }
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
            }
        }
        .frame(width: 140)
    }
}
