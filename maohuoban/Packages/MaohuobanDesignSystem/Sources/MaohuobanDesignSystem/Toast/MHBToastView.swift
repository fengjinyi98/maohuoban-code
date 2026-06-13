// MHBToastView.swift Toast卡片物理渲染视图
// 核心职责：
// - 根据设备的安全区域（Safe Area）适配灵动岛或刘海屏高度与偏移
// - 使用 iOS 27 的 ConcentricRectangle 绘制高保真黑色卡片背景
// - 实现灵动岛在缩拢状态与展开状态下的比例缩放、渐变淡入及 Drag 手势清除

import SwiftUI

// MHBToastContentView 提示内容子视图
// 核心职责：绘制图标、标题与详细文案，包含 wiggle 摆动动效与模糊转场
struct MHBToastContentView: View {
    let toast: MHBToast
    let isExpanded: Bool
    let haveDynamicIsland: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .font(toast.symbolFont)
                .foregroundStyle(
                    toast.symbolForegroundStyleColor1,
                    toast.symbolForegroundStyleColor2
                )
                .symbolEffect(.wiggle, options: .default.speed(1.5), value: isExpanded)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                if haveDynamicIsland {
                    Spacer(minLength: 0)
                }
                Text(toast.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(.white.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, haveDynamicIsland ? 12 : 0)
            .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .compositingGroup()
        .blur(radius: isExpanded ? 0 : 5)
        .opacity(isExpanded ? 1 : 0)
    }
}

// MHBToastView 根组件视图
// 核心职责：根据设备类型计算并展示 Dynamic Island 伸缩特效
public struct MHBToastView: View {
    var window: MHBPassThroughWindow

    public init(window: MHBPassThroughWindow) {
        self.window = window
    }

    private var isExpanded: Bool {
        window.isPresented
    }

    public var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let size = geometry.size

            let haveDynamicIsland = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = 11 + max((safeArea.top - 59), 0)

            let expandedWidth = size.width - 20
            let expandedHeight: CGFloat = haveDynamicIsland ? 90 : 70
            let scaleX: CGFloat = isExpanded ? 1 : (dynamicIslandWidth / expandedWidth)
            let scaleY: CGFloat = isExpanded ? 1 : (dynamicIslandHeight / expandedHeight)

            ZStack {
                if let toast = window.toast {
                    ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
                        .fill(.black)
                        .overlay {
                            MHBToastContentView(
                                toast: toast,
                                isExpanded: isExpanded,
                                haveDynamicIsland: haveDynamicIsland
                            )
                            .frame(width: expandedWidth, height: expandedHeight)
                            .scaleEffect(x: scaleX, y: scaleY)
                        }
                        .frame(
                            width: isExpanded ? expandedWidth : dynamicIslandWidth,
                            height: isExpanded ? expandedHeight : dynamicIslandHeight
                        )
                        .offset(
                            y: haveDynamicIsland ? topOffset : (isExpanded ? safeArea.top + 10 : -80)
                        )
                        .opacity(haveDynamicIsland ? 1 : (isExpanded ? 1 : 0))
                        .animation(.linear(duration: 0.02).delay(isExpanded ? 0 : 0.28)) { content in
                            content.opacity(haveDynamicIsland ? (isExpanded ? 1 : 0) : 1)
                        }
                        .geometryGroup()
                        .contentShape(.rect)
                        .gesture(
                            DragGesture().onEnded { value in
                                if value.translation.height < 0 {
                                    window.isPresented = false
                                }
                            }
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isExpanded)
        }
    }
}
