import CryptoKit
import Foundation
import OSLog

final class APIClient: Sendable {

    static let shared = APIClient()

    private let baseURL = AppConfig.apiBaseURL
    private let session = URLSession.shared

    private init() {}

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let url = components.url!
        do {
            let (data, response) = try await session.data(from: url)
            try Self.validate(response, url: url)
            let value = try Self.makeDecoder().decode(T.self, from: data)
            ResponseCache.store(data, for: url)
            return value
        } catch {
            // An API outage (bad deploy, 5xx, offline) falls back to the last good response for this
            // exact request, so screens keep their content instead of showing an error.
            if !Self.isCancellation(error),
               let cached = ResponseCache.data(for: url),
               let value = try? Self.makeDecoder().decode(T.self, from: cached) {
                Log.repository.error("GET \(url.path) failed (\(error)); serving cached response")
                return value
            }
            throw error
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    func post(_ path: String, body: [String: String]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        try Self.validate(response, url: request.url)
    }

    private static func validate(_ response: URLResponse, url: URL?) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.repository.error("HTTP \(status) for \(url?.path ?? "?")")
            throw URLError(.badServerResponse)
        }
    }

    // Handles timestamptz ("2026-03-17T10:30:00.000Z") and date-only ("2026-03-17") strings.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let iso = ISO8601DateFormatter()

            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }

            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }

            let dateFmt = DateFormatter()
            dateFmt.locale = Locale(identifier: "en_US_POSIX")
            dateFmt.timeZone = TimeZone(identifier: "UTC")
            dateFmt.dateFormat = "yyyy-MM-dd"
            if let date = dateFmt.date(from: string) { return date }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode date from string: \(string)"
                )
            )
        }
        return decoder
    }
}

/// Last successful response body per request URL, on disk in Caches (the system may purge it).
private enum ResponseCache {
    private static let directory: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("api-responses", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func file(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash)
    }

    static func store(_ data: Data, for url: URL) {
        try? data.write(to: file(for: url), options: .atomic)
    }

    static func data(for url: URL) -> Data? {
        try? Data(contentsOf: file(for: url))
    }
}
