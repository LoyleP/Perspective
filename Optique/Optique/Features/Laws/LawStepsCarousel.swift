import SwiftUI

/// A law's path as a row of cards, like the story page's position cards: one card per stage (each
/// reading, then the stages still to come), the centred card full size, the others smaller and
/// dimmed, snapping to centre. It opens on the stage the law is at now.
struct LawStepsCarousel: View {
    let law: Law
    /// Index into `law.steps` of the card in the middle (nil on the cards still to come).
    @Binding var selectedStep: Int?

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
        // First card: the text being filed, so the "Déposé" part of the progress bar has a card too.
        var items = [Item(id: "deposit", kind: .done, step: nil, place: law.kind ?? "Texte", label: "Dépôt")]
        items += law.steps.enumerated().map { index, step in
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

    private var cardFraction: CGFloat { dynamicTypeSize.isAccessibilitySize ? 0.88 : 0.8 }
    private var cardWidth: CGFloat { max(width * cardFraction, 190) }
    /// Height of a reading card that shows a hemicycle: header, label, strip, hemicycle (aspect 1.9), tally.
    private var fullCardHeight: CGFloat {
        let inner = cardWidth - 2 * AppSpacing.m
        return AppSpacing.m * 2 + 150 + inner / 1.9 + 44
    }
    private var sideMargin: CGFloat { max((width - cardWidth) / 2, AppSpacing.m) }

    var body: some View {
        Group {
            if width > 0 {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: AppSpacing.s) {
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
                    .onChange(of: selected) { _, id in
                        if id == "deposit" {
                            selectedStep = -1
                        } else if let id, id.hasPrefix("step"), let index = Int(id.dropFirst(4)) {
                            selectedStep = index
                        } else {
                            selectedStep = nil
                        }
                    }
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
            HStack(alignment: .firstTextBaseline) {
                Text(item.place)
                    .font(.geist(.body, .medium))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Spacer(minLength: AppSpacing.s)
                if let status = status(item) { StatusTag(text: status.text, icon: status.icon, tone: status.tone) }
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                Text(item.label)
                    .font(.geist(.title, .medium))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                if let help = LawExplainer.glossary(item.label) {
                    JargonHelp(term: item.label, text: help)
                }
                if let date = dateBeside(item) {
                    Text(date)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }

            if let step = item.step, step.code.hasPrefix("AN") || step.code.hasPrefix("SN") {
                readingStrip(step)
                // The vote slot: the hemicycle once there was a public vote, a short note until then.
                if let vote = step.vote {
                    voteBlock(vote)
                } else {
                    step.stage == "vote"
                        ? iconNote(icon: "hand-raised", text: "Vote à main levée, sans décompte par député.", muted: false)
                        : iconNote(icon: "calendar", text: "Le vote n'a pas encore eu lieu.", muted: true)
                }
            } else {
                iconNote(item)
            }
        }
        .padding(AppSpacing.m)
        // Every card has the height of one with a full hemicycle (also when none of them has one),
        // and stretches to the tallest in the row.
        .frame(minHeight: fullCardHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.stroke, lineWidth: 1))
        .opacity(item.kind == .upcoming ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }

    /// Status tag in the card's top right corner, like a to-do list.
    private func status(_ item: Item) -> (text: String, icon: String, tone: StatusTag.Tone)? {
        if item.id == "deposit" { return nil }
        if item.kind == .upcoming { return ("À venir", "calendar", .neutral) }
        if let step = item.step {
            if step.code == "PROM" { return ("Promulguée", "check-badge", .success) }
            if let decision = step.decision?.lowercased() {
                if decision.hasPrefix("adopt") { return ("Adopté", "check-circle", .success) }
                if decision.hasPrefix("rejet") { return ("Rejeté", "x-circle", .danger) }
                if decision.hasPrefix("modif") { return ("Modifié", "pencil", .info) }
                return (decision.capitalizedFirst, "check-circle", .neutral)
            }
        }
        return item.kind == .current ? ("En cours", "clock", .progress) : ("Terminé", "check-circle", .neutral)
    }

    /// Dates shown next to the big label on the cards that have no vote (filing, Conseil constitutionnel, promulgation).
    private func dateBeside(_ item: Item) -> String? {
        if item.id == "deposit" { return LawDates.short(law.steps.first?.startedAt) }
        if let step = item.step, step.code == "PROM" || step.code == "CC" { return LawDates.short(step.startedAt) }
        return nil
    }

    /// Dépôt · Commission · Séance · Vote of one reading, as four bar segments like the progress bar above
    /// the cards: lit up to the stage reached, each labelled with its name and date, text aligned left.
    private func readingStrip(_ step: LawStep) -> some View {
        let moments: [(String, String?, Bool)] = [
            ("Dépôt", step.startedAt, true),
            ("Comm.", step.commissionAt, step.commissionAt != nil),
            ("Séance", step.debateAt, step.debateAt != nil),
            ("Vote", step.decidedAt, step.decision != nil)
        ]
        return HStack(alignment: .top, spacing: 4) {
            ForEach(Array(moments.enumerated()), id: \.offset) { _, moment in
                VStack(alignment: .leading, spacing: 6) {
                    Capsule()
                        .fill(moment.2 ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.divider)
                        .frame(height: 4)
                    Text(moment.0)
                        .font(.appCaption)
                        .foregroundStyle(moment.2 ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                    Text(LawDates.shortDay(moment.1) ?? " ")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Text filling the card's lower slot, aligned left.
    private func slotText(_ text: String, muted: Bool = false) -> some View {
        Text(text)
            .font(.appBody)
            .foregroundStyle(muted ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The closing vote as a hemicycle: yes seats lit, the rest dimmed, with the tally under it.
    private func voteBlock(_ vote: LawVote) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            SeatsHemicycle(vote: vote)
            // Legend: how to read a seat (colour = the group's political side).
            HStack(spacing: AppSpacing.st) {
                legendItem(Circle().fill(AppColors.Adaptive.textPrimary), "\(vote.yes) pour")
                legendItem(Circle().fill(AppColors.Adaptive.textPrimary.opacity(0.38)), "\(vote.no) contre")
                legendItem(Circle().stroke(AppColors.Adaptive.textPrimary.opacity(0.55), lineWidth: 1), "\(vote.abstained) abst.")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text("Couleur : bord politique du groupe")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, AppSpacing.s)
    }

    private func legendItem(_ dot: some View, _ text: String) -> some View {
        HStack(spacing: 5) {
            dot.frame(width: 8, height: 8)
            Text(text)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    /// Short line for the stages that have no reading strip, with an icon above it, centred in the card's free space.
    private func iconNote(_ item: Item) -> some View {
        let note = noteContent(item)
        return iconNote(icon: note.icon, text: note.text, muted: item.kind == .upcoming)
    }

    private func iconNote(icon: String, text: String, muted: Bool) -> some View {
        VStack(spacing: AppSpacing.st) {
            HeroIcon(icon, size: 36)
                .foregroundStyle(muted ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
            Text(text)
                .font(.appBody)
                .foregroundStyle(muted ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func noteContent(_ item: Item) -> (icon: String, text: String) {
        if item.id == "deposit" { return ("document-text", "Le texte est déposé, puis envoyé en commission.") }
        if let step = item.step {
            switch step.code {
            case "CMP": return ("arrow-path", "Députés et sénateurs cherchent un accord.")
            case "CC": return ("scale", "Le Conseil constitutionnel a vérifié le texte.")
            case "PROM": return ("check-badge", "La loi est publiée au Journal officiel.")
            default: break
            }
        }
        switch item.label {
        case "Adoption définitive": return ("check-circle", "Les deux chambres votent le même texte.")
        case "Promulgation": return ("check-badge", "Le président promulgue la loi.")
        case "Congrès ou référendum": return ("building-library", "Le Congrès ou le peuple valide la révision.")
        default: return ("building-library", "Examen par \(item.place == "Sénat" ? "le Sénat" : "l'Assemblée").")
        }
    }
}

/// Coloured status pill (to-do list style): green adopted, red rejected, amber in progress, blue amended.
private struct StatusTag: View {
    enum Tone { case success, danger, progress, info, neutral }

    let text: String
    /// Heroicon shown to the left of the text.
    let icon: String
    let tone: Tone

    private var color: Color {
        switch tone {
        case .success: return Color(light: "15803D", dark: "4ADE80")
        case .danger: return Color(light: "B91C1C", dark: "F87171")
        case .progress: return Color(light: "B45309", dark: "FBBF24")
        case .info: return Color(light: "1D4ED8", dark: "60A5FA")
        case .neutral: return AppColors.Adaptive.textMeta
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            HeroIcon(icon, size: 14)
            Text(text)
                .font(.appCaption)
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(color.opacity(0.16), in: Capsule())
    }
}

/// A small "i" next to a legal term; tapping it explains the term in a popover.
private struct JargonHelp: View {
    let term: String
    let text: String
    @State private var shown = false

    var body: some View {
        Button { shown = true } label: {
            HeroIcon("information-circle", size: 18)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Qu'est-ce que « \(term) » ?")
        .popover(isPresented: $shown) {
            Text(text)
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(AppSpacing.m)
                .presentationCompactAdaptation(.popover)
        }
    }
}
