import Foundation

extension DefaultPetRepository {
    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        try await client.post(
            path: "/api/v1/pets/\(petID)/events",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        try await client.get(
            path: "/api/v1/pet-events/\(eventID)",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func loadTimeline(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetTimeline> {
        try await client.get(
            path: "/api/v1/pets/\(petID)/timeline",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func deleteEvent(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetEvent> {
        try await client.delete(
            path: "/api/v1/pet-events/\(eventID)",
            body: MHBEmptyRequest(),
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        try await client.post(
            path: "/api/v1/pets/imports/trade",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }
}
