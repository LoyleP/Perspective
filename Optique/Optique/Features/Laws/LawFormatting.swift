import Foundation

/// Step dates come as "2026-10-28".
enum LawDates {
    private static let input: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let output: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let dayOutput: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    /// "29 oct." for the compact strips.
    static func shortDay(_ value: String?) -> String? {
        guard let value, let date = input.date(from: value) else { return nil }
        return dayOutput.string(from: date)
    }

    static func short(_ value: String?) -> String? {
        guard let value, let date = input.date(from: value) else { return nil }
        return output.string(from: date)
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
