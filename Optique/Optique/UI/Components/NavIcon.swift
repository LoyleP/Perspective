import SwiftUI

/// The glyph inside every round navigation button: a Lucide icon at 20 pt, in the same box as the
/// system's back chevron. Use it for toolbar and circular buttons so they all read as one set.
struct NavIcon: View {
    let name: String
    var filled = false
    var size: CGFloat = 20

    init(_ name: String, filled: Bool = false, size: CGFloat = 20) {
        self.name = name
        self.filled = filled
        self.size = size
    }

    var body: some View {
        LucideIcon(name, filled: filled, size: size)
    }
}
