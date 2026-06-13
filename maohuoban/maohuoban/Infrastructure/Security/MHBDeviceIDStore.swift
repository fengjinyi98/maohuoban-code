import Foundation

// MHBDeviceIDStore 设备标识存储
// 核心职责：
// - 为后端 device_sessions 提供稳定 device_id
// - 将 UserDefaults 写入限制在显式方法调用中
struct MHBDeviceIDStore {
    private let key = "maohuoban.device_id"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentDeviceID() -> String {
        if let deviceID = defaults.string(forKey: key), !deviceID.isEmpty {
            return deviceID
        }
        let deviceID = "ios-\(UUID().uuidString.lowercased())"
        defaults.set(deviceID, forKey: key)
        return deviceID
    }
}
