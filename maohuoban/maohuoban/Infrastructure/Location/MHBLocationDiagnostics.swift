import CoreLocation
import Foundation
import MaohuobanDiagnostics

// MHBLocationDiagnostics 位置诊断埋点
// 核心职责：
// - 记录定位权限、定位回调和地址解析链路
// - 为首页位置展示问题提供 SDK 观测事件
enum MHBLocationDiagnostics {
    static func refreshIfNeededSkipped(reason: String, snapshot: MHBLocationSnapshot?, isLocating: Bool) {
        record(
            "location.refresh_if_needed_skipped",
            metadata: [
                "reason": .string(reason),
                "has_snapshot": .bool(snapshot != nil),
                "display_name": optional(snapshot?.displayName),
                "is_locating": .bool(isLocating)
            ]
        )
    }

    static func refreshRequested(
        source: String,
        status: CLAuthorizationStatus,
        snapshot: MHBLocationSnapshot?,
        isLocating: Bool
    ) {
        record(
            "location.refresh_requested",
            metadata: [
                "source": .string(source),
                "authorization_status": .string(status.diagnosticName),
                "has_snapshot": .bool(snapshot != nil),
                "display_name": optional(snapshot?.displayName),
                "is_locating": .bool(isLocating)
            ]
        )
    }

    static func permissionRequestStarted(status: CLAuthorizationStatus) {
        record(
            "location.permission_request_started",
            metadata: ["authorization_status": .string(status.diagnosticName)]
        )
    }

    static func authorizationChanged(status: CLAuthorizationStatus) {
        record(
            "location.authorization_changed",
            metadata: ["authorization_status": .string(status.diagnosticName)]
        )
    }

    static func requestStarted(status: CLAuthorizationStatus) {
        record(
            "location.request_started",
            metadata: ["authorization_status": .string(status.diagnosticName)]
        )
    }

    static func locationUpdated(_ location: CLLocation, locationsCount: Int) {
        record(
            "location.did_update",
            metadata: [
                "locations_count": .int(locationsCount),
                "horizontal_accuracy": .double(location.horizontalAccuracy),
                "latitude_rounded": .double(roundedCoordinate(location.coordinate.latitude)),
                "longitude_rounded": .double(roundedCoordinate(location.coordinate.longitude))
            ]
        )
    }

    static func locationFailed(_ error: Error, status: CLAuthorizationStatus) {
        let nsError = error as NSError
        record(
            "location.request_failed",
            severity: .error,
            metadata: [
                "authorization_status": .string(status.diagnosticName),
                "error_domain": .string(nsError.domain),
                "error_code": .int(nsError.code),
                "error_description": .string(nsError.localizedDescription)
            ]
        )
    }

    static func geocodeStarted(_ location: CLLocation) {
        record(
            "location.geocode_started",
            metadata: [
                "horizontal_accuracy": .double(location.horizontalAccuracy),
                "latitude_rounded": .double(roundedCoordinate(location.coordinate.latitude)),
                "longitude_rounded": .double(roundedCoordinate(location.coordinate.longitude))
            ]
        )
    }

    static func geocodeRequestInvalid(_ location: CLLocation) {
        record(
            "location.geocode_request_invalid",
            severity: .warn,
            metadata: [
                "latitude_rounded": .double(roundedCoordinate(location.coordinate.latitude)),
                "longitude_rounded": .double(roundedCoordinate(location.coordinate.longitude))
            ]
        )
    }

    static func geocodeEmptyResult() {
        record("location.geocode_empty_result", severity: .warn)
    }

    static func geocodeSucceeded(
        mapItemsCount: Int,
        addressSummary: MHBLocationAddressDiagnosticSummary,
        snapshot: MHBLocationSnapshot
    ) {
        record(
            "location.geocode_succeeded",
            metadata: [
                "map_items_count": .int(mapItemsCount),
                "address_representations_present": .bool(addressSummary.hasAddressRepresentations),
                "address_prefix_kind": .string(addressSummary.prefixKind),
                "address_length": .int(addressSummary.fullAddressLength),
                "representation_city": optional(addressSummary.representationCity),
                "representation_region": optional(addressSummary.representationRegion),
                "country": optional(snapshot.country),
                "province": optional(snapshot.province),
                "city": optional(snapshot.city),
                "district": optional(snapshot.district),
                "display_name": optional(snapshot.displayName),
                "has_display_name": .bool(snapshot.displayName != nil)
            ]
        )
    }

    static func geocodeFailed(_ error: Error) {
        let nsError = error as NSError
        record(
            "location.geocode_failed",
            severity: .error,
            metadata: [
                "error_domain": .string(nsError.domain),
                "error_code": .int(nsError.code),
                "error_description": .string(nsError.localizedDescription)
            ]
        )
    }

    static func homeTaskStarted(currentUserID: String?) {
        record(
            "home.location_task_started",
            metadata: ["has_current_user": .bool(currentUserID != nil)]
        )
    }

    static func homeStoreLoaded(locationDisplayName: String?, backendTitle: String) {
        record(
            "home.location_store_loaded",
            metadata: [
                "location_display_name": optional(locationDisplayName),
                "backend_title": .string(backendTitle),
                "uses_device_location": .bool(locationDisplayName != nil)
            ]
        )
    }

    static func homeToolbarTapped(displayName: String?) {
        record(
            "home.location_toolbar_tapped",
            metadata: ["display_name": optional(displayName)]
        )
    }

    static func homeDisplayNameChanged(displayName: String?, backendTitle: String) {
        record(
            "home.location_display_name_changed",
            metadata: [
                "display_name": optional(displayName),
                "backend_title": .string(backendTitle),
                "uses_device_location": .bool(displayName != nil)
            ]
        )
    }

    private static func record(
        _ message: String,
        severity: DiagnosticSeverity = .info,
        metadata: DiagnosticProperties = [:]
    ) {
        var event = DiagnosticEvent(kind: .breadcrumb, severity: severity, message: message)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }

        Task {
            await recordAfterRuntimeAvailable(event)
        }
    }

    private static func recordAfterRuntimeAvailable(_ event: DiagnosticEvent) async {
        for attempt in 0..<3 {
            if await Diagnostics.current() != nil {
                await Diagnostics.record(event)
                return
            }

            guard attempt < 2 else {
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private static func optional(_ value: String?) -> DiagnosticValue {
        guard let value, value.isEmpty == false else {
            return .null
        }
        return .string(value)
    }

    private static func roundedCoordinate(_ value: CLLocationDegrees) -> Double {
        (value * 1_000).rounded() / 1_000
    }
}

// MHBLocationAddressDiagnosticSummary 地址解析诊断摘要
// 核心职责：
// - 保存反地理编码返回地址的非精确诊断字段
// - 避免在诊断事件中写入完整街道地址
struct MHBLocationAddressDiagnosticSummary: Sendable {
    let hasAddressRepresentations: Bool
    let prefixKind: String
    let fullAddressLength: Int
    let representationCity: String?
    let representationRegion: String?
}

private extension CLAuthorizationStatus {
    var diagnosticName: String {
        switch self {
        case .notDetermined:
            "not_determined"
        case .restricted:
            "restricted"
        case .denied:
            "denied"
        case .authorizedAlways:
            "authorized_always"
        case .authorizedWhenInUse:
            "authorized_when_in_use"
        @unknown default:
            "unknown"
        }
    }
}
