import Foundation
import UIKit

// AuthRepository 认证数据仓库协议
// 核心职责：
// - 定义 ViewModel 所需认证 API
// - 隔离 HTTP DTO 与展示层状态
protocol AuthRepository {
    func sendPhoneCode(phone: String, agreementAccepted: Bool) async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge>
    func verifyPhoneCode(challengeID: String, code: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession>
    func passwordLogin(phone: String, password: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession>
    func refresh(refreshToken: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession>
    func logout(refreshToken: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse>
    func sendRecoveryCode(phone: String) async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge>
    func resetPassword(challengeID: String, code: String, newPassword: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse>
    func oauth(provider: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession>
}

// DefaultAuthRepository 默认认证数据仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 后端认证接口
// - 统一补齐设备会话信息
struct DefaultAuthRepository: AuthRepository {
    private let client: MHBHTTPClient
    private let deviceIDStore: MHBDeviceIDStore

    init(
        client: MHBHTTPClient = MHBHTTPClient(),
        deviceIDStore: MHBDeviceIDStore = MHBDeviceIDStore()
    ) {
        self.client = client
        self.deviceIDStore = deviceIDStore
    }

    func sendPhoneCode(phone: String, agreementAccepted: Bool) async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge> {
        try await client.post(
            path: "/api/v1/auth/phone/code",
            body: SendPhoneCodeRequest(
                phone: phone,
                agreementAccepted: agreementAccepted,
                device: devicePayload()
            )
        )
    }

    func verifyPhoneCode(challengeID: String, code: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        try await client.post(
            path: "/api/v1/auth/phone/verify",
            body: VerifyPhoneCodeRequest(
                challengeID: challengeID,
                code: code,
                device: devicePayload()
            )
        )
    }

    func passwordLogin(phone: String, password: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        try await client.post(
            path: "/api/v1/auth/password/login",
            body: PasswordLoginRequest(phone: phone, password: password, device: devicePayload())
        )
    }

    func refresh(refreshToken: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        try await client.post(
            path: "/api/v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: refreshToken, deviceID: deviceIDStore.currentDeviceID())
        )
    }

    func logout(refreshToken: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse> {
        try await client.post(
            path: "/api/v1/auth/logout",
            body: LogoutRequest(refreshToken: refreshToken, deviceID: deviceIDStore.currentDeviceID())
        )
    }

    func sendRecoveryCode(phone: String) async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge> {
        try await client.post(
            path: "/api/v1/account-recovery/code",
            body: SendRecoveryCodeRequest(phone: phone, device: devicePayload())
        )
    }

    func resetPassword(challengeID: String, code: String, newPassword: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse> {
        try await client.post(
            path: "/api/v1/account-recovery/reset-password",
            body: ResetPasswordRequest(
                challengeID: challengeID,
                code: code,
                newPassword: newPassword
            )
        )
    }

    func oauth(provider: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        try await client.post(
            path: "/api/v1/auth/oauth/\(provider)",
            body: OAuthLoginRequest(identityToken: "todo-token", nonce: "todo-nonce")
        )
    }

    private func devicePayload() -> AuthDevicePayload {
        AuthDevicePayload(
            deviceID: deviceIDStore.currentDeviceID(),
            deviceName: UIDevice.current.name,
            platform: "iOS",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        )
    }
}
