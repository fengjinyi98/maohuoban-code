import SwiftUI
import UIKit

// MHBImagePreviewZoomScrollView 预览页缩放滚动容器
// 核心职责：
// - 以原生 UIScrollView 承担 pinch 缩放、双击缩放、平移与回弹
// - 将当前缩放状态高频采样回传给 Overlay 做外层手势闸门和 chrome 联动
final class MHBImagePreviewZoomScrollView: UIScrollView, UIScrollViewDelegate {
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let singleTapRecognizer = UITapGestureRecognizer()
    private let doubleTapRecognizer = UITapGestureRecognizer()

    private var currentAssetID: String?
    private weak var currentImage: UIImage?
    private var lastBoundsSize: CGSize = .zero
    private var lastReportedState: MHBImagePreviewZoomState?
    private let stateRelay = MHBImagePreviewZoomStateRelay()

    var onSingleTap: (() -> Void)?
    var onWillZoomIn: (() -> Void)?
    var onStateChange: ((MHBImagePreviewZoomState) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        asset: MHBImagePreviewAsset,
        image: UIImage,
        onSingleTap: @escaping () -> Void,
        onWillZoomIn: @escaping () -> Void,
        onStateChange: @escaping (MHBImagePreviewZoomState) -> Void
    ) {
        self.onSingleTap = onSingleTap
        self.onWillZoomIn = onWillZoomIn
        self.onStateChange = onStateChange
        stateRelay.onDeliver = { [weak self] state in
            self?.onStateChange?(state)
        }

        let assetChanged = currentAssetID != asset.id
        let imageChanged = currentImage !== image

        guard assetChanged || imageChanged else {
            emitStateIfNeeded(reason: "updateUIView")
            return
        }

        currentAssetID = asset.id
        currentImage = image
        imageView.image = image
        lastReportedState = nil
        stateRelay.reset()
        setZoomScale(1, animated: false)
        recalculateLayout(preservingZoom: false, reason: assetChanged ? "asset changed" : "image refreshed")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.size.width > 0.5,
              bounds.size.height > 0.5 else {
            return
        }

        guard bounds.size != lastBoundsSize else {
            return
        }
        recalculateLayout(preservingZoom: true, reason: "bounds changed")
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        containerView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if zoomScale <= minimumZoomScale + 0.01 {
            onWillZoomIn?()
        }
        emitStateIfNeeded(reason: "willBeginZooming", force: true)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        emitStateIfNeeded(reason: "didZoom")
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        emitStateIfNeeded(reason: "didEndZooming", force: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if zoomScale > 1.01 || isTracking || isDecelerating {
            emitStateIfNeeded(reason: "didScroll")
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        emitStateIfNeeded(reason: "didEndDragging", force: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        emitStateIfNeeded(reason: "didEndDecelerating", force: true)
    }

    @objc private func handleSingleTap() {
        onSingleTap?()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let locationInContainer = recognizer.location(in: containerView)

        if zoomScale > minimumZoomScale + 0.01 {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }

        onWillZoomIn?()

        let targetZoomScale = resolvedDoubleTapZoomScale()
        let zoomRect = zoomRect(for: targetZoomScale, center: locationInContainer)
        zoom(to: zoomRect, animated: true)
    }

    private func configureView() {
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        bouncesZoom = true
        backgroundColor = .clear
        clipsToBounds = true

        containerView.backgroundColor = .clear
        addSubview(containerView)

        imageView.contentMode = .scaleToFill
        imageView.clipsToBounds = true
        containerView.addSubview(imageView)

        singleTapRecognizer.addTarget(self, action: #selector(handleSingleTap))
        singleTapRecognizer.cancelsTouchesInView = false

        doubleTapRecognizer.addTarget(self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.cancelsTouchesInView = false

        singleTapRecognizer.require(toFail: doubleTapRecognizer)

        addGestureRecognizer(singleTapRecognizer)
        addGestureRecognizer(doubleTapRecognizer)
    }

    private func recalculateLayout(preservingZoom: Bool, reason: String) {
        guard let image = imageView.image,
              bounds.size.width > 0.5,
              bounds.size.height > 0.5 else {
            return
        }

        let fittedSize = aspectFitSize(for: image.size, in: bounds.size)
        let previousZoomScale = zoomScale
        let resolvedMaximumZoomScale = maximumZoomScale(for: image.size, fittedSize: fittedSize)

        containerView.frame = CGRect(origin: .zero, size: fittedSize)
        imageView.frame = containerView.bounds
        contentSize = fittedSize
        minimumZoomScale = 1
        maximumZoomScale = resolvedMaximumZoomScale

        if preservingZoom, previousZoomScale > 1.01 {
            zoomScale = min(max(previousZoomScale, minimumZoomScale), maximumZoomScale)
        } else {
            zoomScale = minimumZoomScale
        }

        centerContent()
        lastBoundsSize = bounds.size
        emitStateIfNeeded(reason: "recalculateLayout", force: true)
    }

    private func centerContent() {
        let horizontalInset = max((bounds.width - contentSize.width) * 0.5, 0)
        let verticalInset = max((bounds.height - contentSize.height) * 0.5, 0)
        contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    private func aspectFitSize(for imageSize: CGSize, in viewportSize: CGSize) -> CGSize {
        guard imageSize.width > 0.5,
              imageSize.height > 0.5,
              viewportSize.width > 0.5,
              viewportSize.height > 0.5 else {
            return viewportSize
        }

        let scale = min(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func maximumZoomScale(for imageSize: CGSize, fittedSize: CGSize) -> CGFloat {
        guard fittedSize.width > 0.5,
              fittedSize.height > 0.5 else {
            return 4
        }

        let nativeScale = max(
            imageSize.width / fittedSize.width,
            imageSize.height / fittedSize.height
        )
        return min(max(nativeScale, 4), 8)
    }

    private func resolvedDoubleTapZoomScale() -> CGFloat {
        min(maximumZoomScale, max(minimumZoomScale * 2.5, 2.5))
    }

    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let width = bounds.width / scale
        let height = bounds.height / scale
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }

    private func emitStateIfNeeded(reason: String, force: Bool = false) {
        let state = MHBImagePreviewZoomState(
            zoomScale: zoomScale,
            contentOffset: contentOffset,
            contentSize: contentSize,
            viewportSize: bounds.size,
            isTracking: isTracking,
            isDecelerating: isDecelerating,
            isZooming: isZooming
        )

        if force == false,
           let lastReportedState,
           lastReportedState.isApproximatelyEqual(to: state) {
            return
        }

        lastReportedState = state
        stateRelay.submit(state)
        _ = reason
        _ = force
    }
}
