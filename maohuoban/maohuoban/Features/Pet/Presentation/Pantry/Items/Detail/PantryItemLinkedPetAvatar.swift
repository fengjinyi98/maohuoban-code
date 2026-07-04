import SwiftUI
import MaohuobanDesignSystem

// PantryItemLinkedPetAvatar 关联宠物头像
// 核心职责：
// - 展示关联宠物头像或占位符
struct PantryItemLinkedPetAvatar: View {
    let imageURLString: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
            if let imageURLString,
               let url = PantryMediaURLResolver.resolve(imageURLString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                }
                .clipShape(Circle())
            } else {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
        }
        .frame(width: 40, height: 40)
    }
}
