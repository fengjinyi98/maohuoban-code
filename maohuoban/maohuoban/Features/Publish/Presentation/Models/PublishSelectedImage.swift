import UIKit

// PublishSelectedImage 发布页本地图片预览模型
struct PublishSelectedImage: Identifiable {
    let id: UUID
    let image: UIImage

    init(id: UUID = UUID(), image: UIImage) {
        self.id = id
        self.image = image
    }
}
