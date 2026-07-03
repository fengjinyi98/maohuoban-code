import SwiftUI

// MHBScrollEdgeEffectStyle+Loft 补齐照片式滚动边缘能力
// 核心职责：
// - 让业务页面使用 .scrollEdgeEffectStyle(.loft, for:) 表达沉浸式相册滚动语义
// - 在当前 SDK 暂无公开 loft 符号时映射到可编译的系统边缘效果
extension ScrollEdgeEffectStyle {
    static var loft: ScrollEdgeEffectStyle {
        .soft
    }
}
