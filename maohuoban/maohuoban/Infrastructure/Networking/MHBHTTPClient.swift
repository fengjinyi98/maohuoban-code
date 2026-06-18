import Foundation

// MHBMultipartFile multipart 文件字段
// 核心职责：
// - 承载 multipart 文件 part 的字段名、文件名、MIME 和二进制内容
// - 为 HTTP 客户端生成标准 form-data body 提供稳定输入
struct MHBMultipartFile: Equatable {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

// MHBHTTPClient 后端 HTTP 客户端
// 核心职责：
// - 统一发起 JSON 和 multipart 请求并解析后端标准响应
// - 将后端 code/message 转为可展示错误
// - 默认使用 Mac 局域网 IP 访问开发后端，方便真机联调
struct MHBHTTPClient {
    let baseURL: URL
    let session: URLSession
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    init(
        baseURL: URL = MHBBackendEndpoint.localDevelopmentBaseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await sendJSON(method: "POST", path: path, body: body, headers: headers)
    }

    func patch<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await sendJSON(method: "PATCH", path: path, body: body, headers: headers)
    }

    func delete<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await sendJSON(method: "DELETE", path: path, body: body, headers: headers)
    }

    func get<ResponseBody: Decodable>(
        path: String,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return try await send(request)
    }

    func get<ResponseBody: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let basePathURL = baseURL.appending(path: path)
        guard var components = URLComponents(url: basePathURL, resolvingAgainstBaseURL: false) else {
            throw .invalidResponse
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw .invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return try await send(request)
    }

    private func sendJSON<RequestBody: Encodable, ResponseBody: Decodable>(
        method: String,
        path: String,
        body: RequestBody,
        headers: [String: String]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw .decoding(error.localizedDescription)
        }

        return try await send(request)
    }
}
