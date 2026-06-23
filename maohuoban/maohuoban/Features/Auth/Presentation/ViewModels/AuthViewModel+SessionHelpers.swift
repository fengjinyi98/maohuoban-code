import Foundation

extension AuthViewModel {
    // applyAuthenticatedSession 应用认证成功会话
    // 核心职责：
    // - 同步 AuthViewModel 登录态
    // - 将用户资料写入当前用户单一 Store
    func applyAuthenticatedSession(_ session: AuthSession) {
        currentUserStore.apply(session: session)
        isAuthenticated = true
    }

    // shouldClearStoredTokens 判断 refresh 失败后的本地凭证处理
    // 核心职责：
    // - 服务端明确判定 refresh 失效时清理本地凭证
    // - 网络中断或后端重启期间保留 refresh token 以便恢复
    func shouldClearStoredTokens(afterRefreshError error: MHBAPIError) -> Bool {
        switch error {
        case .business(let code, _, let statusCode):
            return statusCode == 401 && ["auth.refresh_invalid", "auth.refresh_reused"].contains(code)
        case .invalidResponse, .transport, .decoding:
            return false
        }
    }

    // submit 统一提交状态包装
    // 核心职责：
    // - 防止登录相关请求重复提交
    // - 将 API 错误转换为用户可见 toast
    func submit(_ operation: () async throws -> Void) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await operation()
        } catch let error as MHBAPIError {
            toast.danger(error.toastMessage)
        } catch {
            toast.danger("登录状态保存失败，请稍后再试")
        }
    }

    // resetLocalSession 清理本地登录态
    // 核心职责：
    // - 删除本地 token 并重置当前用户
    // - 停止验证码倒计时并回到登录入口
    func resetLocalSession() {
        try? tokenStore.clearTokens()
        currentUserStore.clear()
        isAuthenticated = false
        step = .login
        stopResendCountdown()
    }

    // startResendCountdown 启动验证码重发倒计时
    // 核心职责：
    // - 按服务端返回秒数驱动重发按钮状态
    // - 倒计时结束后自动释放任务
    func startResendCountdown(seconds: Int) {
        resendCountdownTask?.cancel()
        resendCountdownSeconds = max(seconds, 0)
        guard resendCountdownSeconds > 0 else {
            resendCountdownTask = nil
            return
        }

        resendCountdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.resendCountdownSeconds = max(self.resendCountdownSeconds - 1, 0)
                    if self.resendCountdownSeconds == 0 {
                        self.resendCountdownTask?.cancel()
                        self.resendCountdownTask = nil
                    }
                }
            }
        }
    }

    // stopResendCountdown 停止验证码重发倒计时
    // 核心职责：
    // - 取消当前倒计时任务
    // - 重置按钮可点击状态
    func stopResendCountdown() {
        resendCountdownTask?.cancel()
        resendCountdownTask = nil
        resendCountdownSeconds = 0
    }

    func validatePhone(_ value: String) -> Bool {
        value.count == 11 && value.allSatisfy(\.isNumber)
    }

    func maskPhone(_ value: String) -> String {
        guard value.count == 11 else { return value }
        let prefix = value.prefix(3)
        let suffix = value.suffix(4)
        return "+86 \(prefix) **** \(suffix)"
    }
}
