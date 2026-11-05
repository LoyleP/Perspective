import SwiftUI

/// The glyph inside every round navigation button, the same as the system's back chevron: an SF
/// Symbol, medium weight. Icons are 17 pt; chevrons are drawn 1.26 times larger, because the system's back
/// chevron measures about 19 pt tall (a 21 pt symbol), which is the height every chevron should have.
/// Use it for toolbar and circular buttons so they all read as one set.
struct NavIcon: View {
    let systemName: String
    var size: CGFloat = 17

    init(_ systemName: String, size: CGFloat = 17) {
        self.systemName = systemName
        self.size = size
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: systemName.hasPrefix("chevron") ? size * 1.26 : size, weight: .medium))
            .accessibilityHidden(true)
    }
}
