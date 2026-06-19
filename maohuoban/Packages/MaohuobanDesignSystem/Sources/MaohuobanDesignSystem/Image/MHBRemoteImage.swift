import SwiftUI

// MHBRemoteImage 统一远端图片组件
// 核心职责：
// - 统一承接远端图片加载、缓存和失败占位
// - 保持页面层不直接依赖第三方图片组件 API
public struct MHBRemoteImage<Placeholder: View>: View {
    private let source: String?
    private let contentMode: ContentMode
    private let cornerRadius: CGFloat
    @ViewBuilder private let placeholder: () -> Placeholder

    public init(
        source: String?,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = 0,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.source = source
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
    }

    public var body: some View {
        Color.clear
            .overlay {
                switch MHBImageSourceKind.remoteOrAsset(from: source) {
                case let .remote(rawValue):
                    if let url = URL(string: rawValue) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: contentMode)
                            } else {
                                placeholder()
                            }
                        }
                    } else {
                        placeholder()
                    }

                case let .localAsset(name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)

                case .systemSymbol, .empty:
                    placeholder()
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
