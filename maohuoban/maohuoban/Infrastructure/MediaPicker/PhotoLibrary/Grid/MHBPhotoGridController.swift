import Photos
import UIKit

// MHBPhotoGridController PhotoKit 照片网格控制器
// 核心职责：
// - 管理 UICollectionView 数据源和复用
// - 转发用户选择资源事件给 SwiftUI 层
@MainActor
final class MHBPhotoGridController: NSObject {
    let collectionView: UICollectionView

    var assets: [MHBPhotoLibraryAsset] = [] {
        didSet {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
        }
    }
    var resolvingAssetID: String?
    var selectedAssetIDs: [String: Int] = [:]
    var onSelectAsset: ((MHBPhotoLibraryAsset) -> Void)?
    var onScrollDateChanged: ((MHBPhotoGridScrollDateSnapshot?) -> Void)?

    private let service: MHBPhotoLibraryService
    private let scrollDateFormatter = MHBPhotoGridScrollDateFormatter()
    private var currentScrollDateSnapshot: MHBPhotoGridScrollDateSnapshot?

    init(service: MHBPhotoLibraryService) {
        self.service = service

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init()
        setupCollectionView()
    }

    func updateResolvingAssetID(_ assetID: String?) {
        resolvingAssetID = assetID
        updateVisibleCellStates()
    }

    func updateSelectedAssetIDs(_ selectedAssetIDs: [String: Int]) {
        self.selectedAssetIDs = selectedAssetIDs
        updateVisibleCellStates()
    }

    private func updateVisibleCellStates() {
        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard indexPath.item < assets.count,
                  let cell = collectionView.cellForItem(at: indexPath) as? MHBPhotoGridCell
            else {
                return
            }
            let asset = assets[indexPath.item]
            cell.updateResolvingState(asset.id == resolvingAssetID)
            cell.updateSelectionIndex(selectedAssetIDs[asset.id])
        }
    }

    private func setupCollectionView() {
        collectionView.register(
            MHBPhotoGridCell.self,
            forCellWithReuseIdentifier: MHBPhotoGridCell.reuseIdentifier
        )
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = true
        collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 3)
        collectionView.alwaysBounceVertical = true
    }

    private func updateScrollDateSnapshot(forceNotify: Bool = false) {
        guard collectionView.contentSize.height > collectionView.bounds.height else {
            setScrollDateSnapshot(nil, forceNotify: forceNotify)
            return
        }

        guard let indexPath = currentScrollDateIndexPath(),
              indexPath.item < assets.count,
              let creationDate = assets[indexPath.item].asset.creationDate
        else {
            setScrollDateSnapshot(nil, forceNotify: forceNotify)
            return
        }

        let progress = scrollProgress()
        let snapshot = MHBPhotoGridScrollDateSnapshot(
            title: scrollDateFormatter.title(for: creationDate),
            progress: progress
        )
        setScrollDateSnapshot(snapshot, forceNotify: forceNotify)
    }

    private func setScrollDateSnapshot(
        _ snapshot: MHBPhotoGridScrollDateSnapshot?,
        forceNotify: Bool = false
    ) {
        guard forceNotify || currentScrollDateSnapshot != snapshot else {
            return
        }
        currentScrollDateSnapshot = snapshot
        onScrollDateChanged?(snapshot)
    }

    private func hideScrollDateSnapshot() {
        setScrollDateSnapshot(nil)
    }

    private func currentScrollDateIndexPath() -> IndexPath? {
        let visibleRect = CGRect(
            x: collectionView.bounds.minX,
            y: collectionView.contentOffset.y + collectionView.bounds.height * 0.5,
            width: collectionView.bounds.width,
            height: 1
        )

        let centeredIndexPaths = collectionView.indexPathsForVisibleItems
            .filter { indexPath in
                guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
                    return false
                }
                return attributes.frame.intersects(visibleRect)
            }
            .sorted()

        if let indexPath = centeredIndexPaths.first {
            return indexPath
        }

        return collectionView.indexPathsForVisibleItems.sorted().first
    }

    private func scrollProgress() -> CGFloat {
        let scrollableHeight = collectionView.contentSize.height
            + collectionView.adjustedContentInset.top
            + collectionView.adjustedContentInset.bottom
            - collectionView.bounds.height
        guard scrollableHeight > 0 else {
            return 0
        }

        let offset = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        return min(max(offset / scrollableHeight, 0), 1)
    }
}

extension MHBPhotoGridController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        assets.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MHBPhotoGridCell.reuseIdentifier,
            for: indexPath
        ) as? MHBPhotoGridCell else {
            return UICollectionViewCell()
        }

        let asset = assets[indexPath.item]
        cell.configure(
            assetID: asset.id,
            image: nil,
            isLivePhoto: asset.isLivePhoto,
            isVideo: asset.isVideo,
            durationText: asset.duration.map(Self.formatDuration(_:)),
            selectionIndex: selectedAssetIDs[asset.id],
            isResolving: asset.id == resolvingAssetID
        )
        _ = service.requestThumbnail(for: asset) { [weak cell] image in
            cell?.updateImage(image, for: asset.id)
        }
        return cell
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension MHBPhotoGridController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < assets.count else {
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelectAsset?(assets[indexPath.item])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollDateSnapshot()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hideScrollDateSnapshot()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            hideScrollDateSnapshot()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        hideScrollDateSnapshot()
    }
}

extension MHBPhotoGridController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let spacing: CGFloat = 2
        let columns: CGFloat = 4
        let width = collectionView.bounds.width
        let itemWidth = floor((width - spacing * (columns - 1)) / columns)
        return CGSize(width: itemWidth, height: itemWidth)
    }
}
