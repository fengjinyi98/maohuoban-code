import UIKit

// MHBPhotoGridCameraCell 照片网格相机入口
// 核心职责：
// - 在媒体选择器首格提供拍照入口
// - 与 PhotoKit 资源格保持稳定尺寸和视觉层级
final class MHBPhotoGridCameraCell: UICollectionViewCell {
    static let reuseIdentifier = "MHBPhotoGridCameraCell"

    private let iconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let view = UIImageView(image: UIImage(systemName: "camera.fill", withConfiguration: configuration))
        view.tintColor = .white
        view.contentMode = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "拍照"
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6)
        ])
    }
}
