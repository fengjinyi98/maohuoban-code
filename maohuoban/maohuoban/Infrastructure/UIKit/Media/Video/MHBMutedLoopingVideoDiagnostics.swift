import AVFoundation

extension AVPlayerItem.Status {
    nonisolated var diagnosticsText: String {
        switch self {
        case .unknown:
            "unknown"
        case .readyToPlay:
            "ready_to_play"
        case .failed:
            "failed"
        @unknown default:
            "unknown_default"
        }
    }
}
