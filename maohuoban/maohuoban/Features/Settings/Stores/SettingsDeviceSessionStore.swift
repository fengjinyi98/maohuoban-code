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
    private(set) var toastMessage: String?

    @ObservationIgnored private let repository: any SettingsDeviceSessionRepository

    init(repository: any SettingsDeviceSessionRepository) {
        self.repository = repository
    }

    func loadDevices() async {
        guard isLoadingDevices == false else { return }
        isLoadingDevices = true
        defer { isLoadingDevices = false }

        do {
            let response = try await repository.fetchDevices()
            devices = response.data?.devices ?? []
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.toastMessage
        }
    }

    func loadDetails(sessionID: String) async {
        loadingDetailDeviceID = sessionID
        defer { loadingDetailDeviceID = nil }

        do {
            let response = try await repository.fetchDeviceDetails(sessionID: sessionID)
            if let details = response.data {
                deviceDetails[sessionID] = details
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.toastMessage
        }
    }

    func removeDevice(sessionID: String) async {
        removingDeviceID = sessionID
        toastMessage = nil
        defer { removingDeviceID = nil }

        do {
            let response = try await repository.removeDevice(sessionID: sessionID)
            devices.removeAll { $0.sessionID == sessionID }
            deviceDetails.removeValue(forKey: sessionID)
            lastErrorMessage = nil
            toastMessage = response.message
        } catch {
            lastErrorMessage = error.toastMessage
            toastMessage = error.toastMessage
        }
    }
}
