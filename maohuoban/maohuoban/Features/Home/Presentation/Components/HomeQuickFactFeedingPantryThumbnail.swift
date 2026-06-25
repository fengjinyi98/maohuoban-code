import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingPantryThumbnail 喂食储物柜缩略图
// 核心职责：
// - 展示储物柜物品图片
// - 在图片不可用时提供分类图标兜底
struct HomeQuickFactFeedingPantryThumbnail: View {
    let item: HomeQuickFactFeedingFoodOption

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.primaryBackgroundSoft.color

            if let imageURL = item.imageURL.flatMap(URL.init(string:)) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }

    private var fallbackIcon: some View {
        Image(systemName: item.systemImage)
            .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
    }
}
