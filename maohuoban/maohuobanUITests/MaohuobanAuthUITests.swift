import XCTest

// MaohuobanAuthUITests 登录 UI 端到端测试
// 核心职责：
// - 验证验证码登录、退出登录、第三方 TODO toast
// - 验证忘记密码重置后可使用新密码登录
final class MaohuobanAuthUITests: XCTestCase {
    let backendBaseURL = ProcessInfo.processInfo.environment["MHB_BACKEND_BASE_URL"] ?? "http://192.168.2.2:8080"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAuthFlowFromPhoneCodeToPasswordRecovery() throws {
        let app = launchResetApp()
        let phone = makeUniquePhone()
        let newPassword = "newpass123"

        sendPhoneCodeLogin(app: app, phone: phone)
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 10))
        assertKeyboardDismissed(app: app)

        logoutFromProfile(app: app)
        XCTAssertTrue(app.textFields["auth.phoneInput"].waitForExistence(timeout: 8))

        app.buttons["auth.wechatButton"].tap()
        XCTAssertTrue(app.staticTexts["微信 登录暂未开放"].waitForExistence(timeout: 5))

        resetPasswordFromRecovery(app: app, phone: phone, password: newPassword)
        dismissPasswordSavePromptIfPresent(app: app)
        let passwordLoginButton = app.buttons["auth.passwordLoginButton"]
        XCTAssertTrue(waitUntilHittable(passwordLoginButton, timeout: 5), passwordLoginButton.debugDescription)
        passwordLoginButton.tap()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 10))
        assertKeyboardDismissed(app: app)
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

    // testAgreementLinksOpenLegalDocuments 验证登录页协议文档入口
    // 核心职责：
    // - 确认用户协议和隐私政策以可点击入口出现
    // - 确认点击入口后打开后端托管的文档页
    // - 验证法务正文下拉和上滑后仍保持稳定展示
    @MainActor
    func testAgreementLinksOpenLegalDocuments() throws {
        let app = launchResetApp()

        let userAgreementLink = app.buttons["auth.userAgreementLink"]
        XCTAssertTrue(userAgreementLink.waitForExistence(timeout: 8))
        userAgreementLink.tap()
        XCTAssertTrue(app.staticTexts["用户服务协议"].waitForExistence(timeout: 8))
        let agreementDocument = app.textViews["legal.documentTextView"]
        XCTAssertTrue(agreementDocument.waitForExistence(timeout: 8))
        agreementDocument.swipeDown()
        XCTAssertTrue(agreementDocument.exists)
        agreementDocument.swipeUp()
        XCTAssertTrue(agreementDocument.exists)
        app.buttons["BackButton"].tap()

        let privacyPolicyLink = app.buttons["auth.privacyPolicyLink"]
        XCTAssertTrue(privacyPolicyLink.waitForExistence(timeout: 8))
        privacyPolicyLink.tap()
        XCTAssertTrue(app.staticTexts["用户隐私政策"].waitForExistence(timeout: 8))
        let privacyDocument = app.textViews["legal.documentTextView"]
        XCTAssertTrue(privacyDocument.waitForExistence(timeout: 8))
        privacyDocument.swipeDown()
        XCTAssertTrue(privacyDocument.exists)
        privacyDocument.swipeUp()
        XCTAssertTrue(privacyDocument.exists)
    }

}
