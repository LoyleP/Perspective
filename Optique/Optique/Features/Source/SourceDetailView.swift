import SwiftUI
import OSLog

/// A source's position on the spectrum, ownership and latest articles.
struct SourceDetailView: View {

    let source: Source

    @State private var articles: [Article] = []
    @State private var isLoadingArticles = false
    @State private var selectedArticle: Article?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header

                if let lean = source.lean {
                    positionCard(lean)
                }

                if source.ownerName != nil || source.ownerNotes != nil || source.ownerType != nil {
                    ownerCard
                }

                articlesSection
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = URL(string: source.url) {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("Ouvrir le site")
                }
            }
        }
        .tint(AppColors.Adaptive.textPrimary)
        .sheet(item: $selectedArticle) { article in
            ArticleBrowserView(articles: articles, initialArticle: article)
        }
        .task { await loadArticles() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            SourceAvatarView(source: source, size: 72)
            Text(source.name)
                .font(.appDisplay)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let host = URL(string: source.url)?.host() {
                Text(host.replacingOccurrences(of: "www.", with: ""))
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .padding(.top, AppSpacing.s)
    }

    // MARK: - Position

    private func positionCard(_ lean: PoliticalLean) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("Positionnement")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Spacer()
                LeanTagView(lean: lean)
            }
            HStack(spacing: 4) {
                ForEach(PoliticalLean.allCases) { position in
                    let isSource = position == lean
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(position.spectrumColor.opacity(isSource ? 1 : 0.2))
                            .frame(height: isSource ? 10 : 6)
                        Text(position.code)
                            .font(.appCaption2)
                            .foregroundStyle(isSource ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 30, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position : \(lean.label)")
        }
        .padding(AppSpacing.m)
        .cardSurface()
    }

    // MARK: - Owner

    private var ownerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Text("Propriétaire")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Spacer()
                if let type = source.ownerType {
                    HStack(spacing: 6) {
                        Circle().fill(type.color).frame(width: 8, height: 8)
                        Text(type.displayName)
                    }
                    .font(.appCaption1)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.Adaptive.surfaceElevated, in: Capsule())
                }
            }
            if let owner = source.ownerName {
                Text(owner)
                    .font(.appTitle3)
                    .foregroundStyle(AppColors.Adaptive.textSecondary)
            }
            if let notes = source.ownerNotes {
                Text(notes)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .cardSurface()
    }

    // MARK: - Articles

    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Articles récents")
                .padding(.bottom, AppSpacing.xs)
            if isLoadingArticles && articles.isEmpty {
                SkeletonLines(count: 5, lineHeight: 14)
                    .padding(.top, AppSpacing.s)
            } else if articles.isEmpty {
                Text("Aucun article récent.")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .padding(.vertical, AppSpacing.m)
            } else {
                ForEach(articles) { article in
                    Button {
                        selectedArticle = article
                    } label: {
                        HStack(alignment: .top, spacing: AppSpacing.m) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.publishedAt.relativeToNowFrench())
                                    .overlineStyle()
                                Text(article.title)
                                    .font(.appHeadline)
                                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            if let url = article.imageURL.flatMap(URL.init) {
                                Color.clear
                                    .frame(width: 64, height: 64)
                                    .overlay { RemoteImage(url: url) }
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, AppSpacing.st)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CardPressStyle())
                    Divider().overlay(AppColors.Adaptive.divider)
                }
            }
        }
    }

    // MARK: - Data

    private func loadArticles() async {
        isLoadingArticles = true
        do {
            articles = try await SourceRepository.shared.fetchRecentArticles(sourceId: source.id, limit: 15)
        } catch {
            Log.repository.error("loadArticles failed: \(error)")
        }
        isLoadingArticles = false
    }
}

#if DEBUG
#Preview("SourceDetailView") {
    NavigationStack {
        SourceDetailView(source: Fixtures.sources[4])
    }
}
#endif
