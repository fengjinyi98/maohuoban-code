import CoreLocation
import Foundation
import Observation

// PetWalkTrackingStore 遛弯记录状态容器
// 核心职责：
// - 管理定位权限和连续定位更新
// - 驱动遛弯会话的开始、暂停、继续和结束
@MainActor
@Observable
final class PetWalkTrackingStore: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    @ObservationIgnored
    private let locationManager = CLLocationManager()

    @ObservationIgnored
    private var isStartPendingAfterAuthorization = false

    @ObservationIgnored
    private var referenceLocation: CLLocation?

    private(set) var recorder = PetWalkRouteRecorder()
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var errorMessage: String?
    private(set) var isLocationUpdating = false

    var phase: PetWalkSessionPhase {
        recorder.phase
    }

    var points: [PetWalkRoutePoint] {
        recorder.points
    }

    var canStartTracking: Bool {
        authorizationStatus != .denied && authorizationStatus != .restricted
    }

    var gpsStatusText: String {
        if let errorMessage {
            return errorMessage
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return isLocationUpdating ? "GPS 信号强" : "定位待启动"
        case .notDetermined:
            return "等待授权"
        case .denied, .restricted:
            return "位置权限未开启"
        @unknown default:
            return "定位状态未知"
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        authorizationStatus = locationManager.authorizationStatus
    }

    func start() {
        errorMessage = nil
        authorizationStatus = locationManager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            isStartPendingAfterAuthorization = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isStartPendingAfterAuthorization = false
            recorder.start()
            startLocationUpdates()
        case .denied, .restricted:
            isStartPendingAfterAuthorization = false
            errorMessage = "位置权限未开启"
        @unknown default:
            isStartPendingAfterAuthorization = false
            errorMessage = "无法获取位置权限状态"
        }
    }

    func pause() {
        recorder.pause()
        stopLocationUpdates()
    }

    func resume() {
        recorder.resume()
        startLocationUpdates()
    }

    func finish() {
        isStartPendingAfterAuthorization = false
        recorder.finish()
        stopLocationUpdates()
    }

    func displayMetrics(at date: Date = Date()) -> PetWalkMetrics {
        recorder.metrics(at: date)
    }

    func updateReferenceLocation(_ location: CLLocation) {
        referenceLocation = location
    }

    private func startLocationUpdates() {
        guard isLocationUpdating == false else { return }
        isLocationUpdating = true
        locationManager.startUpdatingLocation()
    }

    private func stopLocationUpdates() {
        guard isLocationUpdating else { return }
        isLocationUpdating = false
        locationManager.stopUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                guard self.isStartPendingAfterAuthorization else { return }
                self.isStartPendingAfterAuthorization = false
                if self.recorder.phase == .ready {
                    self.recorder.start()
                }
                if self.recorder.phase == .tracking {
                    self.startLocationUpdates()
                }
            case .denied, .restricted:
                self.isStartPendingAfterAuthorization = false
                self.errorMessage = "位置权限未开启"
                self.stopLocationUpdates()
            case .notDetermined:
                break
            @unknown default:
                self.isStartPendingAfterAuthorization = false
                self.errorMessage = "无法获取位置权限状态"
                self.stopLocationUpdates()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            if let referenceLocation {
                let distanceFromReference = location.distance(from: referenceLocation)
                if distanceFromReference > 80 {
                    return
                }
            }

            let point = PetWalkRoutePoint(
                coordinate: location.coordinate,
                horizontalAccuracy: location.horizontalAccuracy,
                timestamp: location.timestamp
            )
            self.recorder.append(point)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.errorMessage = "获取位置失败"
            self.stopLocationUpdates()
        }
    }
}
