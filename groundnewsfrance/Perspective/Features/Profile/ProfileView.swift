import SwiftUI

struct ProfileView: View {

    @State private var showSettings = false

    var body: some View {
        content
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .sources:
                    SourcesView()
                case .saved:
                    SavedView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .onAppear {
                configureNavigationBarAppearance()
            }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                profileSection
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    private var profileSection: some View {
        VStack(spacing: AppSpacing.st) {
            NavigationLink(value: ProfileDestination.saved) {
                menuRow(title: "Enregistrés", icon: "bookmark", iconFilled: true)
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileDestination.sources) {
                menuRow(title: "Sources", icon: "building.columns", iconFilled: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func menuRow(title: String, icon: String, iconFilled: Bool) -> some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: iconFilled ? icon + ".fill" : icon)
                .font(.appTitle2)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .frame(width: 32)

            Text(title)
                .font(.appHeadline)
                .foregroundStyle(AppColors.Adaptive.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textSecondary)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
    }

    private func configureNavigationBarAppearance() {
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

enum ProfileDestination: Hashable {
    case sources
    case saved
}
