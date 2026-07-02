import SwiftUI

// MHBPreviewableAssetImage 可预览本地资源图
// 核心职责：
// - 在业务布局中渲染可点击图片源并向宿主注册位置快照
// - 在点击时发起带有画廊上下文的自定义大图预览
public struct MHBPreviewableAssetImage: View {
    @Environment(\.mhbImagePreviewPresentAction) private var presentAction

    let galleryID: String
    let items: [MHBImagePreviewAsset]
    let index: Int
    let cornerRadius: CGFloat
    let contentMode: ContentMode
    private let selection: Binding<Int>?

    @State private var sourceObserver = MHBImagePreviewSourceObserver()

    public init(
        galleryID: String,
        items: [MHBImagePreviewAsset],
        index: Int,
        selection: Binding<Int>? = nil,
        cornerRadius: CGFloat = 0,
        contentMode: ContentMode = .fill
    ) {
        self.galleryID = galleryID
        self.items = items
        self.index = index
        self.selection = selection
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
    }

    public var body: some View {
        Button(action: handleTap) {
            sourceAssetView
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
        }
        .buttonStyle(.plain)
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
                Color.clear
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
