import XCTest

// MaohuobanAuthUITests 登录 UI 端到端测试
// 核心职责：
// - 验证验证码登录、退出登录、第三方 TODO toast
// - 验证忘记密码重置后可使用新密码登录
final class MaohuobanAuthUITests: XCTestCase {
    private let backendBaseURL = ProcessInfo.processInfo.environment["MHB_BACKEND_BASE_URL"] ?? "http://192.168.2.2:8080"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAuthFlowFromPhoneCodeToPasswordRecovery() throws {
        let app = launchResetApp()
        let phone = makeUniquePhone()
        let newPassword = "newpass123"

        sendPhoneCodeLogin(app: app, phone: phone)
        XCTAssertTrue(app.buttons["home.logoutButton"].waitForExistence(timeout: 10))

        app.buttons["home.logoutButton"].tap()
        XCTAssertTrue(app.textFields["auth.phoneInput"].waitForExistence(timeout: 8))

        app.buttons["auth.wechatButton"].tap()
        XCTAssertTrue(app.staticTexts["微信 登录暂未开放"].waitForExistence(timeout: 5))

        resetPasswordFromRecovery(app: app, phone: phone, password: newPassword)
        dismissPasswordSavePromptIfPresent(app: app)
        let passwordLoginButton = app.buttons["auth.passwordLoginButton"]
        XCTAssertTrue(waitUntilHittable(passwordLoginButton, timeout: 5), passwordLoginButton.debugDescription)
        passwordLoginButton.tap()
        XCTAssertTrue(app.buttons["home.logoutButton"].waitForExistence(timeout: 10))
    }

    // testPhoneCodeButtonRequiresElevenDigitPhone 验证验证码入口手机号门禁
    // 核心职责：
    // - 确认手机号不足 11 位时获取验证码按钮不可点击
    // - 确认手机号补齐 11 位后获取验证码按钮恢复可点击
    @MainActor
    func testPhoneCodeButtonRequiresElevenDigitPhone() throws {
        let app = launchResetApp()

        let phoneInput = app.textFields["auth.phoneInput"]
        XCTAssertTrue(phoneInput.waitForExistence(timeout: 8))
        let sendCodeButton = app.buttons["auth.sendCodeButton"]
        XCTAssertTrue(sendCodeButton.waitForExistence(timeout: 3))
        XCTAssertFalse(sendCodeButton.isEnabled)

        phoneInput.tap()
        phoneInput.typeText("13912345")
        XCTAssertFalse(sendCodeButton.isEnabled)

        phoneInput.typeText("678")
        XCTAssertTrue(sendCodeButton.isEnabled)
    }

    // testPasswordLoginButtonRequiresElevenDigitPhone 验证密码登录手机号门禁
    // 核心职责：
    // - 确认手机号不足 11 位时密码登录按钮不可点击
    // - 确认手机号补齐 11 位后密码登录按钮恢复可点击
    @MainActor
    func testPasswordLoginButtonRequiresElevenDigitPhone() throws {
        let app = launchResetApp()

        app.buttons["auth.modeSwitchButton"].tap()
        let phoneInput = app.textFields["auth.phoneInput"]
        XCTAssertTrue(phoneInput.waitForExistence(timeout: 8))
        let passwordInput = app.secureTextFields["auth.passwordInput"]
        XCTAssertTrue(passwordInput.waitForExistence(timeout: 3))
        let passwordLoginButton = app.buttons["auth.passwordLoginButton"]
        XCTAssertTrue(passwordLoginButton.waitForExistence(timeout: 3))

        phoneInput.tap()
        phoneInput.typeText("13912345")
        passwordInput.tap()
        passwordInput.typeText("newpass123")
        XCTAssertFalse(passwordLoginButton.isEnabled)

        phoneInput.tap()
        phoneInput.typeText("678")
        XCTAssertTrue(passwordLoginButton.isEnabled)
    }

    @MainActor
    private func launchResetApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-auth-state",
            "--skip-launch-screen"
        ]
        app.launchEnvironment["MHB_BACKEND_BASE_URL"] = backendBaseURL
        addUIInterruptionMonitor(withDescription: "本地网络权限") { alert in
            for title in ["允许", "Allow", "好", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launch()
        app.tap()
        return app
    }

    @MainActor
    private func sendPhoneCodeLogin(app: XCUIApplication, phone: String) {
        let phoneInput = app.textFields["auth.phoneInput"]
        XCTAssertTrue(phoneInput.waitForExistence(timeout: 8))
        phoneInput.tap()
        phoneInput.typeText(phone)

        app.buttons["auth.sendCodeButton"].tap()

        let codeBoxes = app.buttons["auth.verification.codeBoxes"]
        XCTAssertTrue(codeBoxes.waitForExistence(timeout: 8))
        let resendButton = app.buttons["auth.resendCodeButton"]
        XCTAssertTrue(resendButton.waitForExistence(timeout: 3))
        assertResendCountdownLabel(resendButton.label)
        codeBoxes.tap()
        app.typeText("123456")

        app.buttons["auth.verifyCodeButton"].tap()
    }

    @MainActor
    private func resetPasswordFromRecovery(app: XCUIApplication, phone: String, password: String) {
        app.buttons["auth.modeSwitchButton"].tap()
        XCTAssertTrue(app.buttons["auth.recoveryButton"].waitForExistence(timeout: 5))
        app.buttons["auth.recoveryButton"].tap()

        let recoveryPhoneInput = app.textFields["auth.recovery.phoneInput"]
        XCTAssertTrue(recoveryPhoneInput.waitForExistence(timeout: 5))
        if recoveryPhoneInput.value as? String != phone {
            recoveryPhoneInput.tap()
            recoveryPhoneInput.typeText(phone)
        }

        app.buttons["auth.recovery.sendCodeButton"].tap()

        let recoveryCodeInput = app.textFields["auth.recovery.codeInput"]
        XCTAssertTrue(recoveryCodeInput.waitForExistence(timeout: 8))
        recoveryCodeInput.tap()
        recoveryCodeInput.typeText("123456")

        let recoveryPasswordInput = app.secureTextFields["auth.recovery.passwordInput"]
        XCTAssertTrue(recoveryPasswordInput.waitForExistence(timeout: 5))
        recoveryPasswordInput.tap()
        recoveryPasswordInput.typeText(password)

        app.buttons["auth.recovery.resetPasswordButton"].tap()
        XCTAssertTrue(app.buttons["auth.passwordLoginButton"].waitForExistence(timeout: 8))
    }

    // dismissPasswordSavePromptIfPresent 关闭系统保存密码弹窗
    // 核心职责：
    // - 处理重置密码后 iOS 系统 Sheet 对登录按钮的遮挡
    // - 让端到端测试继续验证真实密码登录链路
    @MainActor
    private func dismissPasswordSavePromptIfPresent(app: XCUIApplication) {
        for title in ["以后", "Not Now", "稍后", "以后再说"] {
            let button = app.buttons[title]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                _ = waitUntilHidden(button, timeout: 3)
                return
            }
        }
    }

    // waitUntilHittable 等待元素进入可点击状态
    // 核心职责：
    // - 按可访问性命中状态轮询 UI 元素
    // - 避免系统弹窗退场动画造成点击丢失
    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.exists && element.isHittable
    }

    // waitUntilHidden 等待元素从可访问性树消失
    // 核心职责：
    // - 等待系统弹窗按钮退场完成
    // - 为后续点击提供稳定前置条件
    @MainActor
    private func waitUntilHidden(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return !element.exists
    }

    private func makeUniquePhone() -> String {
        let suffix = Int(Date().timeIntervalSince1970) % 100_000_000
        return "139" + String(format: "%08d", suffix)
    }

    // assertResendCountdownLabel 校验验证码重发倒计时
    // 核心职责：
    // - 允许端到端测试启动耗时造成的秒数流逝
    // - 固定用户可见的倒计时文案格式
    private func assertResendCountdownLabel(_ label: String) {
        let prefix = "重新发送 "
        let suffix = "s"
        XCTAssertTrue(label.hasPrefix(prefix), label)
        XCTAssertTrue(label.hasSuffix(suffix), label)
        let secondsText = label.dropFirst(prefix.count).dropLast(suffix.count)
        let seconds = Int(secondsText)
        XCTAssertNotNil(seconds, label)
        XCTAssertTrue((1...60).contains(seconds ?? 0), label)
    }
}
