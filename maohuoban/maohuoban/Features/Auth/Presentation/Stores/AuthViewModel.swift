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
    var maskedPhone: String = ""
    var hasRecoveryChallenge = false
    var resendCountdownSeconds = 0

    var isAuthenticated: Bool {
        currentUserStore.isAuthenticated
    }

    var resendButtonTitle: String {
        resendCountdownSeconds > 0 ? "重新发送 \(resendCountdownSeconds)s" : "重新发送"
    }

    var canResendCode: Bool {
        resendCountdownSeconds == 0 && !isSubmitting
    }

    var isLoginPhoneValid: Bool {
        validatePhone(phone)
    }

    var loginChallengeID: String?
    var recoveryChallengeID: String?
    var resendCountdownTask: Task<Void, Never>?
    let repository: AuthRepository
    let tokenStore: MHBTokenStore
    let toast: MHBToastPresenter
    let currentUserStore: CurrentUserStore

    init(
        repository: AuthRepository = DefaultAuthRepository(),
        tokenStore: MHBTokenStore = MHBKeychainTokenStore(),
        toast: MHBToastPresenter = MHBToastPresenter(),
        currentUserStore: CurrentUserStore
    ) {
        self.repository = repository
        self.tokenStore = tokenStore
        self.toast = toast
        self.currentUserStore = currentUserStore
    }

    func bootstrapSession() async {
        guard let tokens = try? tokenStore.loadTokens() else { return }
        do {
            let response = try await repository.refresh(refreshToken: tokens.refreshToken)
            guard let session = response.data else { return }
            try tokenStore.saveTokens(session.storedTokens)
            applyAuthenticatedSession(session)
        } catch let error as MHBAPIError {
            if shouldClearStoredTokens(afterRefreshError: error) {
                resetLocalSession()
            }
        } catch {
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
            applyAuthenticatedSession(session)
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
            applyAuthenticatedSession(session)
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
                applyAuthenticatedSession(session)
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

    func handleAuthenticationInvalidated(message: String) {
        guard isAuthenticated else { return }
        resetLocalSession()
        toast.danger(message)
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
}
