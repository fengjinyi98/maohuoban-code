import XCTest

// MaohuobanHomeUITests 首页 UI 契约测试
// 核心职责：
// - 通过真实验证码登录进入首页
// - 验证普通用户首页首屏核心模块存在
final class MaohuobanHomeUITests: XCTestCase {
    private let backendBaseURL = ProcessInfo.processInfo.environment["MHB_BACKEND_BASE_URL"] ?? "http://192.168.2.2:8080"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // testPetOwnerHomeShowsDashboardSections 验证普通用户首页模块
    // 核心职责：
    // - 确认登录成功后首页展示宠物主体卡
    // - 确认今日照护、快捷动作、今日伙伴和最近时间线可被访问
    @MainActor
    func testPetOwnerHomeShowsDashboardSections() throws {
        let app = launchResetApp()
        sendPhoneCodeLogin(app: app, phone: makeUniquePhone())

        XCTAssertTrue(app.otherElements["home.dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["home.petHeroCard"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["糯米"].exists)
        XCTAssertTrue(app.otherElements["home.careSummarySection"].exists)
        XCTAssertTrue(app.otherElements["home.quickActionsSection"].exists)
        XCTAssertTrue(app.otherElements["home.partnerSection"].exists)
        XCTAssertTrue(app.otherElements["home.timelineSection"].exists)
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
        codeBoxes.tap()
        app.typeText("123456")

        app.buttons["auth.verifyCodeButton"].tap()
    }

    private func makeUniquePhone() -> String {
        let suffix = Int(Date().timeIntervalSince1970) % 100_000_000
        return "137" + String(format: "%08d", suffix)
    }
}
