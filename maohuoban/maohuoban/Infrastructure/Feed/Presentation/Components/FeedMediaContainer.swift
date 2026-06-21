import SwiftUI
import MaohuobanDesignSystem

// FeedMediaContainer Feed 媒体展示容器
// 核心职责：
// - 统一 Feed 大图比例、圆角、背景和内描边
// - 支持业务卡片在图片内部叠加角标
struct FeedMediaContainer<Overlay: View>: View {
    let assetName: String
    @ViewBuilder let overlay: () -> Overlay

    init(
        assetName: String,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.assetName = assetName
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                overlay()
                    .padding(MHBTheme.Spacing.s4)
            }
        }
        .aspectRatio(FeedCardMetrics.mediaAspectRatio, contentMode: .fit)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(FeedCardMetrics.mediaShape)
        .overlay {
            FeedCardMetrics.mediaShape
                .strokeBorder(
                    MHBTheme.ColorToken.labelPrimary.color.opacity(FeedCardMetrics.mediaInnerBorderOpacity),
                    lineWidth: FeedCardMetrics.mediaInnerBorderWidth
                )
        }
    }
}

extension FeedMediaContainer where Overlay == EmptyView {
    init(assetName: String) {
        self.init(assetName: assetName) {
            EmptyView()
        }
    }
}
