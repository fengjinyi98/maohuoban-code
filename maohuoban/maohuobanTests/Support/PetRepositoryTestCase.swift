import Foundation
import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// PetRepositoryTestCase 宠物仓库测试基类
// 核心职责：
// - 提供仓库契约测试共享 HTTP 桩与响应构造
// - 统一清理诊断运行时与 URLProtocol handler
@MainActor
class PetRepositoryTestCase: XCTestCase {
    override func tearDown() {
        PetRepositoryURLProtocol.handler = nil
        Task {
            await Diagnostics.uninstall()
        }
        super.tearDown()
    }

    func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultPetRepository {
        let client = makeHTTPClient(handler: handler)
        return DefaultPetRepository(client: client)
    }

    func makeHTTPClient(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> MHBHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PetRepositoryURLProtocol.self]
        PetRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        return MHBHTTPClient.authenticated(
            baseURL: URL(string: "http://127.0.0.1:18080")!,
            session: session,
            tokenStore: PetRepositoryTestTokenStore(),
            retryPolicy: .disabled
        )
    }

    static func jsonResponse(statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:18080")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }

    static func assertMultipartMediaRequest(
        _ request: URLRequest,
        fileName: String,
        mimeType: String,
        contentText: String,
        sourceClient: String
    ) throws {
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
        let bodyText = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(
            bodyText.contains("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"")
        )
        XCTAssertTrue(bodyText.contains("Content-Type: \(mimeType)"))
        XCTAssertTrue(bodyText.contains(contentText))
        XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"source_client\""))
        XCTAssertTrue(bodyText.contains(sourceClient))
    }

    static func assertMultipartLivePhotoRequest(
        _ request: URLRequest,
        stillFileName: String,
        stillMimeType: String,
        stillContentText: String,
        pairedVideoFileName: String,
        pairedVideoMimeType: String,
        pairedVideoContentText: String,
        sourceClient: String,
        cropMetadata: MHBImageCropMetadata? = nil
    ) throws {
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
        let bodyText = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(
            bodyText.contains("Content-Disposition: form-data; name=\"still_file\"; filename=\"\(stillFileName)\"")
        )
        XCTAssertTrue(bodyText.contains("Content-Type: \(stillMimeType)"))
        XCTAssertTrue(bodyText.contains(stillContentText))
        XCTAssertTrue(
            bodyText.contains(
                "Content-Disposition: form-data; name=\"paired_video_file\"; filename=\"\(pairedVideoFileName)\""
            )
        )
        XCTAssertTrue(bodyText.contains("Content-Type: \(pairedVideoMimeType)"))
        XCTAssertTrue(bodyText.contains(pairedVideoContentText))
        XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"source_client\""))
        XCTAssertTrue(bodyText.contains(sourceClient))

        if let cropMetadata {
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"crop_x\""))
            XCTAssertTrue(bodyText.contains(String(cropMetadata.x)))
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"crop_y\""))
            XCTAssertTrue(bodyText.contains(String(cropMetadata.y)))
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"crop_width\""))
            XCTAssertTrue(bodyText.contains(String(cropMetadata.width)))
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"crop_height\""))
            XCTAssertTrue(bodyText.contains(String(cropMetadata.height)))
        }
    }

    static func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func installDiagnostics() async throws -> DiagnosticsRuntime {
        await Diagnostics.uninstall()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("maohuoban-http-client-tests-\(UUID().uuidString)", isDirectory: true)
        return try await Diagnostics.install(
            DiagnosticsConfiguration(
                serviceName: "maohuoban-ios-tests",
                environment: "test",
                storageDirectory: root
            )
        )
    }
}
