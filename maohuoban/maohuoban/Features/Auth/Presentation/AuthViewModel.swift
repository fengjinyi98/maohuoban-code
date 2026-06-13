import Foundation
import Observation

// AuthViewModel 登录流程状态模型
// 核心职责：
// - 管理登录、验证码、账号恢复页面状态
// - 通过 Repository、TokenStore、ToastPresenter 完成单向数据流更新
@MainActor
@Observable
final class AuthViewModel {
    var step: AuthStep = .login
    var mode: AuthMode = .phoneCode
    var phone: String = ""
    var password: String = ""
    var code: String = ""
    var recoveryPhone: String = ""
    var recoveryCode: String = ""
    var recoveryPassword: String = ""
    var isAgreementAccepted = true
    var isSubmitting = false
    var isAuthenticated = false
    var currentUser: AuthUser?
    var maskedPhone: String = ""
    var hasRecoveryChallenge = false
    var resendCountdownSeconds = 0

    var resendButtonTitle: String {
        resendCountdownSeconds > 0 ? "重新发送 \(resendCountdownSeconds)s" : "重新发送"
    }

    var canResendCode: Bool {
        resendCountdownSeconds == 0 && !isSubmitting
    }

    var isLoginPhoneValid: Bool {
        validatePhone(phone)
    }

    private var loginChallengeID: String?
    private var recoveryChallengeID: String?
    private var resendCountdownTask: Task<Void, Never>?
    private let repository: AuthRepository
    private let tokenStore: MHBTokenStore
    private let toast: MHBToastPresenter

    init(
        repository: AuthRepository = DefaultAuthRepository(),
        tokenStore: MHBTokenStore = MHBKeychainTokenStore(),
        toast: MHBToastPresenter = MHBToastPresenter()
    ) {
        self.repository = repository
        self.tokenStore = tokenStore
        self.toast = toast
    }

    func bootstrapSession() async {
        guard let tokens = try? tokenStore.loadTokens() else { return }
        do {
            let response = try await repository.refresh(refreshToken: tokens.refreshToken)
            guard let session = response.data else { return }
            try tokenStore.saveTokens(session.storedTokens)
            currentUser = session.user
            isAuthenticated = true
        } catch {
            try? tokenStore.clearTokens()
        }
    }

    func toggleMode() {
        mode = mode == .phoneCode ? .password : .phoneCode
        password = ""
    }

    func sendPhoneCode() async {
        guard validatePhone(phone) else {
            toast.warning("请输入正确的手机号")
            return
        }
        guard isAgreementAccepted else {
            toast.warning("请先同意用户协议和隐私政策")
            return
        }
        guard resendCountdownSeconds == 0 else {
            toast.warning("请 \(resendCountdownSeconds) 秒后重新获取验证码")
            return
        }

        await submit {
            let response = try await repository.sendPhoneCode(
                phone: phone,
                agreementAccepted: isAgreementAccepted
            )
            guard let challenge = response.data else { throw MHBAPIError.invalidResponse }
            loginChallengeID = challenge.challengeID
            maskedPhone = maskPhone(phone)
            code = ""
            step = .verification
            startResendCountdown(seconds: challenge.resendAfterSeconds)
            toast.success(response.message)
        }
    }

    func passwordLogin() async {
        guard validatePhone(phone) else {
            toast.warning("请输入正确的手机号")
            return
        }
        guard !password.isEmpty else {
            toast.warning("请输入密码")
            return
        }

        await submit {
            let response = try await repository.passwordLogin(phone: phone, password: password)
            guard let session = response.data else { throw MHBAPIError.invalidResponse }
            try tokenStore.saveTokens(session.storedTokens)
            currentUser = session.user
            isAuthenticated = true
            toast.success(response.message)
        }
    }

    func verifyCode() async {
        guard let loginChallengeID else {
            toast.warning("请重新获取验证码")
            return
        }
        guard code.count == 6 else {
            toast.warning("请输入 6 位验证码")
            return
        }

        await submit {
            let response = try await repository.verifyPhoneCode(
                challengeID: loginChallengeID,
                code: code
            )
            guard let session = response.data else { throw MHBAPIError.invalidResponse }
            try tokenStore.saveTokens(session.storedTokens)
            currentUser = session.user
            isAuthenticated = true
            toast.success(response.message)
        }
    }

    func sendRecoveryCode() async {
        guard validatePhone(recoveryPhone) else {
            toast.warning("请输入正确的手机号")
            return
        }

        await submit {
            let response = try await repository.sendRecoveryCode(phone: recoveryPhone)
            guard let challenge = response.data else { throw MHBAPIError.invalidResponse }
            recoveryChallengeID = challenge.challengeID
            hasRecoveryChallenge = true
            recoveryCode = ""
            recoveryPassword = ""
            toast.success(response.message)
        }
    }

    func resetPassword() async {
        guard let recoveryChallengeID else {
            toast.warning("请先获取验证码")
            return
        }
        guard recoveryCode.count == 6 else {
            toast.warning("请输入 6 位验证码")
            return
        }
        guard recoveryPassword.count >= 6 else {
            toast.warning("密码至少需要 6 位")
            return
        }

        await submit {
            let response = try await repository.resetPassword(
                challengeID: recoveryChallengeID,
                code: recoveryCode,
                newPassword: recoveryPassword
            )
            toast.success(response.message)
            phone = recoveryPhone
            password = recoveryPassword
            mode = .password
            step = .login
            hasRecoveryChallenge = false
        }
    }

    func oauth(provider: String) async {
        await submit {
            let response = try await repository.oauth(provider: provider)
            if let session = response.data {
                try tokenStore.saveTokens(session.storedTokens)
                currentUser = session.user
                isAuthenticated = true
                toast.success(response.message)
            }
        }
    }

    func logout() async {
        guard let tokens = try? tokenStore.loadTokens() else {
            resetLocalSession()
            return
        }
        do {
            let response = try await repository.logout(refreshToken: tokens.refreshToken)
            toast.success(response.message)
        } catch {
            toast.warning(error.toastMessage)
        }
        resetLocalSession()
    }

    func backToLogin() {
        step = .login
        recoveryCode = ""
        recoveryPassword = ""
        stopResendCountdown()
    }

    func showRecovery() {
        recoveryPhone = phone
        recoveryCode = ""
        recoveryPassword = ""
        hasRecoveryChallenge = false
        step = .recovery
    }

    private func submit(_ operation: () async throws -> Void) async {
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

    private func resetLocalSession() {
        try? tokenStore.clearTokens()
        currentUser = nil
        isAuthenticated = false
        step = .login
        stopResendCountdown()
    }

    private func startResendCountdown(seconds: Int) {
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

    private func stopResendCountdown() {
        resendCountdownTask?.cancel()
        resendCountdownTask = nil
        resendCountdownSeconds = 0
    }

    private func validatePhone(_ value: String) -> Bool {
        value.count == 11 && value.allSatisfy(\.isNumber)
    }

    private func maskPhone(_ value: String) -> String {
        guard value.count == 11 else { return value }
        let prefix = value.prefix(3)
        let suffix = value.suffix(4)
        return "+86 \(prefix) **** \(suffix)"
    }
}
