import SwiftUI

/// The one-time callout under the first hero card's coverage bar: a dark rounded bubble with a small tail
/// pointing up at the bar (dark in both modes).
struct CoverageTip: View {
    private static let fill = Color(hex: "262628")
    private static let edge = Color.white.opacity(0.14)
    private static let tail = CGSize(width: 18, height: 9)

    var body: some View {
        VStack(spacing: 0) {
            Text("Voyez comment l'info est couverte")
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .padding(.top, Self.tail.height)
        .background {
            BubbleShape(tail: Self.tail, radius: 18)
                .fill(Self.fill)
                .overlay { BubbleShape(tail: Self.tail, radius: 18).stroke(Self.edge, lineWidth: 1) }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A rounded rectangle with a triangular tail on top, centred.
private struct BubbleShape: Shape {
    let tail: CGSize
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY + tail.height, width: rect.width, height: rect.height - tail.height)
        var path = Path(roundedRect: body, cornerRadius: radius, style: .continuous)
        var triangle = Path()
        let mid = rect.midX
        triangle.move(to: CGPoint(x: mid - tail.width / 2, y: body.minY + 0.5))
        triangle.addQuadCurve(to: CGPoint(x: mid, y: rect.minY), control: CGPoint(x: mid - 3, y: rect.minY + 1))
        triangle.addQuadCurve(to: CGPoint(x: mid + tail.width / 2, y: body.minY + 0.5), control: CGPoint(x: mid + 3, y: rect.minY + 1))
        triangle.closeSubpath()
        path = path.union(triangle)
        return path
    }
}
