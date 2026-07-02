import Foundation

// PetWorldFeedDetailContentBlock 图文混排内容块
// 核心职责：
// - 按用户发布时的排版顺序承载正文与图片
// - 将图片说明绑定到对应图片块，避免渲染层重排
enum PetWorldFeedDetailContentBlock: Identifiable, Equatable {
    case paragraph(id: String, text: String)
    case image(id: String, media: PetWorldFeedDetailMedia, caption: String?)

    var id: String {
        switch self {
        case let .paragraph(id, _),
             let .image(id, _, _):
            return id
        }
    }
}
