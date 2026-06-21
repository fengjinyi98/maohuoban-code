import Foundation
import Observation

// SettingsDeviceSessionStore 设备会话状态源
// 核心职责：
// - 管理设备列表、详情读取和移除状态
// - 避免设置页面在渲染路径触发异步副作用
@MainActor
@Observable
final class SettingsDeviceSessionStore {
    private(set) var devices: [SettingsDeviceSessionSummary] = []
    private(set) var deviceDetails: [String: SettingsDeviceSessionDetails] = [:]
    private(set) var isLoadingDevices = false
    private(set) var loadingDetailDeviceID: String?
    private(set) var removingDeviceID: String?
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let repository: any SettingsDeviceSessionRepository

    init(repository: any SettingsDeviceSessionRepository) {
        self.repository = repository
    }

    func loadDevices() async {
        guard isLoadingDevices == false else { return }
        isLoadingDevices = true
        defer { isLoadingDevices = false }

        do {
            devices = try await repository.fetchDevices()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func loadDetails(deviceID: String) async {
        loadingDetailDeviceID = deviceID
        defer { loadingDetailDeviceID = nil }

        do {
            deviceDetails[deviceID] = try await repository.fetchDeviceDetails(deviceID: deviceID)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func removeDevice(deviceID: String) async {
        removingDeviceID = deviceID
        defer { removingDeviceID = nil }

        do {
            try await repository.removeDevice(deviceID: deviceID)
            devices.removeAll { $0.deviceID == deviceID }
            deviceDetails.removeValue(forKey: deviceID)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
