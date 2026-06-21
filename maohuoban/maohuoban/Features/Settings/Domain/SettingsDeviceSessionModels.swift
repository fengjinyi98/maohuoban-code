import Foundation

// SettingsDeviceSessionSummary 登录设备摘要
// 核心职责：
// - 描述设备管理列表的展示数据
// - 为设备详情路由提供稳定设备标识
struct SettingsDeviceSessionSummary: Identifiable, Equatable, Hashable {
    let deviceID: String
    let deviceName: String
    let deviceModel: String
    let platform: String
    let locationText: String
    let lastActiveText: String
    let isCurrentDevice: Bool

    var id: String { deviceID }
}

// SettingsDeviceSessionDetails 登录设备详情
// 核心职责：
// - 描述单个登录设备的详细状态
// - 为远程移除设备提供确认信息
struct SettingsDeviceSessionDetails: Equatable, Hashable {
    let summary: SettingsDeviceSessionSummary
    let osVersion: String
    let appVersion: String
    let firstLoginText: String
    let ipAddress: String
}

// SettingsDeviceSessionRepository 登录设备仓储协议
// 核心职责：
// - 隔离设备管理页面与后端实现
// - 支持后端未接入时替换为 mock 数据源
protocol SettingsDeviceSessionRepository: Sendable {
    func fetchDevices() async throws -> [SettingsDeviceSessionSummary]
    func fetchDeviceDetails(deviceID: String) async throws -> SettingsDeviceSessionDetails
    func removeDevice(deviceID: String) async throws
}
