import SwiftUI

// MHBRemoteImage 远程图片组件
// 核心职责：
// - 为 App 业务层保留稳定远程图片调用入口
// - 复用 App 与 Widget 共享的远程媒体加载策略
struct MHBRemoteImage<Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    let cachePolicy: URLRequest.CachePolicy
    let timeoutInterval: TimeInterval
    let contentMode: ContentMode
    let transaction: Transaction
    let placeholder: () -> Placeholder

    init(
        url: URL?,
        scale: CGFloat = 1,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 30,
        contentMode: ContentMode = .fill,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18)),
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
        self.contentMode = contentMode
        self.transaction = transaction
        self.placeholder = placeholder
    }

    var body: some View {
        MHBRemoteMediaImage(
            url: url,
            scale: scale,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            contentMode: contentMode,
            transaction: transaction,
            placeholder: placeholder
        )
    }
}
