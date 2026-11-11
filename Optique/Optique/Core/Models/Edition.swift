import Foundation

/// One edition of the Brief: five stories chosen on the server (06:00 and 18:00, Paris time), the same for every reader.
nonisolated struct Edition: Decodable, Identifiable, Hashable {

    enum Slot: String, Decodable {
        case matin, soir

        var title: String { self == .matin ? "Édition du matin" : "Édition du soir" }
    }

    let id: UUID
    /// The Paris day, "2026-11-10".
    let day: String
    let slot: Slot
    let publishedAt: Date
    /// The lead story's headline.
    let headline: String
    let stories: [Story]

    enum CodingKeys: String, CodingKey {
        case id, day, slot, headline, stories
        case publishedAt = "published_at"
    }

    init(id: UUID, day: String, slot: Slot, publishedAt: Date, headline: String, stories: [Story]) {
        self.id = id
        self.day = day
        self.slot = slot
        self.publishedAt = publishedAt
        self.headline = headline
        self.stories = stories
    }

    /// "MARDI 10 NOVEMBRE", for the small label on the first card.
    var dateLabel: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        let date = parser.date(from: day) ?? publishedAt
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date).uppercased()
    }

    /// Reading time of the written part (titles and bullets), about 220 words a minute, never under a minute.
    var readingMinutes: Int {
        let words = stories.reduce(0) { total, story in
            total + story.title.split(separator: " ").count + (story.dek ?? "").split(whereSeparator: \.isWhitespace).count
        }
        return max(1, Int((Double(words) / 220).rounded(.up)))
    }
}

extension Story {
    /// The written description as separate points, one per line.
    nonisolated var bullets: [String] {
        guard let text = dek ?? summary, !text.isEmpty else { return [] }
        return text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "•-– ").union(.whitespaces)) }
            .filter { !$0.isEmpty }
    }
}
