// DiagnosticsCaptureState 动态采集状态
// 核心职责：
// - 保存运行时可更新的采集策略
// - 串行化授权、启用和采样配置读取写入
actor DiagnosticsCaptureState {
    private var policy: CapturePolicy

    init(policy: CapturePolicy) {
        self.policy = policy
    }

    func apply(to event: DiagnosticEvent) -> DiagnosticEvent? {
        policy.apply(to: event)
    }

    func setTrackingConsent(_ consent: DiagnosticsTrackingConsent) {
        policy.consent = consent
    }

    func setCaptureEnabled(_ enabled: Bool) {
        policy.enabled = enabled
    }

    func setSampleRate(_ sampleRate: Double) {
        policy.sampleRate = sampleRate
    }
}
