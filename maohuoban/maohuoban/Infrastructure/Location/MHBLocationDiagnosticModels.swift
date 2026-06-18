import CoreLocation

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

extension CLAuthorizationStatus {
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
