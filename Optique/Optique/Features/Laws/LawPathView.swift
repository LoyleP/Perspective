import SwiftUI

/// A law's path through Parliament, left to right: the readings already done (filled), the current
/// one (ringed, "En cours"), and the generic stages still to come (dashed). `compact` keeps only the
/// dots and lines, sized to fit a card; the full version scrolls and labels every stage.
struct LawPathView: View {
    let law: Law
    var compact = false

    private struct Node: Identifiable {
        enum Kind { case done, current, upcoming }
        let id: String
        let kind: Kind
        let place: String
        let label: String
        let detail: String?
        let rejected: Bool
    }

    private var nodes: [Node] {
        var nodes = law.steps.enumerated().map { index, step in
            let isLast = index == law.steps.count - 1
            return Node(
                id: step.code + "\(index)",
                kind: isLast && !law.isPromulgated ? .current : .done,
                place: step.place,
                label: step.label,
                detail: step.decision.map { $0.capitalizedFirst } ?? LawDates.short(step.startedAt),
                rejected: step.isRejected
            )
        }
        nodes += law.upcoming.enumerated().map { index, label in
            let parts = label.components(separatedBy: " · ")
            return Node(id: "next\(index)", kind: .upcoming, place: parts.count > 1 ? parts[1] : label,
                        label: parts.count > 1 ? parts[0] : "", detail: nil, rejected: false)
        }
        return nodes
    }

    var body: some View {
        if compact {
            HStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    if index > 0 { connector(to: node).frame(maxWidth: .infinity) }
                    dot(node, size: 10)
                }
            }
            .frame(height: 22)
            .accessibilityElement()
            .accessibilityLabel(accessibilitySummary)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                HStack(spacing: 0) {
                                    dot(node, size: 14)
                                    if index < nodes.count - 1 { connector(to: nodes[index + 1]) }
                                }
                                .frame(height: 26)
                                labels(node)
                                    .padding(.trailing, AppSpacing.st)
                            }
                            .frame(width: 128, alignment: .leading)
                            .id(node.id)
                        }
                    }
                    .padding(.horizontal, AppSpacing.m)
                }
                .onAppear {
                    if let current = nodes.first(where: { $0.kind == .current }) ?? nodes.last(where: { $0.kind == .done }) {
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func dot(_ node: Node, size: CGFloat) -> some View {
        switch node.kind {
        case .done:
            Circle()
                .fill(node.rejected ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textPrimary)
                .frame(width: size, height: size)
        case .current:
            Circle()
                .fill(AppColors.Adaptive.textPrimary)
                .frame(width: size, height: size)
                .padding(size * 0.35)
                .overlay(Circle().stroke(AppColors.Adaptive.textPrimary, lineWidth: 2))
        case .upcoming:
            Circle()
                .stroke(AppColors.Adaptive.textMeta, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                .frame(width: size, height: size)
        }
    }

    /// Line leading to `node`: solid once reached, dashed ahead.
    private func connector(to node: Node) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 2)
            .overlay {
                if node.kind == .upcoming {
                    Line()
                        .stroke(AppColors.Adaptive.textMeta.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                } else {
                    Rectangle().fill(AppColors.Adaptive.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
    }

    private func labels(_ node: Node) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if node.kind == .current {
                Text("En cours")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Brand.onInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(AppColors.Brand.accent, in: Capsule())
            }
            Text(node.place)
                .font(.appCaption)
                .foregroundStyle(node.kind == .upcoming ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textPrimary)
            if !node.label.isEmpty {
                Text(node.label)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            if let detail = node.detail {
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(node.rejected ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
            }
        }
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilitySummary: String {
        guard let step = law.current else { return "Parcours du texte" }
        return "Étape actuelle : \(step.label), \(step.place)"
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

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
