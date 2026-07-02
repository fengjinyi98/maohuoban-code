import Foundation
import MaohuobanDiagnostics

extension DefaultPetRepository {
    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        await recordPetDraftPrepared(
            eventName: "pet.create_request_prepared",
            draftBreed: draft.breed,
            currentUserID: currentUserID,
            metadata: [
                "has_avatar_asset": .bool(draft.avatarAssetID != nil),
                "has_background_asset": .bool(draft.backgroundAssetID != nil)
            ]
        )
        do {
            let result = try await Diagnostics.instrumentRepositoryCall(
                name: "pet.profile.create",
                repository: "DefaultPetRepository",
                source: .network,
                metadata: [
                    "resource": .string("pet_profile"),
                    "user_id_prefix": .string(diagnosticsPrefix(currentUserID))
                ]
            ) {
                let response: MHBAPIResponse<PetProfileSummary> = try await client.post(
                    path: "/api/v1/pets",
                    body: draft,
                    headers: try userHeaders(currentUserID: currentUserID)
                )
                return DiagnosticsRepositoryResult(
                    value: response,
                    itemCount: response.data == nil ? 0 : 1,
                    apiCode: response.code,
                    hasData: response.data != nil
                )
            }
            let response = result.value
            await recordPetProfileResponse(
                eventName: "pet.create_response_received",
                response: response,
                currentUserID: currentUserID
            )
            return response
        } catch let error as MHBAPIError {
            await recordPetFailure(
                eventName: "pet.create_request_failed",
                error: error,
                currentUserID: currentUserID
            )
            throw error
        } catch {
            let apiError = MHBAPIError.transport(error.localizedDescription)
            await recordPetFailure(
                eventName: "pet.create_request_failed",
                error: apiError,
                currentUserID: currentUserID
            )
            throw apiError
        }
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        await recordPetDraftPrepared(
            eventName: "pet.update_request_prepared",
            draftBreed: draft.breed,
            currentUserID: currentUserID,
            metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
        )
        do {
            let result = try await Diagnostics.instrumentRepositoryCall(
                name: "pet.profile.update",
                repository: "DefaultPetRepository",
                source: .network,
                metadata: [
                    "resource": .string("pet_profile"),
                    "pet_id_prefix": .string(diagnosticsPrefix(petID)),
                    "user_id_prefix": .string(diagnosticsPrefix(currentUserID))
                ]
            ) {
                let response: MHBAPIResponse<PetProfileSummary> = try await client.patch(
                    path: "/api/v1/pets/\(petID)",
                    body: draft,
                    headers: try userHeaders(currentUserID: currentUserID)
                )
                return DiagnosticsRepositoryResult(
                    value: response,
                    itemCount: response.data == nil ? 0 : 1,
                    apiCode: response.code,
                    hasData: response.data != nil
                )
            }
            let response = result.value
            await recordPetProfileResponse(
                eventName: "pet.update_response_received",
                response: response,
                currentUserID: currentUserID,
                metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
            )
            return response
        } catch let error as MHBAPIError {
            await recordPetFailure(
                eventName: "pet.update_request_failed",
                error: error,
                currentUserID: currentUserID,
                metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
            )
            throw error
        } catch {
            let apiError = MHBAPIError.transport(error.localizedDescription)
            await recordPetFailure(
                eventName: "pet.update_request_failed",
                error: apiError,
                currentUserID: currentUserID,
                metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
            )
            throw apiError
        }
    }

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        try await client.delete(
            path: "/api/v1/pets/\(petID)",
            body: DeletePetProfileDraft(reason: reason),
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    // Phase 1 占位：后端 endpoint 就绪后接入 GET /api/v1/pets/{pet_id}/identity-context
    func loadIdentityContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetIdentityContext> {
        try await client.get(
            path: "/api/v1/pets/\(petID)/identity-context",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }
}
