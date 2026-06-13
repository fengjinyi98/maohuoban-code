import Foundation

// MHBHTTPClient 后端 HTTP 客户端
// 核心职责：
// - 统一发起 JSON 请求并解析后端标准响应
// - 将后端 code/message 转为可展示错误
// - 默认使用 Mac 局域网 IP 访问开发后端，方便真机联调
struct MHBHTTPClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

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
        body: RequestBody
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw .decoding(error.localizedDescription)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }

        do {
            let apiResponse = try decoder.decode(MHBAPIResponse<ResponseBody>.self, from: data)
            if apiResponse.success, (200..<300).contains(httpResponse.statusCode) {
                return apiResponse
            }
            throw MHBAPIError.business(
                code: apiResponse.code,
                message: apiResponse.message,
                statusCode: httpResponse.statusCode
            )
        } catch let apiError as MHBAPIError {
            throw apiError
        } catch {
            throw .decoding(error.localizedDescription)
        }
    }
}
