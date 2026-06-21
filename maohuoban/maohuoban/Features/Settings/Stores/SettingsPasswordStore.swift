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
// - 在后端未接入时提供本地 mock 提交结果
@MainActor
@Observable
final class SettingsPasswordStore {
    var selectedMode: SettingsPasswordMode
    var currentPassword = ""
    var smsCode = ""
    var newPassword = ""
    var confirmPassword = ""
    private(set) var countdownRemaining = 0
    private(set) var isSubmitting = false
    private(set) var didComplete = false
    private(set) var errorMessage: String?

    private let hasPassword: Bool
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    init(hasPassword: Bool = false) {
        self.hasPassword = hasPassword
        self.selectedMode = hasPassword ? .currentPassword : .firstSet
    }

    deinit {
        countdownTask?.cancel()
    }

    var passwordStatusText: String {
        hasPassword ? "已设置" : "未设置"
    }

    var showsModeTabs: Bool {
        hasPassword
    }

    var sendCodeButtonTitle: String {
        countdownRemaining > 0 ? "\(countdownRemaining)s后重发" : "获取验证码"
    }

    var isSendCodeDisabled: Bool {
        countdownRemaining > 0
    }

    func switchMode(to mode: SettingsPasswordMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
        currentPassword = ""
        smsCode = ""
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
    }

    func sendResetCode() {
        guard selectedMode == .smsCode, isSendCodeDisabled == false else { return }
        countdownTask?.cancel()
        countdownRemaining = 60
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while countdownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard Task.isCancelled == false else { return }
                countdownRemaining -= 1
            }
        }
    }

    func submit() async {
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        try? await Task.sleep(for: .milliseconds(180))
        didComplete = true
        errorMessage = nil
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

        switch selectedMode {
        case .firstSet:
            return true
        case .currentPassword:
            guard currentPassword.isEmpty == false else {
                errorMessage = "请输入当前登录密码"
                return false
            }
            return true
        case .smsCode:
            guard smsCode.isEmpty == false else {
                errorMessage = "请输入短信验证码"
                return false
            }
            return true
        }
    }

    private func isPasswordStrongEnough(_ password: String) -> Bool {
        guard (8 ... 20).contains(password.count) else { return false }
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbol = password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil
        return [hasLetter, hasNumber, hasSymbol].filter { $0 }.count >= 2
    }
}
