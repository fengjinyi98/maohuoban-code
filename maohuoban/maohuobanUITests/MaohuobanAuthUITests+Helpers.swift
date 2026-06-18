import XCTest

extension MaohuobanAuthUITests {
    @MainActor
    func launchResetApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-auth-state",
            "--skip-launch-screen",
            "-MHB_BACKEND_BASE_URL",
            backendBaseURL
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
    func sendPhoneCodeLogin(app: XCUIApplication, phone: String) {
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
    func resetPasswordFromRecovery(app: XCUIApplication, phone: String, password: String) {
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

    // logoutFromProfile 从"我的"Tab 触发退出登录
    // 核心职责：
    // - 定位系统 TabBar 中的"我的"入口
    // - 触发 Profile 页面登出按钮，验证真实登出链路
    @MainActor
    func logoutFromProfile(app: XCUIApplication) {
        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()

        let logoutButton = app.buttons["profile.logoutButton"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 5))
        logoutButton.tap()
    }

    // dismissPasswordSavePromptIfPresent 关闭系统保存密码弹窗
    // 核心职责：
    // - 处理重置密码后 iOS 系统 Sheet 对登录按钮的遮挡
    // - 让端到端测试继续验证真实密码登录链路
    @MainActor
    func dismissPasswordSavePromptIfPresent(app: XCUIApplication) {
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
    func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
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
    func waitUntilHidden(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return !element.exists
    }

    // assertKeyboardDismissed 校验登录态切换后的键盘状态
    // 核心职责：
    // - 等待系统软键盘从可访问性树移除
    // - 防止认证流程输入焦点泄漏到 App 主壳
    @MainActor
    func assertKeyboardDismissed(app: XCUIApplication) {
        XCTAssertTrue(waitUntilHidden(app.keyboards.firstMatch, timeout: 3), app.keyboards.debugDescription)
    }

    func makeUniquePhone() -> String {
        let suffix = Int(Date().timeIntervalSince1970) % 100_000_000
        return "139" + String(format: "%08d", suffix)
    }

    // assertResendCountdownLabel 校验验证码重发倒计时
    // 核心职责：
    // - 允许端到端测试启动耗时造成的秒数流逝
    // - 固定用户可见的倒计时文案格式
    func assertResendCountdownLabel(_ label: String) {
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
