import Foundation

extension DefaultPetRepository {
    func listFoodInventoryItems(
        currentUserID: String
    ) async throws(MHBAPIError) -> [FoodInventoryItem] {
        let response: MHBAPIResponse<FoodInventoryListData> = try await client.get(
            path: "/api/v1/food-inventory/items",
            headers: try userHeaders(currentUserID: currentUserID)
        )
        return response.data?.items ?? []
    }

    func loadFoodInventoryItemDetail(
        itemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItemDetail {
        let response: MHBAPIResponse<FoodInventoryItemDetail> = try await client.get(
            path: "/api/v1/food-inventory/items/\(itemID)/detail",
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let detail = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "物品详情加载失败", statusCode: 500)
        }
        return detail
    }

    func loadPetCurrentDietContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetCurrentDietContext {
        let response: MHBAPIResponse<PetCurrentDietContext> = try await client.get(
            path: "/api/v1/pets/\(petID)/diet-context",
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let context = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "饮食配置加载失败", statusCode: 500)
        }
        return context
    }

    func setPetCurrentStaple(
        petID: String,
        foodItemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetDietAssignment {
        let body = PetCurrentStapleRequest(
            food_item_id: foodItemID,
            reason: "用户设置当前主粮"
        )
        let response: MHBAPIResponse<PetDietAssignment> = try await client.post(
            path: "/api/v1/pets/\(petID)/diet/staple",
            body: body,
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let assignment = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "当前主粮设置失败", statusCode: 500)
        }
        return assignment
    }

    func setPetFoodAssignment(
        petID: String,
        foodItemID: String,
        role: PetDietAssignmentRole,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetDietAssignment {
        let body = PetFoodAssignmentRequest(
            food_item_id: foodItemID,
            role: role,
            reason: "用户设置饮食配置"
        )
        let response: MHBAPIResponse<PetDietAssignment> = try await client.post(
            path: "/api/v1/pets/\(petID)/diet/assignments",
            body: body,
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let assignment = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "饮食配置设置失败", statusCode: 500)
        }
        return assignment
    }

    func createFoodInventoryItem(
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        let body = FoodInventoryCreateRequest(
            name: draft.name,
            brand: draft.brand.isEmpty ? nil : draft.brand,
            category: draft.category.rawValue,
            inventory_status: draft.initialStatus.rawValue,
            quantity: draft.quantity,
            unit: draft.unit.isEmpty ? nil : draft.unit,
            spec: draft.spec.isEmpty ? nil : draft.spec,
            expiry_date: draft.expiryDate.isEmpty ? nil : draft.expiryDate,
            cover_asset_id: draft.coverAssetID,
            note: draft.note.isEmpty ? nil : draft.note
        )
        let response: MHBAPIResponse<FoodInventoryItem> = try await client.post(
            path: "/api/v1/food-inventory/items",
            body: body,
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let item = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "创建失败", statusCode: 500)
        }
        return item
    }

    func updateFoodInventoryItem(
        itemID: String,
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        let body = FoodInventoryUpdateRequest(
            name: draft.name.isEmpty ? nil : draft.name,
            brand: draft.brand.isEmpty ? nil : draft.brand,
            category: draft.category.rawValue,
            inventory_status: draft.initialStatus.rawValue,
            quantity: draft.quantity > 0 ? draft.quantity : nil,
            unit: draft.unit.isEmpty ? nil : draft.unit,
            spec: draft.spec.isEmpty ? nil : draft.spec,
            expiry_date: draft.expiryDate.isEmpty ? nil : draft.expiryDate,
            cover_asset_id: draft.coverAssetID,
            note: draft.note.isEmpty ? nil : draft.note
        )
        let response: MHBAPIResponse<FoodInventoryItem> = try await client.patch(
            path: "/api/v1/food-inventory/items/\(itemID)",
            body: body,
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let item = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "编辑失败", statusCode: 500)
        }
        return item
    }

    func updateFoodInventoryStatus(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        let body = FoodInventoryUpdateRequest(
            name: nil,
            brand: nil,
            category: nil,
            inventory_status: status.rawValue,
            quantity: nil,
            unit: nil,
            spec: nil,
            expiry_date: nil,
            cover_asset_id: nil,
            note: nil
        )
        let response: MHBAPIResponse<FoodInventoryItem> = try await client.patch(
            path: "/api/v1/food-inventory/items/\(itemID)",
            body: body,
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let item = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "状态更新失败", statusCode: 500)
        }
        return item
    }

    func uploadFoodInventoryCover(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await uploadPendingMedia(
            path: "/api/v1/food-inventory/media",
            draft: draft,
            currentUserID: currentUserID,
            onUploadProgress: onUploadProgress
        )
    }

    func deleteFoodInventoryItem(
        itemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        let response: MHBAPIResponse<FoodInventoryItem> = try await client.delete(
            path: "/api/v1/food-inventory/items/\(itemID)",
            body: FoodInventoryDeleteRequest(reason: "用户移出储物柜"),
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let item = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "移出失败", statusCode: 500)
        }
        return item
    }

    func restockFoodInventoryItem(
        itemID: String,
        quantity: Int,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        let request = FoodInventoryRestockRequest(quantity_delta: quantity)
        let response: MHBAPIResponse<FoodInventoryItem> = try await client.post(
            path: "/api/v1/food-inventory/items/\(itemID)/restock",
            body: request,
            headers: try userHeaders(currentUserID: currentUserID)
        )
        guard let item = response.data else {
            throw MHBAPIError.business(code: "pet.no_data", message: "补库存失败", statusCode: 500)
        }
        return item
    }
}
