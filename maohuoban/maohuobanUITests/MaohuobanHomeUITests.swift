import XCTest

// MaohuobanHomeUITests 首页 UI 契约测试
// 核心职责：
// - 通过真实验证码登录进入首页
// - 验证无宠物新用户首页空态存在
final class MaohuobanHomeUITests: XCTestCase {
    private let backendBaseURL = ProcessInfo.processInfo.environment["MHB_BACKEND_BASE_URL"] ?? "http://127.0.0.1:18080"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // testNewUserHomeShowsCreatePetEmptyState 验证新用户首页空态
    // 核心职责：
    // - 确认登录成功后首页读取当前用户上下文
    // - 确认无宠物用户展示创建宠物主操作
    @MainActor
    func testNewUserHomeShowsCreatePetEmptyState() throws {
        let app = launchResetApp()
        sendPhoneCodeLogin(app: app, phone: makeUniquePhone())

        XCTAssertTrue(app.otherElements["home.dashboard"].waitForExistence(timeout: 10))
        XCTAssertEqual(waitForKeyboardDismissal(in: app), .completed)
        XCTAssertTrue(app.staticTexts["为第一只毛孩子建立主页"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.emptyState.primaryAction"].exists)
        XCTAssertTrue(app.buttons["home.quickAction.create_pet"].exists)
    }

    @MainActor
    private func launchResetApp() -> XCUIApplication {
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
        let suffix = Int.random(in: 0..<100_000_000)
        return "137" + String(format: "%08d", suffix)
    }

    @MainActor
    private func waitForKeyboardDismissal(in app: XCUIApplication) -> XCTWaiter.Result {
        let keyboard = app.keyboards.element
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: keyboard
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3)
    }
}
