import Foundation

// MockSettingsDeviceSessionRepository 设备管理 Mock 仓储
// 核心职责：
// - 在后端接口未接入时提供稳定设备列表
// - 支持设备详情读取与移除链路验证
@MainActor
final class MockSettingsDeviceSessionRepository: SettingsDeviceSessionRepository {
    private var devices: [SettingsDeviceSessionSummary]

    init(devices: [SettingsDeviceSessionSummary] = SettingsMockData.deviceSessions) {
        self.devices = devices
    }

    func fetchDevices() async throws(MHBAPIError) -> MHBAPIResponse<SettingsDeviceSessionList> {
        MHBAPIResponse(
            success: true,
            code: "account.devices_loaded",
            message: "登录设备已加载",
            data: SettingsDeviceSessionList(devices: devices)
        )
    }

    func fetchDeviceDetails(
        sessionID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsDeviceSessionDetails> {
        guard let summary = devices.first(where: { $0.sessionID == sessionID }) else {
            throw .business(code: "account.device_not_found", message: "设备不存在或已移除", statusCode: 404)
        }

        return MHBAPIResponse(
            success: true,
            code: "account.device_loaded",
            message: "登录设备详情已加载",
            data: SettingsDeviceSessionDetails(
                summary: summary,
                osVersion: summary.isCurrentDevice ? "iOS 27.0" : "iOS 26.5",
                appVersion: "1.0.0 (Mock)",
                firstLoginText: summary.isCurrentDevice ? "今天 09:12" : "6月18日 20:40",
                ipAddress: summary.isCurrentDevice ? "192.168.2.18" : "120.245.88.16"
            )
        )
    }

    func removeDevice(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse> {
        guard devices.contains(where: { $0.sessionID == sessionID }) else {
            throw .business(code: "account.device_not_found", message: "设备不存在或已移除", statusCode: 404)
        }
        devices.removeAll { $0.sessionID == sessionID }
        return MHBAPIResponse(
            success: true,
            code: "account.device_revoked",
            message: "登录设备已移除",
            data: MHBEmptyResponse()
        )
    }
}

// SettingsMockData 设置功能 Mock 数据
// 核心职责：
// - 集中提供设置页后端缺口的模拟数据
// - 保持页面默认展示与旧项目一致
enum SettingsMockData {
    static let username = "阿毛"
    static let phoneMasked = "155****4195"

    static let deviceSessions: [SettingsDeviceSessionSummary] = [
        SettingsDeviceSessionSummary(
            sessionID: "session-current",
            deviceID: "device-current",
            deviceName: "iPhone 17 Pro",
            deviceModel: "iPhone",
            platform: "iOS",
            locationText: "上海",
            lastActiveText: "当前在线",
            isCurrentDevice: true
        ),
        SettingsDeviceSessionSummary(
            sessionID: "session-ipad",
            deviceID: "device-ipad",
            deviceName: "iPad Pro",
            deviceModel: "iPad",
            platform: "iPadOS",
            locationText: "杭州",
            lastActiveText: "昨天 21:34",
            isCurrentDevice: false
        ),
        SettingsDeviceSessionSummary(
            sessionID: "session-old",
            deviceID: "device-old",
            deviceName: "iPhone 15",
            deviceModel: "iPhone",
            platform: "iOS",
            locationText: "北京",
            lastActiveText: "6月17日 08:20",
            isCurrentDevice: false
        )
    ]
}

// SettingsMockError 设置 Mock 错误
// 核心职责：
// - 描述 mock 数据源的可恢复错误
// - 为 Store 暴露用户可理解的错误文案
enum SettingsMockError: LocalizedError {
    case deviceNotFound

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            "设备不存在或已移除"
        }
    }
}
