import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailDoubleTapLikeBurst 双击点赞动画数据
// 核心职责：
// - 记录双击发生在详情页内的位置
// - 标识本次双击后的点赞目标状态
struct PetWorldFeedDetailDoubleTapLikeBurst: Identifiable, Equatable {
    let id = UUID()
    let location: CGPoint
    let isLiked: Bool
}

// PetWorldFeedDetailDoubleTapLikeOverlay 双击点赞浮层
// 核心职责：
// - 在双击位置展示点赞或取消点赞动画
// - 保持自身不参与命中测试，避免遮挡页面交互
struct PetWorldFeedDetailDoubleTapLikeOverlay: View {
    let bursts: [PetWorldFeedDetailDoubleTapLikeBurst]

    var body: some View {
        ZStack {
            ForEach(bursts) { burst in
                PetWorldFeedDetailDoubleTapLikeBurstView(isLiked: burst.isLiked)
                    .position(burst.location)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// PetWorldFeedDetailDoubleTapLikeBurstView 双击点赞单次动画
// 核心职责：
// - 使用心形图标表达点赞与取消点赞状态
// - 通过缩放、上浮和透明度变化形成轻量反馈
private struct PetWorldFeedDetailDoubleTapLikeBurstView: View {
    let isLiked: Bool

    @State private var scale: CGFloat = 0.42
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 12

    var body: some View {
        Image(systemName: isLiked ? "heart.fill" : "heart.slash.fill")
            .font(.system(size: 82, weight: .heavy))
            .foregroundStyle(iconColor)
            .shadow(color: shadowColor, radius: 18, y: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
            .task {
                await runAnimation()
            }
    }

    private var iconColor: Color {
        isLiked
            ? MHBTheme.ColorToken.danger.color
            : MHBTheme.ColorToken.labelSecondary.color
    }

    private var shadowColor: Color {
        isLiked
            ? MHBTheme.ColorToken.danger.color.opacity(0.28)
            : MHBTheme.ColorToken.labelPrimary.color.opacity(0.18)
    }

    @MainActor
    private func runAnimation() async {
        withAnimation(.smooth(duration: 0.16, extraBounce: 0.48)) {
            scale = 1
            opacity = 1
            yOffset = 0
        }

        try? await Task.sleep(for: .milliseconds(280))

        withAnimation(.easeOut(duration: 0.32)) {
            scale = 1.24
            opacity = 0
            yOffset = -34
        }
    }
}
