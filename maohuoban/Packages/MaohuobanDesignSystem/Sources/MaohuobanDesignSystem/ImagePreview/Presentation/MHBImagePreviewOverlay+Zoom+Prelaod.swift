import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewOverlay 缩放与预加载扩展
// 核心职责：
// - 承载全屏页内的缩放状态管理
// - 后台解码预览图并在主线程更新缓存
extension MHBImagePreviewOverlay {
    func handleZoomWillBegin(for index: Int) {
        guard index == session.activeIndex else { return }
        setChromeForcedHiddenByZoom(true)
    }

    func handleZoomStateChange(_ state: MHBImagePreviewZoomState, for index: Int) {
        let previousState = zoomStates[index]
        if let previousState,
           previousState.isApproximatelyEqual(to: state) {
            return
        }

        zoomStates[index] = state

        if index == session.activeIndex {
            let previousIdentity = previousState?.isIdentityZoom
            if previousIdentity != state.isIdentityZoom {
                syncZoomDrivenChromeVisibility(for: state)
            }
        }
    }

#if canImport(UIKit)
    func prefetchedImage(for asset: MHBImagePreviewAsset) -> UIImage? {
        assetImages[asset.sourceIdentifier]
    }
#endif

    func startPreloadAssets() {
#if canImport(UIKit)
        guard assetImages.isEmpty else { return }
        let items = session.items
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                var images: [String: UIImage] = [:]
                for item in items where images[item.sourceIdentifier] == nil {
                    let image: UIImage?
                    switch item.sourceKind {
                    case let .localAsset(name):
                        image = UIImage(named: name)
                    case let .remote(urlString):
                        if let url = URL(string: urlString) {
                            image = try? await UIImage(data: MHBRemoteMediaDataLoader.data(from: url))
                        } else {
                            image = nil
                        }
                    case .systemSymbol, .empty:
                        image = nil
                    }
                    guard let image else { continue }
                    _ = image.cgImage
                    images[item.sourceIdentifier] = image
                }
                return images
            }.value
            assetImages = result
        }
#endif
    }
}
