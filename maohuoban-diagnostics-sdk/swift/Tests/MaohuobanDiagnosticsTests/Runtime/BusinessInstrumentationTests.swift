import Foundation
import Testing
import Darwin
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("Store command instrumentation 会记录开始、成功和状态转换")
    func storeCommandInstrumentationRecordsLifecycleEvents() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban-ios",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        let result = try await Diagnostics.instrumentStoreCommand(
            name: "pet.profile.save",
            store: "PetWriteStore",
            command: "save_profile",
            metadata: ["screen_name": .string("pet_profile_edit")]
        ) {
            "saved"
        }
        await Diagnostics.recordStoreStateTransition(
            store: "PetWriteStore",
            command: "save_profile",
            fromState: "editing",
            toState: "saving",
            result: "started"
        )

        #expect(result == "saved")
        let events = try await diagnostics.readEvents()
        #expect(events.contains { $0.message == "pet.profile.save.started" })
        #expect(events.contains { $0.message == "pet.profile.save.succeeded" })
        let transition = try #require(events.first { $0.message == "store.state.changed" })
        #expect(transition.metadata["store"] == "PetWriteStore")
        #expect(transition.metadata["from_state"] == "editing")
        #expect(transition.metadata["to_state"] == "saving")
    }

    @Test("Repository instrumentation 会记录 source、数据条数和耗时")
    func repositoryInstrumentationRecordsResponseSummary() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban-ios",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        let value = try await Diagnostics.instrumentRepositoryCall(
            name: "pet.profile.fetch",
            repository: "DefaultPetRepository",
            source: .network,
            metadata: ["resource": .string("pet_profile")]
        ) {
            DiagnosticsRepositoryResult(value: ["pet-a", "pet-b"], itemCount: 2, apiCode: "pet.ok")
        }

        #expect(value.value == ["pet-a", "pet-b"])
        let events = try await diagnostics.readEvents()
        let succeeded = try #require(events.first { $0.message == "pet.profile.fetch.succeeded" })
        #expect(succeeded.metadata["repository"] == "DefaultPetRepository")
        #expect(succeeded.metadata["source"] == "network")
        #expect(succeeded.metadata["item_count"] == "2")
        #expect(succeeded.metadata["api_code"] == "pet.ok")
        #expect(Int(succeeded.metadata["duration_ms"]?.stringValue ?? "") != nil)
    }

    @Test("Repository instrumentation 不把 operation 切到 MainActor")
    func repositoryInstrumentationKeepsDetachedOperationOffMainActor() async throws {
        let root = try temporaryDirectory()
        _ = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban-ios",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        let result = try await Task.detached {
            try await Diagnostics.instrumentRepositoryCall(
                name: "pet.profile.detached",
                repository: "DefaultPetRepository",
                source: .network
            ) {
                DiagnosticsRepositoryResult(value: pthread_main_np() == 1)
            }
        }.value

        #expect(result.value == false)
    }

    @Test("表单和页面性能 helper 只记录边界信息")
    func formAndScreenHelpersRecordBoundaryOnlyMetadata() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban-ios",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        await Diagnostics.recordFormFieldBlurred(
            form: "pet_profile",
            field: "note",
            screenName: "pet_profile_edit",
            valueLength: 42,
            valid: true
        )
        await Diagnostics.recordFormValidationFailed(
            form: "pet_profile",
            field: "name",
            screenName: "pet_profile_edit",
            rule: "required",
            errorKind: "validation"
        )
        await Diagnostics.recordScreenReady(
            screenName: "pet_profile_edit",
            dataReadyMs: 120,
            interactiveMs: 180,
            visibleItemCount: 6
        )

        let events = try await diagnostics.readEvents()
        let blur = try #require(events.first { $0.message == "form.field.blurred" })
        #expect(blur.metadata["length_bucket"] == "long")
        #expect(blur.metadata["value"] == nil)
        let ready = try #require(events.first { $0.message == "screen.performance.ready" })
        #expect(ready.metadata["screen_name"] == "pet_profile_edit")
        #expect(ready.metadata["screen_data_ready_ms"] == "120")
        #expect(ready.metadata["screen_interactive_ms"] == "180")
        #expect(ready.metadata["visible_item_count"] == "6")
    }
}
