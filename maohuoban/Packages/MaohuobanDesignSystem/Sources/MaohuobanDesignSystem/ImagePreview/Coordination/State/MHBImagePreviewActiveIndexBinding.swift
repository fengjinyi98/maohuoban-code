import Foundation

// MHBImagePreviewActiveIndexBinding 图片预览激活索引绑定
// 核心职责：
// - 将预览页当前索引同步回业务画廊
// - 让关闭 Hero 能回落到当前页 source，而非打开时 source
struct MHBImagePreviewActiveIndexBinding {
    let update: @MainActor (Int) -> Void

    @MainActor
    func callAsFunction(_ activeIndex: Int) {
        update(activeIndex)
    }
}
