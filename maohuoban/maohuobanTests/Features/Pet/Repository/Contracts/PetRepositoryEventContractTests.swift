import Foundation
import XCTest
@testable import maohuoban

// PetRepositoryEventContractTests 宠物事件仓库契约测试
// 核心职责：
// - 验证宠物事件创建请求契约
// - 验证宠物事件详情加载响应解码
// - 验证宠物事件删除请求契约
@MainActor
final class PetRepositoryEventContractTests: PetRepositoryTestCase {
    func testCreateEventSendsUserContextAndDecodesEvent() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/events")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["event_kind"] as? String, "health")
            XCTAssertEqual(json?["event_subkind"] as? String, "weight")
            XCTAssertEqual(json?["title"] as? String, "体重记录")
            XCTAssertEqual(json?["summary"] as? String, "5.2kg，较上次稳定")
            XCTAssertEqual(json?["visibility"] as? String, "private")
            XCTAssertEqual(json?["occurred_at"] as? String, "2026-06-13T09:20:00Z")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_created",
                  "message": "宠物事件已记录",
                    "data": {
                      "id": "event-1",
                      "pet_id": "pet-1",
                      "litter_id": null,
                      "event_kind": "health",
                      "event_subkind": "weight",
                      "title": "体重记录",
                      "summary": "5.2kg，较上次稳定",
                      "visibility": "private",
                      "event_payload": {
                        "weight_kg": 5.2
                      },
                      "occurred_at": "2026-06-13T09:20:00Z",
                      "record_revision": 1
                    }
                }
                """
            )
        }

        let response = try await repository.createEvent(
            petID: "pet-1",
            draft: PetEventDraft(
                kind: .health,
                subkind: "weight",
                title: "体重记录",
                summary: "5.2kg，较上次稳定",
                visibility: .private,
                occurredAt: "2026-06-13T09:20:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已记录")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertEqual(response.data?.recordRevision, 1)
    }

    func testLoadEventDetailSendsUserContextAndDecodesEvent() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-events/event-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_loaded",
                  "message": "宠物事件已加载",
                  "data": {
                    "id": "event-1",
                    "pet_id": "pet-1",
                    "event_kind": "health",
                    "event_subkind": "weight",
                    "title": "体重记录",
                    "summary": "5.2kg，较上次稳定",
                    "visibility": "private",
                    "occurred_at": "2026-06-13T09:20:00Z",
                    "record_revision": 1
                  }
                }
                """
            )
        }

        let response = try await repository.loadEventDetail(
            eventID: "event-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已加载")
        XCTAssertEqual(response.data?.id, "event-1")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertNil(response.data?.litterID)
        XCTAssertEqual(response.data?.title, "体重记录")
    }

    func testLoadTimelineSendsUserContextAndDecodesEntries() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/timeline")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.timeline_loaded",
                  "message": "宠物时间线已加载",
                  "data": {
                    "pet_id": "pet-1",
                    "events": [
                      {
                        "id": "event-1",
                        "pet_id": "pet-1",
                        "event_kind": "daily",
                        "event_subkind": "appetite_normal",
                        "title": "食欲正常",
                        "summary": "今天食欲正常",
                        "visibility": "private",
                        "event_payload": null,
                        "occurred_at": "2026-06-13T09:20:00Z",
                        "record_revision": 1,
                        "source": "event"
                      },
                      {
                        "id": "pet-1-homecoming",
                        "pet_id": "pet-1",
                        "event_kind": "daily",
                        "event_subkind": "homecoming",
                        "title": "到家的第一天",
                        "summary": "糯米来到你身边",
                        "visibility": "private",
                        "event_payload": {
                          "lifecycle_kind": "homecoming"
                        },
                        "occurred_at": "2024-06-16T00:00:00Z",
                        "record_revision": 1,
                        "source": "lifecycle"
                      }
                    ]
                  }
                }
                """
            )
        }

        let response = try await repository.loadTimeline(
            petID: "pet-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物时间线已加载")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertEqual(response.data?.events.map(\.id), ["event-1", "pet-1-homecoming"])
        XCTAssertEqual(response.data?.events[0].source, .event)
        XCTAssertEqual(response.data?.events[1].source, .lifecycle)
        XCTAssertEqual(response.data?.events[1].subkind, "homecoming")
    }

    func testDeleteEventSendsUserContextAndDecodesDeletion() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-events/event-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_deleted",
                  "message": "宠物事件已删除",
                  "data": {
                    "id": "event-1",
                    "deleted": true
                  }
                }
                """
            )
        }

        let response = try await repository.deleteEvent(
            eventID: "event-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已删除")
        XCTAssertEqual(response.data?.id, "event-1")
        XCTAssertEqual(response.data?.deleted, true)
    }
}
