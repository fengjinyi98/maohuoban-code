import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("track 会记录结构化产品埋点属性")
    func trackRecordsStructuredAnalyticsProperties() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        let accepted = await diagnostics.track(
            "checkout.started",
            properties: [
                "screen": "checkout",
                "amount": 129,
                "discount": 12.5,
                "is_trial": false,
                "items": ["sku-1", "sku-2"],
                "coupon": [
                    "code": "WELCOME",
                    "valid": true
                ]
            ]
        )

        let events = try await diagnostics.readEvents()
        let event = try #require(events.first {
            $0.kind == .analytics && $0.message == "checkout.started"
        })
        #expect(accepted)
        #expect(event.metadata["event_type"] == "track")
        #expect(event.metadata["screen"] == "checkout")
        #expect(event.metadata["amount"] == 129)
        #expect(event.metadata["discount"] == 12.5)
        #expect(event.metadata["is_trial"] == false)
        #expect(event.metadata["items"] == .array(["sku-1", "sku-2"]))
        #expect(event.metadata["coupon"] == .object(["code": "WELCOME", "valid": true]))
    }

    @Test("identify 和用户属性会注入后续埋点并可清除")
    func identifyAndUserPropertiesApplyToFutureEventsAndCanBeCleared() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        await diagnostics.identify(
            userID: "user-123",
            traits: [
                "plan": "pro",
                "age": 29
            ]
        )
        await diagnostics.setUserProperty("locale", "zh-CN")
        await diagnostics.track("home.opened")
        await diagnostics.clearUser()
        await diagnostics.track("home.closed")

        let events = try await diagnostics.readEvents()
        let identify = try #require(events.first { $0.kind == .identity && $0.message == "identify" })
        let opened = try #require(events.first { $0.message == "home.opened" })
        let closed = try #require(events.first { $0.message == "home.closed" })

        #expect(identify.metadata["user_id"] == "user-123")
        #expect(identify.metadata["plan"] == "pro")
        #expect(identify.metadata["age"] == 29)
        #expect(opened.metadata["user_id"] == "user-123")
        #expect(opened.metadata["user.plan"] == "pro")
        #expect(opened.metadata["user.locale"] == "zh-CN")
        #expect(closed.metadata["user_id"] == nil)
        #expect(closed.metadata["user.plan"] == nil)
        #expect(closed.metadata["user.locale"] == nil)
    }

    @Test("track 会拒绝不符合命名规范的事件")
    func trackRejectsInvalidEventNames() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        let accepted = await diagnostics.track("Checkout Started")

        let events = try await diagnostics.readEvents()
        #expect(!accepted)
        #expect(!events.contains { $0.kind == .analytics && $0.message == "Checkout Started" })
        #expect(events.contains {
            $0.kind == .error
                && $0.severity == .warn
                && $0.message == "analytics event rejected"
                && $0.metadata["event_name"] == "Checkout Started"
        })
    }

    @Test("全局网络采集注册具备幂等状态和卸载边界")
    func globalNetworkCaptureRegistrationIsIdempotentAndCanBeUninstalled() async throws {
        let root = try temporaryDirectory()

        _ = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("first"),
                networkCapture: .globalURLProtocol
            )
        )
        _ = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("second"),
                networkCapture: .globalURLProtocol
            )
        )

        #expect(await Diagnostics.isGlobalNetworkCaptureRegistered)
        await Diagnostics.uninstall()
        #expect(!(await Diagnostics.isGlobalNetworkCaptureRegistered))
        #expect(await Diagnostics.current() == nil)
    }
}
