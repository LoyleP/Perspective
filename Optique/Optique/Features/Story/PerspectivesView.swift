import SwiftUI

/// AI summary of how each side of the spectrum covers the story, one side at a time.
struct PerspectivesView: View {
    let summary: SpectrumSummary?
    let isUnavailable: Bool

    @State private var side: Side = .centre

    enum Side: String, CaseIterable, Identifiable {
        case gauche = "Gauche"
        case centre = "Centre"
        case droite = "Droite"

        var id: String { rawValue }

        func contains(_ lean: PoliticalLean) -> Bool {
            switch self {
            case .gauche: return lean.rawValue < 4
            case .centre: return lean == .centre
            case .droite: return lean.rawValue > 4
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Ce que disent les médias", subtitle: subtitle)

            if let summary {
                Picker("Bord politique", selection: $side) {
                    ForEach(Side.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                let perspectives = summary.perspectives
                    .filter { side.contains($0.lean) }
                    .sorted { $0.lean.rawValue < $1.lean.rawValue }

                if perspectives.isEmpty {
                    Text("Aucun média de ce bord n'a couvert ce sujet.")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .padding(.vertical, AppSpacing.s)
                } else {
                    ForEach(perspectives) { perspective in
                        perspectiveBlock(perspective)
                    }
                }
            } else if isUnavailable {
                Text("Le résumé n'est pas disponible pour le moment.")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            } else {
                SkeletonLines(count: 4, lineHeight: 14)
            }
        }
        .onChange(of: summary, initial: true) { _, summary in
            if let summary { side = Self.defaultSide(for: summary) }
        }
    }

    private var subtitle: String {
        guard let summary else { return "Résumé en cours de génération…" }
        let count = summary.perspectives.reduce(0) { $0 + $1.sourceCount }
        return "Résumé généré à partir de \(count) articles"
    }

    private func perspectiveBlock(_ perspective: SpectrumPerspective) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            HStack(spacing: AppSpacing.s) {
                LeanTagView(lean: perspective.lean)
                Text(perspective.sourceCount == 1 ? "1 article" : "\(perspective.sourceCount) articles")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            ForEach(Self.bullets(perspective), id: \.self) { bullet in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.st) {
                    Circle()
                        .fill(perspective.lean.spectrumColor)
                        .frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        .accessibilityHidden(true)
                    Text(bullet)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    private static func bullets(_ perspective: SpectrumPerspective) -> [String] {
        perspective.summary
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("•") ? String($0.dropFirst()).trimmingCharacters(in: .whitespaces) : $0 }
            .filter { !$0.isEmpty }
    }

    /// The side with the most covering articles.
    private static func defaultSide(for summary: SpectrumSummary) -> Side {
        Side.allCases.max { lhs, rhs in
            count(summary, lhs) < count(summary, rhs)
        } ?? .centre
    }

    private static func count(_ summary: SpectrumSummary, _ side: Side) -> Int {
        summary.perspectives.filter { side.contains($0.lean) }.reduce(0) { $0 + $1.sourceCount }
    }
}
