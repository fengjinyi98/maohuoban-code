import Foundation

// DefaultHomeRealtimeRepository 默认首页实时事件仓库
// 核心职责：
// - 使用 MHBHTTPClient 连接首页实时 SSE
// - 只向上层产出已识别的首页实时事件
struct DefaultHomeRealtimeRepository: HomeRealtimeRepository {
    private let client: MHBHTTPClient
    private let session: URLSession

    init(client: MHBHTTPClient = MHBHTTPClient.authenticated()) {
        self.client = client
        self.session = client.session
    }

    func openEventStream() -> AsyncThrowingStream<HomeRealtimeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: client.baseURL.appending(path: "/api/v1/home/events/stream"))
                    request.httpMethod = "GET"
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    try client.prepareRequest(&request)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: MHBAPIError.invalidResponse)
                        return
                    }
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: MHBAPIError.business(
                            code: "home.events_stream_failed",
                            message: "首页实时事件连接失败",
                            statusCode: httpResponse.statusCode
                        ))
                        return
                    }

                    var parser = HomeRealtimeEventParser(decoder: client.decoder)
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        for parsedEvent in parser.consumeLine(line) {
                            if let event = parsedEvent.event {
                                continuation.yield(event)
                            }
                        }
                    }

                    for parsedEvent in parser.finish() {
                        if let event = parsedEvent.event {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
