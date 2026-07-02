import SwiftUI

// PublishComposerSheet 发布页配置弹层类型
enum PublishComposerSheet: String, Identifiable {
    case pet
    case location
    case visibility
    case album
    case mentionUser

    var id: String { rawValue }

    var presentationDetents: Set<PresentationDetent>? {
        switch self {
        case .location, .mentionUser:
            [.large]
        case .pet, .visibility, .album:
            nil
        }
    }

    var usesFittedPresentationSizing: Bool {
        switch self {
        case .pet, .visibility, .album:
            true
        case .location, .mentionUser:
            false
        }
    }
}
