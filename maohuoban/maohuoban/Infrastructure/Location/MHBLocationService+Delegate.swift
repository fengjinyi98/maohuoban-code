import CoreLocation

// MHBLocationService+Delegate 定位代理
// 核心职责：
// - 响应定位权限变化
// - 接收一次性定位结果并触发地址解析
extension MHBLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            MHBLocationDiagnostics.authorizationChanged(status: status)

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.snapshot == nil, self.isLocating == false {
                    self.startLocationRequest()
                }
            case .denied, .restricted:
                self.isLocating = false
                self.errorMessage = "位置权限未开启"
            case .notDetermined:
                break
            @unknown default:
                self.isLocating = false
                self.errorMessage = "无法获取位置权限状态"
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            MHBLocationDiagnostics.locationUpdated(location, locationsCount: locations.count)
            await self.reverseGeocode(location: location)
            self.isLocating = false
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.isLocating = false
            self.errorMessage = "获取位置失败: \(error.localizedDescription)"
            MHBLocationDiagnostics.locationFailed(error, status: self.authorizationStatus)
        }
    }
}
