import SwiftUI

/// A law's path as a row of cards, like the story page's position cards: one card per stage (each
/// reading, then the stages still to come), the centred card full size, the others smaller and
/// dimmed, snapping to centre. It opens on the stage the law is at now.
struct LawStepsCarousel: View {
    let law: Law

    @State private var selected: String?
    @State private var width: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Item: Identifiable {
        enum Kind { case done, current, upcoming }
        let id: String
        let kind: Kind
        let step: LawStep?
        let place: String
        let label: String
    }

    private var items: [Item] {
        var items = law.steps.enumerated().map { index, step in
            let isLast = index == law.steps.count - 1 && !law.isPromulgated
            return Item(id: "step\(index)", kind: isLast ? .current : .done, step: step, place: step.place, label: step.label)
        }
        items += law.upcoming.enumerated().map { index, text in
            let parts = text.components(separatedBy: " · ")
            return Item(id: "next\(index)", kind: .upcoming, step: nil,
                        place: parts.count > 1 ? parts[1] : text, label: parts.count > 1 ? parts[0] : "À venir")
        }
        return items
    }

    private var cardFraction: CGFloat { dynamicTypeSize.isAccessibilitySize ? 0.88 : 0.76 }
    private var cardWidth: CGFloat { max(width * cardFraction, 190) }
    private var sideMargin: CGFloat { max((width - cardWidth) / 2, AppSpacing.m) }

    var body: some View {
        Group {
            if width > 0 {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: AppSpacing.st) {
                            ForEach(items) { item in
                                card(item)
                                    .frame(width: cardWidth)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .scrollTransition(axis: .horizontal) { content, phase in
                                        content
                                            .scaleEffect(1 - min(abs(phase.value), 1) * 0.12)
                                            .opacity(1 - min(abs(phase.value), 1) * 0.45)
                                    }
                                    .id(item.id)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, sideMargin, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selected, anchor: .center)
                    .onAppear {
                        let start = items.first { $0.kind == .current } ?? items.last { $0.kind == .done } ?? items.first
                        guard let start else { return }
                        selected = start.id
                        DispatchQueue.main.async { proxy.scrollTo(start.id, anchor: .center) }
                    }
                }
            } else {
                Color.clear.frame(height: 200)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { width = geo.size.width }
                    .onChange(of: geo.size.width) { _, new in width = new }
            }
        )
    }

    // MARK: - Cards

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Text(item.place)
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                Text(item.label)
                    .font(.appTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text(badge(item))
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }

            if let step = item.step, step.code.hasPrefix("AN") || step.code.hasPrefix("SN") {
                readingLines(step)
                if let vote = step.vote { voteBlock(vote) }
            } else {
                Text(explanation(item))
                    .font(.appBody)
                    .foregroundStyle(item.kind == .upcoming ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.st)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.stroke, lineWidth: 1))
        .opacity(item.kind == .upcoming ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }

    private func badge(_ item: Item) -> String {
        switch item.kind {
        case .current: return "En cours"
        case .upcoming: return "À venir"
        case .done:
            if let step = item.step, step.code == "PROM" || step.code == "CC" { return LawDates.short(step.startedAt) ?? "" }
            return item.step?.decision?.capitalizedFirst ?? "Terminé"
        }
    }

    /// Dépôt · Commission · Séance · Vote of one reading, with a bullet filled once reached.
    private func readingLines(_ step: LawStep) -> some View {
        let lines: [(String, String?, Bool)] = [
            ("Dépôt", LawDates.short(step.startedAt), true),
            ("Commission", LawDates.short(step.commissionAt), step.commissionAt != nil),
            ("Séance publique", LawDates.short(step.debateAt), step.debateAt != nil),
            ("Vote", [step.decision?.capitalizedFirst, LawDates.short(step.decidedAt)].compactMap { $0 }.joined(separator: " · "),
             step.decision != nil)
        ]
        return VStack(alignment: .leading, spacing: AppSpacing.s) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .center, spacing: AppSpacing.s) {
                    Circle()
                        .fill(line.2 ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.divider)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                    Text(line.0)
                        .font(.appBody)
                        .foregroundStyle(line.2 ? AppColors.Adaptive.textBody : AppColors.Adaptive.textMeta)
                    Spacer(minLength: 0)
                    if let detail = line.1, !detail.isEmpty {
                        Text(detail)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
            }
        }
    }

    /// The closing vote as a hemicycle: yes seats lit, the rest dimmed, with the tally under it.
    private func voteBlock(_ vote: LawVote) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            SeatsHemicycle(vote: vote)
            Text("\(vote.yes) pour · \(vote.no) contre · \(vote.abstained) abst.")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, AppSpacing.s)
    }

    private func explanation(_ item: Item) -> String {
        if let step = item.step {
            switch step.code {
            case "CMP": return "Sept députés et sept sénateurs cherchent une version commune quand les deux chambres ne sont pas d'accord."
            case "CC": return "Le Conseil constitutionnel a vérifié que la loi respecte la Constitution."
            case "PROM": return "La loi est promulguée et publiée au Journal officiel : elle s'applique."
            default: break
            }
        }
        switch item.label {
        case "Adoption définitive": return "Les deux chambres doivent voter un texte identique."
        case "Promulgation": return "Le président promulgue la loi, qui est publiée au Journal officiel."
        case "Congrès ou référendum": return "Une révision de la Constitution doit être validée par le Congrès ou par référendum."
        default: return "Le texte sera examiné en commission, débattu puis voté dans \(item.place == "Sénat" ? "le Sénat" : "l'Assemblée")."
        }
    }
}
