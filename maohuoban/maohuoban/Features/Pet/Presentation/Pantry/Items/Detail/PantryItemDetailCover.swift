import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailCover 物品详情封面
// 核心职责：
// - 展示物品封面图片
// - 在无图片时展示统一占位
struct PantryItemDetailCover: View {
    let imageURLString: String?

    var body: some View {
        ZStack {
            if let imageURLString,
               let url = PantryMediaURLResolver.resolve(imageURLString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        PantryItemCoverPlaceholder()
                    }
                }
            } else {
                PantryItemCoverPlaceholder()
            }
        }
        .frame(width: 92, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
