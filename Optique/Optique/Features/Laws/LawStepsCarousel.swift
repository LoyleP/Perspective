import SwiftUI

/// A law's path as a row of cards, like the story page's position cards: one card per stage (each
/// reading, then the stages still to come), the centred card full size, the others smaller and
/// dimmed, snapping to centre. It opens on the stage the law is at now.
struct LawStepsCarousel: View {
    let law: Law
    /// Index into `law.steps` of the card in the middle (nil on the cards still to come).
    @Binding var selectedStep: Int?
    /// Vertical timeline (one card per stage down a rail) instead of the horizontal carousel.
    var vertical = false

    @State private var selected: String?
    @State private var width: CGFloat = 0
    @State private var visible: CGFloat = 0
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
            // The label is the big title; when it would just repeat the place (e.g. "Conseil
            // constitutionnel" said twice), show what happens at that stage instead.
            let label = step.label == step.place ? "Décision" : step.label
            return Item(id: "step\(index)", kind: isLast ? .current : .done, step: step, place: step.place, label: label)
        }
        items += law.upcoming.enumerated().map { index, text in
            let parts = text.components(separatedBy: " · ")
            return Item(id: "next\(index)", kind: .upcoming, step: nil,
                        place: parts.count > 1 ? parts[1] : text, label: parts.count > 1 ? parts[0] : "À venir")
        }
        return items
    }

    private var cardFraction: CGFloat { dynamicTypeSize.isAccessibilitySize ? 0.88 : 0.8 }
    private var cardWidth: CGFloat {
        vertical ? max(width - 2 * AppSpacing.m - 14 - AppSpacing.st, 190) : max(width * cardFraction, 190)
    }
    /// Height of a reading card that shows a hemicycle: header, label, strip, hemicycle (aspect 1.9), tally.
    private var fullCardHeight: CGFloat {
        let inner = cardWidth - 2 * AppSpacing.m
        return AppSpacing.m * 2 + 150 + inner / 1.9 + 44
    }
    private var sideMargin: CGFloat { max((width - cardWidth) / 2, AppSpacing.m) }

    var body: some View {
        Group {
            if vertical {
                if width > 0 { timeline } else { Color.clear }
            } else if width > 0 {
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

    // MARK: - Vertical timeline

    /// Newest stage first (stages still to come at the top, the filing at the bottom), one card per
    /// snap, opening on the stage the law is at now.
    private var timeline: some View {
        let all = Array(items.reversed())
        let cardHeight = fullCardHeight + 32
        // The scroll view spans the whole screen (no safe-area insets), so equal margins above and
        // below put the focused card exactly in the middle of the screen.
        let margin = max((visible - cardHeight) / 2, AppSpacing.m)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(all.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: AppSpacing.st) {
                        rail(item, above: index > 0 ? all[index - 1] : nil, hasBelow: index + 1 < all.count, topInset: 0)
                        card(item)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .frame(height: cardHeight)
                            .padding(.bottom, index + 1 < all.count ? AppSpacing.xxl : 0)
                    }
                    .id(item.id)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .scrollTargetLayout()
        }
        .ignoresSafeArea(.container, edges: .vertical)
        .contentMargins(.vertical, margin, for: .scrollContent)
        // The neighbouring cards stay in view; a swipe moves exactly one card and snaps it to the centre.
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $selected, anchor: .center)
        // One tick each time a card snaps into the middle (not for the first positioning on open).
        .sensoryFeedback(trigger: selected) { old, _ in old == nil ? nil : .selection }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { visible = $0 }
        .onAppear {
            let start = items.first { $0.kind == .current } ?? items.last { $0.kind == .done } ?? items.first
            guard let start else { return }
            DispatchQueue.main.async { selected = start.id }
        }
    }

    private let dotSize: CGFloat = 14
    private func dotCenter(_ topInset: CGFloat) -> CGFloat { topInset + AppSpacing.m + 9 }

    /// Dot for the stage with the line running through it, unbroken from one card to the next: solid
    /// up to where the law stands, light for the stages still to come.
    private func rail(_ item: Item, above: Item?, hasBelow: Bool, topInset: CGFloat) -> some View {
        func line(_ kind: Item.Kind) -> Color { kind == .upcoming ? AppColors.Adaptive.divider : AppColors.Adaptive.textPrimary }
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(above.map { line($0.kind) } ?? .clear)
                    .frame(width: 2, height: dotCenter(topInset))
                Rectangle()
                    .fill(hasBelow ? line(item.kind) : .clear)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            Group {
                if item.kind == .upcoming {
                    Circle().fill(AppColors.Adaptive.background)
                        .overlay(Circle().stroke(AppColors.Adaptive.textMeta, lineWidth: 2))
                } else {
                    Circle().fill(AppColors.Adaptive.textPrimary)
                }
            }
            .frame(width: dotSize, height: dotSize)
            .padding(.top, dotCenter(topInset) - dotSize / 2)
        }
        .frame(width: dotSize)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Cards

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            // Date and place on one line, split by a dot.
            Text([dateBeside(item), item.place].compactMap { $0 }.joined(separator: " · "))
                .typeStyle(.meta)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .lineLimit(1)

            HStack(alignment: .center, spacing: AppSpacing.s) {
                Text(item.label)
                    .font(.geist(.heading, .medium))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(1)
                if let help = LawExplainer.glossary(item.label) {
                    JargonHelp(term: item.label, text: help)
                }
            }

            if let step = item.step, step.code.hasPrefix("AN") || step.code.hasPrefix("SN") {
                readingStrip(step)
                // The vote slot: the hemicycle once there was a public vote, a short note until then.
                if let vote = step.vote {
                    voteBlock(vote)
                } else {
                    step.stage == "vote"
                        ? iconNote(icon: "hand", text: "Vote à main levée, sans décompte par député.", muted: false)
                        : iconNote(icon: "calendar", text: "Le vote n'a pas encore eu lieu.", muted: true)
                }
            } else {
                iconNote(item)
            }
        }
        .padding(AppSpacing.m)
        // The status tag sits in the actual top-right corner of the card, independent of whether
        // there's a date above the small title, so a dateless card (upcoming) has no blank row for it.
        .overlay(alignment: .topTrailing) {
            if let status = status(item) {
                StatusTag(text: status.text, icon: status.icon, tone: status.tone)
                    .padding(AppSpacing.m)
            }
        }
        // Every card has the height of one with a full hemicycle (also when none of them has one),
        // and stretches to the tallest in the row.
        .frame(minHeight: vertical ? nil : fullCardHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .opacity(item.kind == .upcoming ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }

    /// Status tag in the card's top right corner, like a to-do list.
    private func status(_ item: Item) -> (text: String, icon: String, tone: StatusTag.Tone)? {
        if item.id == "deposit" { return nil }
        if item.kind == .upcoming { return ("À venir", "calendar", .neutral) }
        if let step = item.step {
            if step.code == "PROM" { return ("Promulguée", "badge-check", .success) }
            if let decision = step.decision?.lowercased() {
                if decision.hasPrefix("adopt") { return ("Adopté", "circle-check", .success) }
                if decision.hasPrefix("rejet") { return ("Rejeté", "circle-x", .danger) }
                if decision.hasPrefix("modif") { return ("Modifié", "pencil", .info) }
                return (decision.capitalizedFirst, "circle-check", .neutral)
            }
        }
        return item.kind == .current ? ("En cours", "clock", .progress) : ("Terminé", "circle-check", .neutral)
    }

    /// Date shown above the small title on every card that has one: the filing date on the deposit
    /// card, and otherwise the latest date reached on that step (readings included, not just the
    /// no-vote stages) so the date line is never blank while the step itself has one.
    private func dateBeside(_ item: Item) -> String? {
        if item.id == "deposit" { return LawDates.short(law.steps.first?.startedAt) }
        guard let step = item.step else { return nil }   // upcoming: no date is known yet
        return LawDates.short(step.decidedAt ?? step.debateAt ?? step.commissionAt ?? step.startedAt)
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
                        .typeStyle(.meta)
                        .foregroundStyle(moment.2 ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                    Text(LawDates.shortDay(moment.1) ?? " ")
                        .typeStyle(.meta)
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
            .typeStyle(.body)
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
                .typeStyle(.meta)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, AppSpacing.s)
    }

    private func legendItem(_ dot: some View, _ text: String) -> some View {
        HStack(spacing: 5) {
            dot.frame(width: 8, height: 8)
            Text(text)
                .typeStyle(.meta)
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
            LucideIcon(icon, size: 36)
                .foregroundStyle(muted ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
            Text(text)
                .typeStyle(.body)
                .foregroundStyle(muted ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func noteContent(_ item: Item) -> (icon: String, text: String) {
        if item.id == "deposit" { return ("file-text", "Le texte est déposé, puis envoyé en commission.") }
        if let step = item.step {
            switch step.code {
            case "CMP": return ("refresh-cw", "Députés et sénateurs cherchent un accord.")
            case "CC": return ("scale", "Le Conseil constitutionnel a vérifié le texte.")
            case "PROM": return ("badge-check", "La loi est publiée au Journal officiel.")
            default: break
            }
        }
        switch item.label {
        case "Adoption définitive": return ("circle-check", "Les deux chambres votent le même texte.")
        case "Promulgation": return ("badge-check", "Le président promulgue la loi.")
        case "Congrès ou référendum": return ("landmark", "Le Congrès ou le peuple valide la révision.")
        default: return ("landmark", "Examen par \(item.place == "Sénat" ? "le Sénat" : "l'Assemblée").")
        }
    }
}

/// Coloured status pill (to-do list style): green adopted, red rejected, amber in progress, blue amended.
private struct StatusTag: View {
    enum Tone { case success, danger, progress, info, neutral }

    let text: String
    /// Lucide icon shown to the left of the text.
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
            LucideIcon(icon, size: 14)
            Text(text)
                .typeStyle(.meta)
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
            LucideIcon("info", size: 18)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Qu'est-ce que « \(term) » ?")
        .popover(isPresented: $shown) {
            Text(text)
                .typeStyle(.body)
                .foregroundStyle(AppColors.Adaptive.textBody)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(AppSpacing.m)
                .presentationCompactAdaptation(.popover)
        }
    }
}
