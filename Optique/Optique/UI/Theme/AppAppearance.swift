import SwiftUI
import UIKit

/// Geist and ink colors for UIKit-backed controls (navigation bar, tab bar, segmented control,
/// search field). System alerts, context menus and the share sheet stay in the system font.
enum AppAppearance {

    @MainActor
    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.largeTitleTextAttributes = [
            .font: UIFont.geist(34, .medium, relativeTo: .largeTitle),
            .foregroundColor: UIColor.label
        ]
        nav.titleTextAttributes = [
            .font: UIFont.geist(17, .medium, relativeTo: .headline),
            .foregroundColor: UIColor.label
        ]
        let navButton = UIBarButtonItemAppearance()
        navButton.normal.titleTextAttributes = [.font: UIFont.geist(17, .regular, relativeTo: .body)]
        nav.buttonAppearance = navButton
        nav.doneButtonAppearance = navButton
        nav.backButtonAppearance = navButton
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tabTitle: [NSAttributedString.Key: Any] = [.font: UIFont.geist(10, .medium, relativeTo: .caption2)]
        UITabBarItem.appearance().setTitleTextAttributes(tabTitle, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(tabTitle, for: .selected)

        let segmentTitle: [NSAttributedString.Key: Any] = [.font: UIFont.geist(13, .medium, relativeTo: .footnote)]
        UISegmentedControl.appearance().setTitleTextAttributes(segmentTitle, for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes(segmentTitle, for: .selected)

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [
            .font: UIFont.geist(17, .regular, relativeTo: .body)
        ]
    }
}
