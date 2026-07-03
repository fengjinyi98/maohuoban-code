import Foundation

extension DefaultPetRepository {
    func listWeightRecords(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecordList> {
        try await client.get(
            path: "/api/v1/pets/\(petID)/weight-records",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func createWeightRecord(
        petID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        try await client.post(
            path: "/api/v1/pets/\(petID)/weight-records",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func loadWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        try await client.get(
            path: "/api/v1/pet-weight-records/\(recordID)",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func updateWeightRecord(
        recordID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        try await client.patch(
            path: "/api/v1/pet-weight-records/\(recordID)",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func deleteWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetWeightRecord> {
        try await client.delete(
            path: "/api/v1/pet-weight-records/\(recordID)",
            body: MHBEmptyRequest(),
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }
}
