import Foundation

struct HTTPResponse: Sendable {
    let status: Int
    let data: Data
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

final class URLSessionTransport: NSObject, HTTPTransport, URLSessionTaskDelegate, Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        guard let url = request.url, ServerAddress.allowedTransport(url) else { throw ChainError.invalidConfiguration }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = request.timeoutInterval
        configuration.timeoutIntervalForResource = request.timeoutInterval
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, data.count <= 8_000_000 else {
                throw ChainError.invalidResponse
            }
            return HTTPResponse(status: response.statusCode, data: data)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw error.code == .timedOut ? ChainError.timeout : ChainError.network
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // Never replay a broadcast to a redirected host or downgrade TLS.
        completionHandler(nil)
    }
}
