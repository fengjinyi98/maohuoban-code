import UIKit

// MHBPhotoGridCell PhotoKit 照片网格单元格
// 核心职责：
// - 展示照片缩略图和 Live Photo 标识
// - 在资源解析时提供选中遮罩状态
final class MHBPhotoGridCell: UICollectionViewCell {
    static let reuseIdentifier = "MHBPhotoGridCell"

    var representedAssetID: String?

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = .secondarySystemFill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let livePhotoBadge: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let view = UIImageView(
            image: UIImage(systemName: "livephoto", withConfiguration: configuration)
        )
        view.tintColor = .white
        view.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        view.contentMode = .center
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let selectionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = .white
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        assetID: String,
        image: UIImage?,
        isLivePhoto: Bool,
        isResolving: Bool
    ) {
        representedAssetID = assetID
        imageView.image = image
        livePhotoBadge.isHidden = !isLivePhoto
        updateResolvingState(isResolving)
    }

    func updateImage(_ image: UIImage?, for assetID: String) {
        guard representedAssetID == assetID else {
            return
        }
        imageView.image = image
    }

    func updateResolvingState(_ isResolving: Bool) {
        selectionOverlay.isHidden = !isResolving
        if isResolving {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedAssetID = nil
        imageView.image = nil
        livePhotoBadge.isHidden = true
        updateResolvingState(false)
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(livePhotoBadge)
        contentView.addSubview(selectionOverlay)
        selectionOverlay.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            livePhotoBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            livePhotoBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            livePhotoBadge.widthAnchor.constraint(equalToConstant: 30),
            livePhotoBadge.heightAnchor.constraint(equalToConstant: 22),

            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: selectionOverlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: selectionOverlay.centerYAnchor)
        ])
    }
}
