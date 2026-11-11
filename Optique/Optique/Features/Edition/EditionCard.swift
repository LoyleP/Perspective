import SwiftUI

/// The entry to the Brief at the top of À la une: a dark card with the edition's name, its size and a play button.
struct EditionCard: View {
    let edition: Edition
    let onOpen: () -> Void

    @AppStorage("lastSeenEdition") private var lastSeen = ""

    private var isNew: Bool { lastSeen != edition.id.uuidString }

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .leading) {
                Color(hex: "0A0A0A")
                bloom
                HStack(alignment: .bottom, spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BRIEF · \(edition.dateLabel)")
                            .typeStyle(.label)
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                        Text(edition.slot.title)
                            .typeStyle(.headline)
                            .foregroundStyle(Color.white)
                        Text("\(edition.stories.count) sujets · \(edition.readingMinutes) min de lecture")
                            .typeStyle(.meta)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                    PlayGlyph()
                        .fill(Color.black)
                        .frame(width: 14, height: 16)
                        .offset(x: 1)
                        .frame(width: 48, height: 48)
                        .background(Color.white, in: Circle())
                        .accessibilityHidden(true)
                }
                .padding(AppSpacing.m)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 148)
            .overlay(alignment: .topTrailing) {
                if isNew {
                    Text("NOUVEAU")
                        .typeStyle(.label)
                        .tracking(1)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white, in: Capsule())
                        .padding(AppSpacing.m)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel("\(edition.slot.title), \(edition.stories.count) sujets. Regarder")
    }

    /// The spectrum colours, blurred into the corners: the same bloom as the launch screen and the paywall.
    private var bloom: some View {
        ZStack {
            RadialGradient(colors: [PoliticalLean.gauche.spectrumColor.opacity(0.5), .clear], center: .topLeading, startRadius: 0, endRadius: 190)
            RadialGradient(colors: [PoliticalLean.droite.spectrumColor.opacity(0.5), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 200)
            RadialGradient(colors: [PoliticalLean.centre.spectrumColor.opacity(0.3), .clear], center: UnitPoint(x: 0.45, y: 1.1), startRadius: 0, endRadius: 140)
        }
        .allowsHitTesting(false)
    }
}

/// A play triangle.
private struct PlayGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
