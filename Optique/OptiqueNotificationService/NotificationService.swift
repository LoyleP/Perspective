import UserNotifications
import UIKit

/// Runs for every push carrying `mutable-content`. The title and the description are already in the alert;
/// this adds the coverage bar as an image attachment, drawn from the `lean_counts` of the payload
/// (primary articles per lean 1 to 7), so the bar is on the lock screen without the app being opened.
final class NotificationService: UNNotificationServiceExtension {

    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        handler = contentHandler
        let mutable = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        content = mutable

        if let counts = (request.content.userInfo["lean_counts"] as? [NSNumber])?.map(\.intValue),
           let url = CoverageImage.write(counts: counts, id: request.identifier),
           let attachment = try? UNNotificationAttachment(
               identifier: "coverage", url: url,
               // Whole image as the collapsed thumbnail instead of a centre crop.
               options: [UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                            CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation]
           ) {
            mutable.attachments = [attachment]
        }
        contentHandler(mutable)
    }

    /// Out of time: deliver what we have, without the image.
    override func serviceExtensionTimeWillExpire() {
        if let handler, let content { handler(content) }
    }
}

/// The app's CoverageBar for a notification: five positions, far left to far right, in the spectrum colours,
/// each segment sized by its share with its percentage, and the colour key underneath.
enum CoverageImage {

    private struct Position { let label: String; let color: UIColor; let leans: [Int] }

    private static let positions: [Position] = [
        .init(label: "E. gauche", color: UIColor(hex: 0xA81F26), leans: [1]),
        .init(label: "Gauche", color: UIColor(hex: 0xD9383F), leans: [2, 3]),
        .init(label: "Centre", color: UIColor(hex: 0x86868C), leans: [4]),
        .init(label: "Droite", color: UIColor(hex: 0x3A6FE0), leans: [5, 6]),
        .init(label: "E. droite", color: UIColor(hex: 0x2442B8), leans: [7]),
    ]

    static func write(counts: [Int], id: String) -> URL? {
        guard let data = render(counts: counts)?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coverage-\(id).png")
        do { try data.write(to: url); return url } catch { return nil }
    }

    static func render(counts: [Int]) -> UIImage? {
        guard counts.count == 7 else { return nil }
        let totals = positions.map { p in p.leans.reduce(0) { $0 + counts[$1 - 1] } }
        let total = totals.reduce(0, +)
        guard total > 0 else { return nil }

        let size = CGSize(width: 720, height: 360)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(hex: 0xF4F4F5).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let margin: CGFloat = 40, gap: CGFloat = 8, barHeight: CGFloat = 56, barY: CGFloat = 96
            let shown = totals.enumerated().filter { $0.element > 0 }
            let usable = size.width - margin * 2 - gap * CGFloat(max(shown.count - 1, 0))

            var x = margin
            for (index, count) in shown {
                let width = usable * CGFloat(count) / CGFloat(total)
                let rect = CGRect(x: x, y: barY, width: width, height: barHeight)
                positions[index].color.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: barHeight / 2).fill()

                let percent = "\(Int((Double(count) / Double(total) * 100).rounded())) %"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .semibold),
                    .foregroundColor: UIColor.white,
                ]
                let textSize = percent.size(withAttributes: attrs)
                if width >= textSize.width + 28 {
                    percent.draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: attrs)
                }
                x += width + gap
            }

            let title = "Couverture par position · \(total) \(total == 1 ? "source" : "sources")"
            title.draw(at: CGPoint(x: margin, y: 36), withAttributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor(hex: 0x52525B),
            ])

            // Colour key.
            let keyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor(hex: 0x52525B),
            ]
            let widths = positions.map { $0.label.size(withAttributes: keyAttrs).width + 20 + 8 }
            let keyGap: CGFloat = 20
            var kx = margin
            let ky: CGFloat = 220
            for (i, position) in positions.enumerated() {
                position.color.setFill()
                UIBezierPath(ovalIn: CGRect(x: kx, y: ky + 7, width: 16, height: 16)).fill()
                position.label.draw(at: CGPoint(x: kx + 24, y: ky), withAttributes: keyAttrs)
                kx += widths[i] + keyGap
            }
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
