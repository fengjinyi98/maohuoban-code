import UIKit

// MHBIdentifiableUIImage 可识别本地图片
// 核心职责：
// - 为 fullScreenCover item 传递本地图片提供稳定身份
// - 避免业务页面重复定义图片包装模型
struct MHBIdentifiableUIImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
