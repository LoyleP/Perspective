import Foundation

extension Date {
    private static let relativeFrenchFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    func relativeToNowFrench() -> String {
        Self.relativeFrenchFormatter.localizedString(for: self, relativeTo: Date())
    }
}
