import SwiftUI

/// Heroicons (heroicons.com, MIT) rendered from the asset catalog (`Assets.xcassets/Icons`).
/// Outline icons are named `hero-<name>`, solid ones `hero-<name>-solid`. The icon takes the
/// current foreground style and scales with Dynamic Type.
struct HeroIcon: View {
    let name: String
    var solid = false
    @ScaledMetric private var scaledSize: CGFloat

    init(_ name: String, solid: Bool = false, size: CGFloat = 20) {
        self.name = name
        self.solid = solid
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(solid ? "hero-\(name)-solid" : "hero-\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: scaledSize, height: scaledSize)
            .accessibilityHidden(true)
    }
}

extension Label where Title == Text, Icon == HeroIcon {
    /// `Label` with a Heroicon in place of an SF Symbol.
    init(_ title: String, hero name: String, solid: Bool = false, size: CGFloat = 20) {
        self.init {
            Text(title)
        } icon: {
            HeroIcon(name, solid: solid, size: size)
        }
    }
}

extension ContentUnavailableView where Label == SwiftUI.Label<Text, HeroIcon>, Description == Text, Actions == EmptyView {
    /// `ContentUnavailableView` with a Heroicon in place of an SF Symbol.
    init(_ title: String, hero name: String, description: Text) {
        self.init {
            SwiftUI.Label(title, hero: name, size: 44)
        } description: {
            description
        }
    }
}
