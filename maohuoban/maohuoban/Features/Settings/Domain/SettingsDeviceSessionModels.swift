import Foundation

// SettingsDeviceSessionSummary 登录设备摘要
// 核心职责：
// - 描述设备管理列表的展示数据
// - 为设备详情路由提供稳定设备标识
struct SettingsDeviceSessionSummary: Identifiable, Decodable, Equatable, Hashable {
    let sessionID: String
    let deviceID: String
    let deviceName: String
    let deviceModel: String
    let platform: String
    let locationText: String
    let lastActiveText: String
    let isCurrentDevice: Bool

    var id: String { sessionID }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case deviceID = "device_id"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case platform
        case locationText = "location_text"
        case lastActiveText = "last_active_text"
        case isCurrentDevice = "is_current_device"
    }
}

// SettingsDeviceSessionDetails 登录设备详情
// 核心职责：
// - 描述单个登录设备的详细状态
// - 为远程移除设备提供确认信息
struct SettingsDeviceSessionDetails: Decodable, Equatable, Hashable {
    let summary: SettingsDeviceSessionSummary
    let osVersion: String
    let appVersion: String
    let firstLoginText: String
    let ipAddress: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case deviceID = "device_id"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case platform
        case osVersion = "os_version"
        case appVersion = "app_version"
        case locationText = "location_text"
        case ipAddress = "ip_address"
        case firstLoginText = "first_login_text"
        case lastActiveText = "last_active_text"
        case isCurrentDevice = "is_current_device"
    }

    init(
        summary: SettingsDeviceSessionSummary,
        osVersion: String,
        appVersion: String,
        firstLoginText: String,
        ipAddress: String
    ) {
        self.summary = summary
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.firstLoginText = firstLoginText
        self.ipAddress = ipAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = SettingsDeviceSessionSummary(
            sessionID: try container.decode(String.self, forKey: .sessionID),
            deviceID: try container.decode(String.self, forKey: .deviceID),
            deviceName: try container.decode(String.self, forKey: .deviceName),
            deviceModel: try container.decode(String.self, forKey: .deviceModel),
            platform: try container.decode(String.self, forKey: .platform),
            locationText: try container.decode(String.self, forKey: .locationText),
            lastActiveText: try container.decode(String.self, forKey: .lastActiveText),
            isCurrentDevice: try container.decode(Bool.self, forKey: .isCurrentDevice)
        )
        osVersion = try container.decode(String.self, forKey: .osVersion)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        firstLoginText = try container.decode(String.self, forKey: .firstLoginText)
        ipAddress = try container.decode(String.self, forKey: .ipAddress)
    }
}

// SettingsDeviceSessionList 登录设备列表响应数据
// 核心职责：
// - 承接后端设备列表 data 包装
// - 让仓储保留后端 message 给 Store 消费
struct SettingsDeviceSessionList: Decodable, Equatable {
    let devices: [SettingsDeviceSessionSummary]
}

// SettingsDeviceSessionRepository 登录设备仓储协议
// 核心职责：
// - 隔离设备管理页面与后端实现
// - 支持后端未接入时替换为 mock 数据源
protocol SettingsDeviceSessionRepository {
    func fetchDevices() async throws(MHBAPIError) -> MHBAPIResponse<SettingsDeviceSessionList>
    func fetchDeviceDetails(
        sessionID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsDeviceSessionDetails>
    func removeDevice(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse>
}
