// MHBToastType.swift Toast提示类型
// 核心职责：
// - 定义 Toast 提示的不同语义类型
// - 供不同视觉反馈组件进行色彩与图标匹配
public enum MHBToastType: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
    case loading
}
