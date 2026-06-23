import Foundation
import Observation

// SettingsPasswordMode 设置密码模式
// 核心职责：
// - 描述首次设置、旧密码修改和短信重置三种入口
// - 为设置密码页提供可测试的分段状态
enum SettingsPasswordMode: String, CaseIterable, Identifiable, Equatable {
    case firstSet
    case currentPassword
    case smsCode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSet: "设置登录密码"
        case .currentPassword: "旧密码修改"
        case .smsCode: "短信验证码"
        }
    }
}

// SettingsPasswordStore 设置密码状态源
// 核心职责：
// - 管理设置密码页面表单状态与基础校验
// - 调用后端账号安全接口并写回 CurrentUserStore
@MainActor
@Observable
final class SettingsPasswordStore {
    var selectedMode: SettingsPasswordMode
    var currentPassword = ""
    var smsCode = ""
    var newPassword = ""
    var confirmPassword = ""
    private(set) var countdownRemaining = 0
    private(set) var isSendingCode = false
    private(set) var isSubmitting = false
    private(set) var didComplete = false
    private(set) var errorMessage: String?
    private(set) var toastMessage: String?
    private(set) var passwordChangeChallengeID: String?

    @ObservationIgnored private let repository: any SettingsPasswordRepository
    @ObservationIgnored private let currentUserStore: CurrentUserStore
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    init(
        repository: any SettingsPasswordRepository = DefaultSettingsPasswordRepository(),
        currentUserStore: CurrentUserStore
    ) {
        self.repository = repository
        self.currentUserStore = currentUserStore
        self.selectedMode = currentUserStore.hasPassword ? .currentPassword : .firstSet
    }

    deinit {
        countdownTask?.cancel()
    }

    var passwordStatusText: String {
        currentHasPassword ? "已设置" : "未设置"
    }

    var showsModeTabs: Bool {
        false
    }

    var sendCodeButtonTitle: String {
        if isSendingCode {
            return "发送中..."
        }
        return countdownRemaining > 0 ? "\(countdownRemaining)s后重发" : "获取验证码"
    }

    var isSendCodeDisabled: Bool {
        currentHasPassword == false || isSendingCode || countdownRemaining > 0
    }

    var requiresCurrentPassword: Bool {
        currentHasPassword
    }

    private var currentHasPassword: Bool {
        currentUserStore.hasPassword
    }

    var requiresSMSCode: Bool {
        currentHasPassword
    }

    func switchMode(to mode: SettingsPasswordMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
        currentPassword = ""
        smsCode = ""
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
        toastMessage = nil
        passwordChangeChallengeID = nil
    }

    func sendResetCode() async {
        guard isSendCodeDisabled == false else { return }
        isSendingCode = true
        errorMessage = nil
        toastMessage = nil
        passwordChangeChallengeID = nil
        defer { isSendingCode = false }

        do {
            let response = try await repository.sendPasswordChangeCode()
            passwordChangeChallengeID = response.data?.challengeID
            toastMessage = response.message
            startCountdown(seconds: response.data?.resendAfterSeconds ?? 60)
        } catch {
            errorMessage = error.toastMessage
            toastMessage = error.toastMessage
        }
    }

    func submit() async {
        didComplete = false
        toastMessage = nil
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if currentHasPassword {
                guard let challengeID = passwordChangeChallengeID, challengeID.isEmpty == false else {
                    errorMessage = "请先获取并输入短信验证码"
                    return
                }
                let response = try await repository.changePassword(
                    currentPassword: currentPassword,
                    challengeID: challengeID,
                    code: smsCode,
                    newPassword: newPassword,
                    confirmPassword: confirmPassword
                )
                applySecurityResponse(response, fallbackHasPassword: true)
            } else {
                let response = try await repository.setInitialPassword(
                    newPassword: newPassword,
                    confirmPassword: confirmPassword
                )
                applySecurityResponse(response, fallbackHasPassword: true)
            }

            didComplete = true
            errorMessage = nil
        } catch {
            errorMessage = error.toastMessage
            toastMessage = error.toastMessage
        }
    }

    private func startCountdown(seconds: Int) {
        countdownTask?.cancel()
        countdownRemaining = seconds
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while countdownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard Task.isCancelled == false else { return }
                countdownRemaining -= 1
            }
        }
    }

    private func validate() -> Bool {
        guard newPassword.isEmpty == false, confirmPassword.isEmpty == false else {
            errorMessage = "请填写完整的新密码信息"
            return false
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return false
        }
        guard isPasswordStrongEnough(newPassword) else {
            errorMessage = "密码需为 8-20 位，且至少满足两种字符类型"
            return false
        }

        if currentHasPassword {
            guard currentPassword.isEmpty == false else {
                errorMessage = "请输入当前登录密码"
                return false
            }
            guard smsCode.isEmpty == false else {
                errorMessage = "请先获取并输入短信验证码"
                return false
            }
        }

        return true
    }

    private func applySecurityResponse(
        _ response: MHBAPIResponse<SettingsAccountSecurityState>,
        fallbackHasPassword: Bool
    ) {
        let securityState = response.data
        currentUserStore.applyAccountSecurity(
            phoneMasked: securityState?.phoneMasked,
            hasPassword: securityState?.hasPassword ?? fallbackHasPassword
        )
        selectedMode = currentHasPassword ? .currentPassword : .firstSet
        toastMessage = response.message
    }

    private func isPasswordStrongEnough(_ password: String) -> Bool {
        guard (8 ... 20).contains(password.count) else { return false }
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbol = password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil
        return [hasLetter, hasNumber, hasSymbol].filter { $0 }.count >= 2
    }
}
