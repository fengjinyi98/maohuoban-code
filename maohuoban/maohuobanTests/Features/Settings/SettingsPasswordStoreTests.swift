import Foundation
import XCTest
@testable import maohuoban

// SettingsPasswordStoreTests 登录密码状态测试
// 核心职责：
// - 固化设置密码页面到后端仓储的单向数据流
// - 验证成功后写回 CurrentUserStore 作为唯一账号安全状态源
@MainActor
final class SettingsPasswordStoreTests: XCTestCase {
    func testFirstSetPasswordUpdatesCurrentUserStoreFromSecurityResponse() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(hasPassword: false))
        let repository = SettingsPasswordRepositoryStub(
            setResponse: MHBAPIResponse(
                success: true,
                code: "account.password_set",
                message: "登录密码已设置",
                data: Self.securityState(hasPassword: true)
            )
        )
        let store = SettingsPasswordStore(
            repository: repository,
            currentUserStore: currentUserStore
        )
        store.newPassword = "Newpass123"
        store.confirmPassword = "Newpass123"

        await store.submit()

        XCTAssertTrue(store.didComplete)
        XCTAssertEqual(store.toastMessage, "登录密码已设置")
        XCTAssertEqual(repository.lastSetRequest?.newPassword, "Newpass123")
        XCTAssertTrue(currentUserStore.hasPassword)
        XCTAssertEqual(currentUserStore.settingsState.passwordStatusText, "已设置")
    }

    func testPasswordModeDerivesFromCurrentUserStoreAfterExternalSecurityUpdate() {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(hasPassword: false))
        let store = SettingsPasswordStore(
            repository: SettingsPasswordRepositoryStub(),
            currentUserStore: currentUserStore
        )

        currentUserStore.applyAccountSecurity(
            phoneMasked: "138****8016",
            hasPassword: true
        )

        XCTAssertEqual(store.passwordStatusText, "已设置")
        XCTAssertTrue(store.requiresCurrentPassword)
        XCTAssertTrue(store.requiresSMSCode)
        XCTAssertFalse(store.isSendCodeDisabled)
    }

    func testChangePasswordRequiresCodeChallengeAndUpdatesCurrentUserStore() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(hasPassword: true))
        let repository = SettingsPasswordRepositoryStub(
            codeResponse: MHBAPIResponse(
                success: true,
                code: "account.password_change_code_sent",
                message: "验证码已发送",
                data: PhoneCodeChallenge(
                    challengeID: "challenge-1",
                    expiresInSeconds: 300,
                    resendAfterSeconds: 60
                )
            ),
            changeResponse: MHBAPIResponse(
                success: true,
                code: "account.password_changed",
                message: "登录密码已修改",
                data: Self.securityState(hasPassword: true)
            )
        )
        let store = SettingsPasswordStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        await store.sendResetCode()
        store.currentPassword = "Oldpass123"
        store.smsCode = "123456"
        store.newPassword = "Newpass123"
        store.confirmPassword = "Newpass123"
        await store.submit()

        XCTAssertEqual(store.toastMessage, "登录密码已修改")
        XCTAssertEqual(repository.lastChangeRequest?.currentPassword, "Oldpass123")
        XCTAssertEqual(repository.lastChangeRequest?.challengeID, "challenge-1")
        XCTAssertEqual(repository.lastChangeRequest?.code, "123456")
        XCTAssertTrue(currentUserStore.hasPassword)
    }

    func testChangePasswordValidationRequiresSmsCodeWhenPasswordAlreadySet() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(hasPassword: true))
        let repository = SettingsPasswordRepositoryStub()
        let store = SettingsPasswordStore(
            repository: repository,
            currentUserStore: currentUserStore
        )
        store.currentPassword = "Oldpass123"
        store.newPassword = "Newpass123"
        store.confirmPassword = "Newpass123"

        await store.submit()

        XCTAssertFalse(store.didComplete)
        XCTAssertEqual(store.errorMessage, "请先获取并输入短信验证码")
        XCTAssertNil(repository.lastChangeRequest)
    }

    private static func authSession(hasPassword: Bool) -> AuthSession {
        AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 900,
            refreshExpiresInSeconds: 15_552_000,
            user: AuthUser(
                id: "user-1",
                phone: "13800138016",
                phoneMasked: "138****8016",
                hasPassword: hasPassword,
                profile: nil
            )
        )
    }

    fileprivate static func securityState(hasPassword: Bool) -> SettingsAccountSecurityState {
        SettingsAccountSecurityState(
            phoneMasked: "138****8016",
            hasPassword: hasPassword,
            passwordStatusText: hasPassword ? "已设置" : "未设置",
            passwordUpdatedAt: nil,
            wechatBound: false,
            appleBound: false,
            realNameStatus: "unverified",
            officialVerificationStatus: "unverified"
        )
    }
}

// SettingsPasswordRepositoryStub 登录密码仓储测试桩
// 核心职责：
// - 用固定响应驱动 SettingsPasswordStore 分支
// - 记录最后一次提交参数供测试断言
@MainActor
private final class SettingsPasswordRepositoryStub: SettingsPasswordRepository {
    var lastSetRequest: SettingsSetPasswordRequest?
    var lastChangeRequest: SettingsChangePasswordRequest?
    private let securityResponse: MHBAPIResponse<SettingsAccountSecurityState>
    private let setResponse: MHBAPIResponse<SettingsAccountSecurityState>
    private let codeResponse: MHBAPIResponse<PhoneCodeChallenge>
    private let changeResponse: MHBAPIResponse<SettingsAccountSecurityState>

    init(
        securityResponse: MHBAPIResponse<SettingsAccountSecurityState>? = nil,
        setResponse: MHBAPIResponse<SettingsAccountSecurityState>? = nil,
        codeResponse: MHBAPIResponse<PhoneCodeChallenge>? = nil,
        changeResponse: MHBAPIResponse<SettingsAccountSecurityState>? = nil
    ) {
        self.securityResponse = securityResponse ?? MHBAPIResponse(
            success: true,
            code: "account.security_loaded",
            message: "账号安全信息已加载",
            data: SettingsPasswordStoreTests.securityState(hasPassword: false)
        )
        self.setResponse = setResponse ?? MHBAPIResponse(
            success: true,
            code: "account.password_set",
            message: "登录密码已设置",
            data: SettingsPasswordStoreTests.securityState(hasPassword: true)
        )
        self.codeResponse = codeResponse ?? MHBAPIResponse(
            success: true,
            code: "account.password_change_code_sent",
            message: "验证码已发送",
            data: PhoneCodeChallenge(
                challengeID: "challenge-1",
                expiresInSeconds: 300,
                resendAfterSeconds: 60
            )
        )
        self.changeResponse = changeResponse ?? MHBAPIResponse(
            success: true,
            code: "account.password_changed",
            message: "登录密码已修改",
            data: SettingsPasswordStoreTests.securityState(hasPassword: true)
        )
    }

    func loadSecurity() async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState> {
        securityResponse
    }

    func setInitialPassword(
        newPassword: String,
        confirmPassword: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState> {
        lastSetRequest = SettingsSetPasswordRequest(
            newPassword: newPassword,
            confirmPassword: confirmPassword
        )
        return setResponse
    }

    func sendPasswordChangeCode() async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge> {
        codeResponse
    }

    func changePassword(
        currentPassword: String,
        challengeID: String,
        code: String,
        newPassword: String,
        confirmPassword: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState> {
        lastChangeRequest = SettingsChangePasswordRequest(
            currentPassword: currentPassword,
            challengeID: challengeID,
            code: code,
            newPassword: newPassword,
            confirmPassword: confirmPassword
        )
        return changeResponse
    }
}
