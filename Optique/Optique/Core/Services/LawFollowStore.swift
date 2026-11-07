import Foundation
import Observation
import UserNotifications

/// Laws the reader follows with the bell. Each one remembers the stage it was last seen at, so a
/// local notification goes out when the text moves on (new reading, vote, promulgation…).
@MainActor
@Observable
final class LawFollowStore {
    static let shared = LawFollowStore()

    private let key = "followedLaws"
    /// uid → signature of the stage last seen.
    private(set) var followed: [String: String]

    private init() {
        followed = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    /// Forgets every followed law.
    func reset() {
        followed = [:]
        UserDefaults.standard.removeObject(forKey: key)
    }

    func isFollowing(_ uid: String) -> Bool { followed[uid] != nil }

    func follow(_ law: Law) {
        followed[law.uid] = Self.signature(law)
        save()
    }

    func unfollow(_ uid: String) {
        followed[uid] = nil
        save()
    }

    /// The reader has seen the law as it is now: no notification for what they already know.
    func markSeen(_ law: Law) {
        guard followed[law.uid] != nil else { return }
        followed[law.uid] = Self.signature(law)
        save()
    }

    /// Compares followed laws with the server and notifies about the ones that moved.
    func checkForUpdates() async {
        guard !followed.isEmpty,
              await NotificationManager.shared.authorizationStatus == .authorized,
              let page = try? await LawRepository.shared.fetchLaws() else { return }
        for law in page.laws {
            guard let seen = followed[law.uid] else { continue }
            let now = Self.signature(law)
            guard now != seen else { continue }
            followed[law.uid] = now
            await NotificationManager.shared.notify(
                title: law.displayTitle,
                body: Self.update(law)
            )
        }
        save()
    }

    private func save() { UserDefaults.standard.set(followed, forKey: key) }

    private static func signature(_ law: Law) -> String {
        let step = law.current
        return [String(law.steps.count), step?.code, step?.stage, step?.decision].compactMap { $0 }.joined(separator: "|")
    }

    private static func update(_ law: Law) -> String {
        guard let step = law.current else { return "Le texte a avancé." }
        if law.isPromulgated { return "Le texte a été promulgué." }
        let decision = step.decision.map { " : \($0)" } ?? ""
        return "\(step.place) · \(step.label)\(decision)"
    }
}
