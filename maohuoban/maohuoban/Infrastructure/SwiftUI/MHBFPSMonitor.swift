import SwiftUI
import QuartzCore

// MHBFPSMonitor FPS 帧率悬浮监视器
// 核心职责：
// - 通过 CADisplayLink 采样屏幕刷新帧率
// - 在页面上悬浮显示当前 FPS，用于流式渲染性能验证
@MainActor
@Observable
final class MHBFPSMonitor {
    var fps: Double = 0
    var isVisible: Bool = false

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    func startMonitoring() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
    }

    func toggleVisibility() {
        if isVisible {
            isVisible = false
            stopMonitoring()
        } else {
            isVisible = true
            startMonitoring()
        }
    }

    @objc private nonisolated func displayLinkFired(_ link: CADisplayLink) {
        let timestamp = link.timestamp
        Task { @MainActor in
            if lastTimestamp == 0 {
                lastTimestamp = timestamp
                return
            }

            frameCount += 1
            let elapsed = timestamp - lastTimestamp

            if elapsed >= 0.5 {
                fps = Double(frameCount) / elapsed
                lastTimestamp = timestamp
                frameCount = 0
            }
        }
    }
}
