import SwiftUI

struct SourceDetailView: View {

    let source: Source

    @State private var articles: [Article] = []
    @State private var isLoadingArticles = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection

                if source.ownerName != nil || source.ownerNotes != nil {
                    sectionHeader("Propriétaire")
                    ownerCard
                }

                sectionHeader("Liens")
                linksCard

                sectionHeader("Articles récents")
                articlesContent
                    .padding(.horizontal, AppSpacing.m)

                Spacer(minLength: AppSpacing.xxl)
            }
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .tint(AppColors.Adaptive.textPrimary)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.Adaptive.background, for: .navigationBar)
        .task { await loadArticles() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.m) {
            logoView

            Text(source.name)
                .font(.appLargeTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .multilineTextAlignment(.center)

            if let lean = source.lean {
                leanTag(lean)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.l)
    }

    private var logoView: some View {
        AsyncImage(url: source.logoURL.flatMap(URL.init)) { phase in
            if let img = phase.image {
                Color.clear
                    .overlay(img.resizable().scaledToFill())
                    .clipped()
            } else {
                fallbackLogo
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private var fallbackLogo: some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }

    private func leanTag(_ lean: PoliticalLean) -> some View {
        Text(lean.label)
            .font(.appFootnote)
            .foregroundStyle(lean.tagTextColor)
            .padding(.horizontal, AppSpacing.st)
            .padding(.vertical, AppSpacing.s)
            .background(lean.spectrumColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
    }

    // MARK: - Section header

    private func sectionHeader(_ label: String) -> some View {
        Text(label.uppercased())
            .font(.appCaption1)
            .foregroundStyle(AppColors.Adaptive.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - Owner card

    private var ownerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let owner = source.ownerName {
                Text(owner)
                    .font(.appTitle3)
                    .foregroundStyle(AppColors.Adaptive.textSecondary)
            }
            if let notes = source.ownerNotes {
                Text(notes)
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
        .padding(.horizontal, AppSpacing.m)
    }

    // MARK: - Links card

    private var linksCard: some View {
        VStack(spacing: 0) {
            if let siteURL = URL(string: source.url) {
                linkRow(
                    systemImage: "safari",
                    label: source.url,
                    url: siteURL
                )
            }
            if source.rssURL != source.url, let rssURL = URL(string: source.rssURL) {
                AppColors.Adaptive.divider.frame(height: 1)
                linkRow(
                    systemImage: "antenna.radiowaves.left.and.right",
                    label: source.rssURL,
                    url: rssURL
                )
            }
        }
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
        .padding(.horizontal, AppSpacing.m)
    }

    private func linkRow(systemImage: String, label: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
                    .frame(width: 18)
                Text(label)
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.appCaption1)
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
            }
            .padding(AppSpacing.m)
        }
        .accessibilityHint("Ouvre dans Safari")
    }

    // MARK: - Articles

    @ViewBuilder
    private var articlesContent: some View {
        if isLoadingArticles {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
        } else if articles.isEmpty {
            Text("Aucun article disponible.")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: AppSpacing.st) {
                ForEach(articles) { article in
                    articleCard(article)
                }
            }
            .padding(.bottom, AppSpacing.m)
        }
    }

    private func articleCard(_ article: Article) -> some View {
        Group {
            if let url = URL(string: article.url) {
                Link(destination: url) { articleCardContent(article) }
                    .buttonStyle(.plain)
            } else {
                articleCardContent(article)
            }
        }
    }

    private func articleCardContent(_ article: Article) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(article.title)
                    .font(.appTitle2)
                    .foregroundStyle(AppColors.Adaptive.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(article.publishedAt.relativeToNowFrench())
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            Image(systemName: "arrow.up.forward")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .padding(.top, 2)
        }
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }

    // MARK: - Data

    private func loadArticles() async {
        isLoadingArticles = true
        do {
            articles = try await SourceRepository.shared.fetchRecentArticles(
                sourceId: source.id, limit: 10
            )
        } catch {
            print("[SourceDetailView] loadArticles failed: \(error)")
        }
        isLoadingArticles = false
    }
}

#if DEBUG
#Preview("SourceDetailView") {
    NavigationStack {
        SourceDetailView(source: PreviewData.leFigaro)
    }
}
#endif
