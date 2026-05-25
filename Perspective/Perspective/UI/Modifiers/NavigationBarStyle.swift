import SwiftUI

struct PerspectiveNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()

                appearance.largeTitleTextAttributes = [
                    .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                    .foregroundColor: UIColor(AppColors.Adaptive.textPrimary)
                ]

                appearance.titleTextAttributes = [
                    .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: UIColor(AppColors.Adaptive.textPrimary)
                ]

                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
    }
}

extension View {
    func perspectiveNavigationBar() -> some View {
        modifier(PerspectiveNavigationBar())
    }
}
