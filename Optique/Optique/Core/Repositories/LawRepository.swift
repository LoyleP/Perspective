import Foundation
import OSLog

/// Laws followed in the Lois tab (synced server-side from the Assemblée and Sénat data).
final class LawRepository: Sendable {

    static let shared = LawRepository()

    private init() {}

    func fetchLaws() async throws -> LawsPage {
        do {
            return try await APIClient.shared.get("laws")
        } catch {
            Log.repository.error("fetchLaws failed: \(error)")
            throw AppError.from(error)
        }
    }

    func cachedLaws() async -> LawsPage? { await APIClient.shared.cached("laws") }

    func cachedLaw(uid: String) async -> Law? { await APIClient.shared.cached("law", query: ["uid": uid]) }

    func fetchLaw(uid: String) async throws -> Law {
        do {
            return try await APIClient.shared.get("law", query: ["uid": uid])
        } catch {
            Log.repository.error("fetchLaw(\(uid)) failed: \(error)")
            throw AppError.from(error)
        }
    }
}
