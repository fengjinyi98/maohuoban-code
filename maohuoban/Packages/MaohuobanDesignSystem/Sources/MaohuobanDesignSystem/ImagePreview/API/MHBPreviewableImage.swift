import SwiftUI

// MHBPreviewableImage 通用可预览图片
// 核心职责：
// - 为本地和远端图片提供同一套点击预览与 source 注册能力
// - 保持图片布局骨架一致，只在交互层区分是否可预览
// 设计备注：
// - 不使用 Button 实现：外层卡片常用 NavigationLink 包裹（Button 嵌套 Button），
//   SwiftUI 会把非 Button 区域的点击按"最近 Button"分配给内部 Button，导致
//   多图卡片里点击文本、操作栏、空白等非图片区域错误触发最近图片的大图预览。
// - 改用 .contentShape + .onTapGesture：命中区域严格限定为图片 frame，
//   外层 NavigationLink 可以正常接收卡片剩余非图片区域的点击。
// - 保留 .accessibilityAddTraits(.isButton) 让 VoiceOver 仍将其识别为按钮。
public struct MHBPreviewableImage<Placeholder: View>: View {
    @Environment(\.mhbImagePreviewPresentAction) private var presentAction

    let galleryID: String
    let items: [MHBImagePreviewAsset]
    let index: Int
    let cornerRadius: CGFloat
    let contentMode: ContentMode
    private let selection: Binding<Int>?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var sourceObserver = MHBImagePreviewSourceObserver()

    public init(
        galleryID: String,
        items: [MHBImagePreviewAsset],
        index: Int,
        selection: Binding<Int>? = nil,
        cornerRadius: CGFloat = 0,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.galleryID = galleryID
        self.items = items
        self.index = index
        self.selection = selection
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    public var body: some View {
        sourceAssetView
            .contentShape(.rect(cornerRadius: cornerRadius))
            .background {
#if canImport(UIKit)
                if let currentAsset {
                    MHBImagePreviewSourceRegistrationView(
                        sourceID: sourceID,
                        cornerRadius: cornerRadius,
                        asset: currentAsset,
                        observer: sourceObserver
                    )
                }
#endif
            }
            .onTapGesture(perform: handleTap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(currentAsset?.accessibilityLabel ?? "查看大图")
            .accessibilityIdentifier("查看大图")
            .accessibilityAddTraits(.isButton)
    }

    private var sourceAssetView: some View {
        Group {
            if let currentAsset {
                MHBImagePreviewAssetImage(
                    asset: currentAsset,
                    contentMode: contentMode,
                    cornerRadius: cornerRadius
                )
            } else {
                placeholder()
            }
        }
    }

    private var currentAsset: MHBImagePreviewAsset? {
        guard items.indices.contains(index) else {
            return nil
        }
        return items[index]
    }

    private var sourceID: MHBImagePreviewSourceID {
        MHBImagePreviewSourceID(galleryID: galleryID, index: index)
    }

    private func handleTap() {
        guard let presentAction else { return }

        let request = MHBImagePreviewRequest(
            galleryID: galleryID,
            items: items,
            initialIndex: index
        )
        let snapshot = sourceObserver.captureSnapshot()
        presentAction(
            request,
            preferredSource: snapshot,
            activeIndexBinding: makeActiveIndexBinding()
        )
    }

    private func makeActiveIndexBinding() -> MHBImagePreviewActiveIndexBinding? {
        guard let selection else {
            return nil
        }

        return MHBImagePreviewActiveIndexBinding { newIndex in
            guard selection.wrappedValue != newIndex else {
                return
            }
            selection.wrappedValue = newIndex
        }
    }
}
