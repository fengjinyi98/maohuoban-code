import Foundation
import Observation

// PetWeightRecordStore 体重记录状态容器
// 核心职责：
// - 通过 PetRepository 加载和写入体重记录
// - 为体重页面提供单一数据源和展示摘要
@MainActor
@Observable
final class PetWeightRecordStore {
    private let petID: String
    private let currentUserID: String
    private let repository: PetRepository

    private(set) var records: [PetWeightRecord]
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded = false

    init(
        petID: String,
        currentUserID: String,
        repository: PetRepository = DefaultPetRepository(),
        records: [PetWeightRecord] = []
    ) {
        self.petID = petID
        self.currentUserID = currentUserID
        self.repository = repository
        self.records = Self.sorted(records)
    }

    var isEmpty: Bool {
        records.isEmpty
    }

    var shouldShowEmptyState: Bool {
        hasLoaded && records.isEmpty && errorMessage == nil
    }

    var shouldShowErrorState: Bool {
        errorMessage != nil && records.isEmpty
    }

    var shouldShowBottomCTA: Bool {
        !shouldShowEmptyState && !shouldShowErrorState
    }

    var emptyStateTitle: String {
        "还没有体重记录"
    }

    var emptyStateMessage: String {
        "记录第一次称重后，就能看到毛伙伴的体重变化。"
    }

    var emptyStateButtonTitle: String {
        "添加体重记录"
    }

    var currentWeightText: String {
        records.first?.weightText ?? "--"
    }

    var weightChangeText: String {
        guard records.count >= 2 else { return "暂无变化" }
        let deltaGrams = records[0].weightGrams - records[1].weightGrams
        guard deltaGrams != 0 else { return "持平" }
        let sign = deltaGrams > 0 ? "+" : "-"
        return "\(sign) \(String(format: "%.2f", abs(Double(deltaGrams)) / 1000)) kg"
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.listWeightRecords(
                petID: petID,
                currentUserID: currentUserID
            )
            records = Self.sorted(response.data?.items ?? [])
            hasLoaded = true
        } catch {
            errorMessage = error.toastMessage
        }
    }

    func create(draft: PetWeightRecordDraft) async -> Bool {
        await mutate { () async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> in
            try await repository.createWeightRecord(
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
        }
    }

    func update(recordID: String, draft: PetWeightRecordDraft) async -> Bool {
        await mutate { () async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> in
            try await repository.updateWeightRecord(
                recordID: recordID,
                draft: draft,
                currentUserID: currentUserID
            )
        }
    }

    func delete(recordID: String) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            let response = try await repository.deleteWeightRecord(
                recordID: recordID,
                currentUserID: currentUserID
            )
            guard response.data?.deleted == true else { return false }
            records.removeAll { $0.id == recordID }
            return true
        } catch {
            errorMessage = error.toastMessage
            return false
        }
    }

    func record(id: String) -> PetWeightRecord? {
        records.first { $0.id == id }
    }

    private func mutate(
        operation: () async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord>
    ) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            guard let record = try await operation().data else { return false }
            upsert(record)
            return true
        } catch {
            errorMessage = error.toastMessage
            return false
        }
    }

    private func upsert(_ record: PetWeightRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        records = Self.sorted(records)
    }

    private static func sorted(_ records: [PetWeightRecord]) -> [PetWeightRecord] {
        records.sorted { lhs, rhs in
            lhs.occurredAt > rhs.occurredAt
        }
    }
}
