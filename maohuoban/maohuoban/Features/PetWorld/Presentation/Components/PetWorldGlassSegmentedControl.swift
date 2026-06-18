import SwiftUI
import MaohuobanDesignSystem

// PetWorldGlassSegmentedControl 宠物世界玻璃频道控件
// 核心职责：
// - 复刻参考 demo 的横向吸附、胶囊跟随和液态折射动效
// - 使用主题色驱动选中态文字和玻璃选中胶囊
struct PetWorldGlassSegmentedControl: View {
    var config: Config = .init()
    @Binding var selection: PetWorldFeedTab
    @Binding var tabs: [Tab]

    @State private var activeIndex: Int?
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var scrollPhase: ScrollPhase = .idle

    var body: some View {
        if tabs.isEmpty {
            Color.clear.frame(height: 50)
        } else {
            controlBody
        }
    }

    private var controlBody: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let activeSize = activeTabSize

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach($tabs) { $tab in
                        Text(tab.title)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .padding(.horizontal, config.refractionDepth + 3)
                            .frame(height: containerSize.height)
                            .onGeometryChange(for: CGSize.self) { proxy in
                                proxy.size
                            } action: { newValue in
                                tab.viewSize = newValue
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                selection = tab.feedTab
                            }
                    }
                }
                .overlay {
                    highlightedTitles(containerSize: containerSize, activeSize: activeSize)
                }
                .visualEffect { [config] content, proxy in
                    let rect = proxy.frame(in: .scrollView)
                    let minX = rect.minX + activeSize.width / 2

                    return content.layerEffect(
                        ShaderLibrary.petWorldLiquidLens(
                            .float2(activeSize),
                            .float(-minX),
                            .float(config.refractionAmount),
                            .float(config.refractionDepth)
                        ),
                        maxSampleOffset: .init(width: 200, height: 100)
                    )
                }
                .background(alignment: .leading) {
                    selectedPill(size: activeSize)
                }
                .animation(
                    .interactiveSpring(response: 0.35, dampingFraction: 0.3, blendDuration: 0.4),
                    value: activeIndex
                )
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, containerSize.width / 2)
            .scrollTargetBehavior(PetWorldSegmentScrollTarget(tabs: $tabs))
            .scrollPosition($scrollPosition, anchor: .center)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x + geometry.contentInsets.leading
            } action: { _, newValue in
                syncSelection(for: newValue)
            }
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase
            }
        }
        .frame(height: 50)
        .task {
            installInitialPositionIfNeeded()
        }
        .onChange(of: selection) { _, _ in
            scrollToSelectionIfNeeded()
        }
    }

    private var selectedIndex: Int {
        tabs.firstIndex { $0.feedTab == selection } ?? 0
    }

    private var activeTabSize: CGSize {
        let index = activeIndex ?? selectedIndex

        guard tabs.indices.contains(index) else {
            return .zero
        }

        return tabs[index].viewSize
    }

    private func highlightedTitles(containerSize: CGSize, activeSize: CGSize) -> some View {
        HStack(spacing: 0) {
            ForEach($tabs) { $tab in
                Text(tab.title)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(config.tint)
                    .padding(.horizontal, config.refractionDepth + 3)
                    .frame(height: containerSize.height)
            }
        }
        .mask(alignment: .leading) {
            Capsule()
                .frame(width: activeSize.width, height: activeSize.height)
                .visualEffect { content, proxy in
                    let midX = proxy.frame(in: .scrollView).midX

                    return content.offset(x: -midX)
                }
        }
        .allowsTightening(false)
    }

    private func selectedPill(size: CGSize) -> some View {
        Capsule()
            .fill(.clear)
            .frame(width: size.width, height: size.height)
            .glassEffect(.regular, in: .capsule)
            .visualEffect { content, proxy in
                let midX = proxy.frame(in: .scrollView).midX

                return content.offset(x: -midX)
            }
    }

    private func syncSelection(for offset: CGFloat) {
        guard activeIndex != nil,
              let index = tabs.closestSnapPointIndex(offset),
              tabs.indices.contains(index)
        else {
            return
        }

        activeIndex = index

        if scrollPhase != .animating {
            selection = tabs[index].feedTab
        }
    }

    private func installInitialPositionIfNeeded() {
        guard activeIndex == nil else {
            return
        }

        let index = selectedIndex
        activeIndex = index
        scrollPosition.scrollTo(x: tabs.snapPoints[index])
    }

    private func scrollToSelectionIfNeeded() {
        let index = selectedIndex

        guard activeIndex != index,
              tabs.snapPoints.indices.contains(index)
        else {
            return
        }

        withAnimation(.snappy) {
            scrollPosition.scrollTo(x: tabs.snapPoints[index])
        }
    }

    // Config 控件动效配置
    // 核心职责：
    // - 提供选中态主题色和折射强度参数
    // - 与参考 demo 保持一致的动效调性
    struct Config {
        var tint: Color = MHBTheme.ColorToken.primary.color
        var refractionAmount: CGFloat = 10
        var refractionDepth: CGFloat = 17
    }

    // Tab 频道测量模型
    // 核心职责：
    // - 绑定业务频道和展示标题
    // - 持有当前文字尺寸供吸附点计算
    struct Tab: Identifiable {
        let feedTab: PetWorldFeedTab
        let title: String
        var viewSize: CGSize = .zero

        init(feedTab: PetWorldFeedTab) {
            self.feedTab = feedTab
            self.title = feedTab.rawValue
        }

        var id: PetWorldFeedTab { feedTab }
    }
}
