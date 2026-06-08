// DiagnosticsRuntimeSpan 运行时性能 span API
// 核心职责：
// - 创建与当前运行时绑定的性能 span
// - 让业务流程用显式生命周期记录耗时
extension DiagnosticsRuntime {
    public func beginSpan(_ name: String) -> DiagnosticsSpan {
        DiagnosticsSpan(name: name, runtime: self)
    }
}
