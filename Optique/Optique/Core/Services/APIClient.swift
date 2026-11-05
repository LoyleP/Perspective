import CryptoKit
import Foundation
import OSLog

final class APIClient: Sendable {

    static let shared = APIClient()

    private let baseURL = AppConfig.apiBaseURL
    private let session = URLSession.shared

    private init() {}

    private func url(_ path: String, _ query: [String: String]) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let url = url(path, query)
        do {
            let data = try await Self.inflight.data(for: url, session: session)
            let value = try Self.decoder.decode(T.self, from: data)
            ResponseCache.store(data, for: url)
            return value
        } catch {
            // An API outage (bad deploy, 5xx, offline) falls back to the last good response for this
            // exact request, so screens keep their content instead of showing an error.
            if !Self.isCancellation(error),
               let cached = ResponseCache.data(for: url),
               let value = try? Self.decoder.decode(T.self, from: cached) {
                Log.repository.error("GET \(url.path) failed (\(error)); serving cached response")
                return value
            }
            throw error
        }
    }

    /// The last good response for this exact request (memory, then disk), or nil. Screens show it
    /// at once and refresh from the network behind it.
    func cached<T: Decodable>(_ path: String, query: [String: String] = [:]) async -> T? {
        let url = url(path, query)
        guard let data = ResponseCache.data(for: url) else { return nil }
        return try? Self.decoder.decode(T.self, from: data)
    }

    /// Identical requests already on their way share one network call.
    private static let inflight = InflightRequests()

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
    // The formatters are built once: creating them per date made decoding a feed slow.
    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    nonisolated(unsafe) private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated(unsafe) private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = isoFractional.date(from: string) ?? isoPlain.date(from: string) ?? dayFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode date from string: \(string)"
                )
            )
        }
        return decoder
    }()
}

/// Shares one network call between identical GETs started at the same time.
private final class InflightRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [URL: Task<Data, Error>] = [:]

    func data(for url: URL, session: URLSession) async throws -> Data {
        lock.lock()
        if let task = tasks[url] { lock.unlock(); return try await task.value }
        let task = Task<Data, Error> {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                Log.repository.error("HTTP \(status) for \(url.path)")
                throw URLError(.badServerResponse)
            }
            return data
        }
        tasks[url] = task
        lock.unlock()
        defer { lock.lock(); tasks[url] = nil; lock.unlock() }
        return try await task.value
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

    /// Recent responses kept in memory too, so reopening a screen doesn't touch the disk.
    nonisolated(unsafe) private static let memory: NSCache<NSURL, NSData> = {
        let c = NSCache<NSURL, NSData>()
        c.totalCostLimit = 32 * 1024 * 1024
        return c
    }()

    static func store(_ data: Data, for url: URL) {
        memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        try? data.write(to: file(for: url), options: .atomic)
    }

    static func data(for url: URL) -> Data? {
        if let hit = memory.object(forKey: url as NSURL) { return hit as Data }
        guard let data = try? Data(contentsOf: file(for: url)) else { return nil }
        memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }
}
