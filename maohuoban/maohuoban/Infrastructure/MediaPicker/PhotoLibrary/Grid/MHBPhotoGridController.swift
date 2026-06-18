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
        }
    }
    var resolvingAssetID: String?
    var onSelectAsset: ((MHBPhotoLibraryAsset) -> Void)?

    private let service: MHBPhotoLibraryService

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
        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard indexPath.item < assets.count,
                  let cell = collectionView.cellForItem(at: indexPath) as? MHBPhotoGridCell
            else {
                return
            }
            cell.updateResolvingState(assets[indexPath.item].id == assetID)
        }
    }

    private func setupCollectionView() {
        collectionView.register(
            MHBPhotoGridCell.self,
            forCellWithReuseIdentifier: MHBPhotoGridCell.reuseIdentifier
        )
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
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
            isResolving: asset.id == resolvingAssetID
        )
        _ = service.requestThumbnail(for: asset) { [weak cell] image in
            cell?.updateImage(image, for: asset.id)
        }
        return cell
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
