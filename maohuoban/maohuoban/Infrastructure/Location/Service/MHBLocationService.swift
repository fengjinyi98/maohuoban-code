import CoreLocation
import Foundation
import Observation

// MHBLocationService 设备定位服务
// 核心职责：
// - 管理 CoreLocation 权限请求和一次性定位
// - 保存可复用的结构化位置快照
@MainActor
@Observable
final class MHBLocationService: NSObject, @unchecked Sendable {
    @ObservationIgnored
    let locationManager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var snapshot: MHBLocationSnapshot?
    var isLocating = false
    var errorMessage: String?

    var displayName: String? {
        snapshot?.displayName
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }

    func refreshIfNeeded() {
        guard snapshot == nil else {
            MHBLocationDiagnostics.refreshIfNeededSkipped(
                reason: "snapshot_exists",
                snapshot: snapshot,
                isLocating: isLocating
            )
            return
        }
        guard !isLocating else {
            MHBLocationDiagnostics.refreshIfNeededSkipped(
                reason: "already_locating",
                snapshot: snapshot,
                isLocating: isLocating
            )
            return
        }
        refresh()
    }

    func refresh() {
        authorizationStatus = locationManager.authorizationStatus
        MHBLocationDiagnostics.refreshRequested(
            source: "service_refresh",
            status: authorizationStatus,
            snapshot: snapshot,
            isLocating: isLocating
        )

        switch authorizationStatus {
        case .notDetermined:
            errorMessage = nil
            MHBLocationDiagnostics.permissionRequestStarted(status: authorizationStatus)
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationRequest()
        case .denied, .restricted:
            isLocating = false
            errorMessage = "位置权限未开启"
        @unknown default:
            isLocating = false
            errorMessage = "无法获取位置权限状态"
        }
    }

    func startLocationRequest() {
        isLocating = true
        errorMessage = nil
        MHBLocationDiagnostics.requestStarted(status: authorizationStatus)
        locationManager.requestLocation()
    }
}
