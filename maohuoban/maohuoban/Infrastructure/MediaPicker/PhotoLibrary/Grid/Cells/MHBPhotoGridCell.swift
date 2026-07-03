import UIKit

// MHBPhotoGridCell PhotoKit 照片网格单元格
// 核心职责：
// - 展示媒体缩略图、类型标识和选择序号
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

    private let videoBadge: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        label.textAlignment = .center
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let selectionBadge: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemBlue
        label.layer.cornerRadius = 11
        label.layer.borderColor = UIColor.white.cgColor
        label.layer.borderWidth = 1.5
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let selectionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let disabledOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let disabledBadge: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let view = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: configuration))
        view.tintColor = .white
        view.backgroundColor = UIColor.systemGreen
        view.contentMode = .center
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
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
        isVideo: Bool,
        durationText: String?,
        selectionIndex: Int?,
        isResolving: Bool,
        isDisabled: Bool
    ) {
        representedAssetID = assetID
        imageView.image = image
        livePhotoBadge.isHidden = !isLivePhoto
        videoBadge.isHidden = !isVideo
        videoBadge.text = durationText
        updateSelectionIndex(selectionIndex)
        updateResolvingState(isResolving)
        updateDisabledState(isDisabled)
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

    func updateSelectionIndex(_ selectionIndex: Int?) {
        selectionBadge.isHidden = selectionIndex == nil
        selectionBadge.text = selectionIndex.map(String.init)
    }

    func updateDisabledState(_ isDisabled: Bool) {
        disabledOverlay.isHidden = !isDisabled
        disabledBadge.isHidden = !isDisabled
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedAssetID = nil
        imageView.image = nil
        livePhotoBadge.isHidden = true
        videoBadge.isHidden = true
        videoBadge.text = nil
        updateSelectionIndex(nil)
        updateResolvingState(false)
        updateDisabledState(false)
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(livePhotoBadge)
        contentView.addSubview(videoBadge)
        contentView.addSubview(selectionBadge)
        contentView.addSubview(disabledOverlay)
        contentView.addSubview(disabledBadge)
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

            videoBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            videoBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            videoBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 42),
            videoBadge.heightAnchor.constraint(equalToConstant: 22),

            selectionBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            selectionBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            selectionBadge.widthAnchor.constraint(equalToConstant: 22),
            selectionBadge.heightAnchor.constraint(equalToConstant: 22),

            disabledOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            disabledOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            disabledOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            disabledOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            disabledBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            disabledBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            disabledBadge.widthAnchor.constraint(equalToConstant: 24),
            disabledBadge.heightAnchor.constraint(equalToConstant: 24),

            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: selectionOverlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: selectionOverlay.centerYAnchor)
        ])
    }
}
