import Proton
import UIKit
import MaohuobanDesignSystem

// PublishArticleImageAttachmentView 图文图片附件视图
// 核心职责：
// - 作为 Proton block attachment 渲染本地图片和图片说明
// - 为删除、替换和图注编辑提供独立交互入口
@MainActor
final class PublishArticleImageAttachmentView: UIView, AttachmentViewIdentifying, UITextFieldDelegate {
    let blockID: UUID
    private(set) var mediaID: UUID
    private(set) var selectedImage: PublishSelectedImage

    var caption: String {
        captionField.text ?? ""
    }

    nonisolated var name: EditorContent.Name {
        EditorContent.Name("maohuoban.publish.article.image")
    }

    nonisolated var type: AttachmentType {
        .block
    }

    private let onCaptionChange: (UUID, String) -> Void
    private let onReplace: (UUID) -> Void
    private let onDelete: (UUID) -> Void
    private let imageView = UIImageView()
    private let replaceButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let captionField = UITextField()

    init(
        blockID: UUID,
        mediaID: UUID,
        caption: String,
        selectedImage: PublishSelectedImage,
        onCaptionChange: @escaping (UUID, String) -> Void,
        onReplace: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.blockID = blockID
        self.mediaID = mediaID
        self.selectedImage = selectedImage
        self.onCaptionChange = onCaptionChange
        self.onReplace = onReplace
        self.onDelete = onDelete
        super.init(frame: .zero)
        setup()
        captionField.text = caption
        imageView.image = selectedImage.image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateItem(_ selectedImage: PublishSelectedImage) {
        guard self.mediaID != selectedImage.id || imageView.image !== selectedImage.image else {
            return
        }
        self.mediaID = selectedImage.id
        self.selectedImage = selectedImage
        imageView.image = selectedImage.image
    }

    private func setup() {
        backgroundColor = .clear

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = MHBTheme.Radius.medium
        addSubview(imageView)

        replaceButton.translatesAutoresizingMaskIntoConstraints = false
        replaceButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
        replaceButton.tintColor = .white
        replaceButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        replaceButton.layer.cornerRadius = 14
        replaceButton.addTarget(self, action: #selector(replaceTapped), for: .touchUpInside)
        addSubview(replaceButton)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        deleteButton.layer.cornerRadius = 14
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        addSubview(deleteButton)

        captionField.translatesAutoresizingMaskIntoConstraints = false
        captionField.placeholder = "添加图片注释"
        captionField.font = .systemFont(ofSize: 14)
        captionField.textColor = MHBTheme.ColorToken.labelSecondary.publishUIKitColor
        captionField.borderStyle = .none
        captionField.textAlignment = .center
        captionField.backgroundColor = MHBTheme.ColorToken.separatorSoft.publishUIKitColor
        captionField.layer.cornerRadius = MHBTheme.Radius.small
        captionField.layer.masksToBounds = true
        captionField.delegate = self
        captionField.addTarget(self, action: #selector(captionChanged), for: .editingChanged)
        addSubview(captionField)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 240),

            replaceButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 8),
            replaceButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            replaceButton.widthAnchor.constraint(equalToConstant: 28),
            replaceButton.heightAnchor.constraint(equalToConstant: 28),

            deleteButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            captionField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            captionField.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionField.trailingAnchor.constraint(equalTo: trailingAnchor),
            captionField.heightAnchor.constraint(equalToConstant: 40),
            captionField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    @objc private func deleteTapped() {
        onDelete(blockID)
    }

    @objc private func replaceTapped() {
        onReplace(blockID)
    }

    @objc private func captionChanged() {
        onCaptionChange(blockID, caption)
    }
}
