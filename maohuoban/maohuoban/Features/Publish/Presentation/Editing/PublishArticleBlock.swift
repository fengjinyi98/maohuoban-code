import Foundation

// PublishArticleBlock 图文编辑块
// 核心职责：
// - 承接图文页的文本块与图片块顺序
// - 为富文本编辑器和发布草稿同步提供稳定本地真值
struct PublishArticleBlock: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case text
        case image
    }

    let id: UUID
    var kind: Kind
    var text: String
    var mediaID: UUID?

    init(
        id: UUID = UUID(),
        kind: Kind = .text,
        text: String = "",
        mediaID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.mediaID = mediaID
    }

    var isImage: Bool {
        kind == .image
    }
}
