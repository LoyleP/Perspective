import SwiftUI

struct StoryThreadView: View {

    let story: Story

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                timelineSection
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.Adaptive.feedBackground, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(story.title)
                .font(.appLargeTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Text("\(story.articles.count) articles")
                Text("•").accessibilityHidden(true)
                Text(dateSpanLabel)
            }
            .font(.appFootnote)
            .foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        let groups = groupedByDay
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.day) { gi, group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayLabel(group.day).uppercased())
                        .font(.appCaption1)
                        .foregroundStyle(AppColors.Adaptive.textTertiary)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, gi == 0 ? 0 : AppSpacing.l)
                        .padding(.bottom, AppSpacing.s)

                    ForEach(Array(group.articles.enumerated()), id: \.element.id) { ai, article in
                        let isLast = gi == groups.count - 1 && ai == group.articles.count - 1
                        threadEntry(article: article, isLast: isLast)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }

    // MARK: - Thread entry

    private func threadEntry(article: Article, isLast: Bool) -> some View {
        let lean = article.source?.lean
        let dotColor = lean?.spectrumColor ?? AppColors.Adaptive.placeholder

        return HStack(alignment: .top, spacing: AppSpacing.s) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, AppSpacing.m)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.Adaptive.divider)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            entryCard(article: article, lean: lean)
                .padding(.bottom, AppSpacing.st)
        }
    }

    // MARK: - Entry card (matches AnalyzedArticleCard style)

    private func entryCard(article: Article, lean: PoliticalLean?) -> some View {
        let content = entryCardContent(article: article, lean: lean)
        return Group {
            if let url = URL(string: article.url) {
                Link(destination: url) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private func entryCardContent(article: Article, lean: PoliticalLean?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text(article.title)
                .font(.appTitle2)
                .foregroundStyle(AppColors.Adaptive.textSecondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: AppSpacing.s) {
                if let lean {
                    leanTag(lean)
                }
                if let source = article.source {
                    sourceRow(source)
                }
                Spacer()
                Text(timeLabel(article.publishedAt))
                    .font(.appCaption1)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                Image(systemName: "arrow.up.forward")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }

    private func leanTag(_ lean: PoliticalLean) -> some View {
        Text(lean.shortLabel)
            .font(.appFootnote)
            .foregroundStyle(lean.tagTextColor)
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xs)
            .background(lean.spectrumColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.s).stroke(AppColors.stroke, lineWidth: 1))
    }

    private func sourceRow(_ source: Source) -> some View {
        HStack(spacing: AppSpacing.xs) {
            avatarCircle(source)
            Text(source.name)
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .lineLimit(1)
        }
    }

    private func avatarCircle(_ source: Source) -> some View {
        Group {
            if let s = source.logoURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        Color.clear.overlay(img.resizable().scaledToFill()).clipped()
                    } else {
                        sourceInitial(source)
                    }
                }
            } else {
                sourceInitial(source)
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private func sourceInitial(_ source: Source) -> some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }

    // MARK: - Data grouping

    private struct DayGroup {
        let day: Date
        let articles: [Article]
    }

    private var groupedByDay: [DayGroup] {
        let calendar = Calendar.current
        var groups: [Date: [Article]] = [:]
        for article in story.articles.sorted(by: { $0.publishedAt < $1.publishedAt }) {
            let day = calendar.startOfDay(for: article.publishedAt)
            groups[day, default: []].append(article)
        }
        return groups.keys.sorted().map { DayGroup(day: $0, articles: groups[$0]!) }
    }

    // MARK: - Formatting

    private var dateSpanLabel: String {
        let sorted = story.articles.map(\.publishedAt).sorted()
        guard let first = sorted.first, let last = sorted.last, first != last else {
            return dayLabel(story.firstPublishedAt)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    private func dayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "EEEE d MMMM"
        return fmt.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("StoryThreadView") {
    NavigationStack {
        StoryThreadView(story: {
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
            let a1 = Article(
                id: UUID(), sourceID: PreviewData.leMonde.id,
                title: "La réforme des retraites présentée en Conseil des ministres",
                url: "https://lemonde.fr", summary: "Le gouvernement détaille les grandes lignes du projet.",
                imageURL: nil, publishedAt: yesterday.addingTimeInterval(32400),
                fetchedAt: .now, storyID: PreviewData.storyID,
                rawKeywords: [], clickCount: 0, isPrimary: true, createdAt: .now, updatedAt: .now,
                source: PreviewData.leMonde
            )
            let a2 = Article(
                id: UUID(), sourceID: PreviewData.leFigaro.id,
                title: "Retraites : le gouvernement défend sa réforme face à l'opposition",
                url: "https://lefigaro.fr", summary: nil,
                imageURL: nil, publishedAt: yesterday.addingTimeInterval(50400),
                fetchedAt: .now, storyID: PreviewData.storyID,
                rawKeywords: [], clickCount: 0, isPrimary: true, createdAt: .now, updatedAt: .now,
                source: PreviewData.leFigaro
            )
            let a3 = Article(
                id: UUID(), sourceID: PreviewData.liberation.id,
                title: "Les syndicats appellent à une grève nationale contre les retraites",
                url: "https://liberation.fr", summary: nil,
                imageURL: nil, publishedAt: Date().addingTimeInterval(-7200),
                fetchedAt: .now, storyID: PreviewData.storyID,
                rawKeywords: [], clickCount: 0, isPrimary: true, createdAt: .now, updatedAt: .now,
                source: PreviewData.liberation
            )
            let a4 = Article(
                id: UUID(), sourceID: PreviewData.leMonde.id,
                title: "Forte mobilisation dans les rues, le gouvernement reste ferme",
                url: "https://lemonde.fr/2", summary: nil,
                imageURL: nil, publishedAt: Date().addingTimeInterval(-1800),
                fetchedAt: .now, storyID: PreviewData.storyID,
                rawKeywords: [], clickCount: 0, isPrimary: true, createdAt: .now, updatedAt: .now,
                source: PreviewData.leMonde
            )
            return Story(
                id: PreviewData.storyID,
                title: PreviewData.story.title,
                summary: PreviewData.story.summary,
                firstPublishedAt: yesterday,
                lastUpdatedAt: .now,
                topicTags: PreviewData.story.topicTags,
                isFeatured: true,
                createdAt: .now, updatedAt: .now,
                articles: [a1, a2, a3, a4],
                coverage: PreviewData.story.coverage,
                spectrumSummary: nil,
                summaryGeneratedAt: nil
            )
        }())
    }
}
#endif
