import SwiftUI

/// Topic tabs have their own look, distinct from "À la une": a masthead, then a body chosen per topic
/// (spectrum cards for politics, a ledger for the economy, photo grids for sport and culture, a mixed
/// lead + list for the others). `link` wraps a cell in the page's navigation, zoom and context menu.
typealias TopicLink = (Story, AnyView) -> AnyView

// MARK: - Masthead

struct TopicMasthead: View {
    let topic: StoryTopic
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.st) {
                LucideIcon(topic.lucideIcon, size: 22)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: topic.tileColors.top), Color(hex: topic.tileColors.bottom)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.rawValue)
                        .typeStyle(.display)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(count == 1 ? "1 sujet couvert par plusieurs médias" : "\(count) sujets couverts par plusieurs médias")
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
        }
    }
}

// MARK: - Body

struct TopicBody: View {
    let topic: StoryTopic
    let stories: [Story]
    let link: TopicLink

    var body: some View {
        switch topic {
        case .societe:
            MixedLayout(stories: stories, link: link)
        case .sport, .culture:
            GridLayout(stories: stories, link: link)
        default:
            FrontLayout(stories: stories, link: link)
        }
    }
}

// MARK: Every other topic: the same cards as "À la une"

private struct FrontLayout: View {
    let stories: [Story]
    let link: TopicLink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                if index == 0 {
                    link(story, AnyView(StoryHeroCard(story: story)))
                } else {
                    link(story, AnyView(StoryRow(story: story)))
                }
            }
        }
    }
}

private struct LedgerRow: View {
    let story: Story

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .typeStyle(.rowTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                StoryMetaLine(story: story)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear
                .frame(width: 96, height: 96)
                .overlay { RemoteImage(url: story.leadImageURL, maxPixel: 300, topic: story.placeholderTopic, alternates: story.imageAlternates) }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
                .accessibilityHidden(true)
        }
        .padding(.vertical, AppSpacing.st)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: Sport and culture: photo-first grid

private struct GridLayout: View {
    let stories: [Story]
    let link: TopicLink

    private let columns = [GridItem(.flexible(), spacing: AppSpacing.st), GridItem(.flexible(), spacing: AppSpacing.st)]

    var body: some View {
        VStack(spacing: AppSpacing.st) {
            if let lead = stories.first {
                link(lead, AnyView(StoryHeroCard(story: lead)))
            }
            LazyVGrid(columns: columns, spacing: AppSpacing.st) {
                ForEach(stories.dropFirst()) { story in
                    link(story, AnyView(GridCard(story: story)))
                }
            }
        }
    }
}

private struct GridCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Color.clear
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .overlay { RemoteImage(url: story.leadImageURL, maxPixel: 600, topic: story.placeholderTopic, alternates: story.imageAlternates) }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
                .accessibilityHidden(true)
            Text(story.title)
                .typeStyle(.rowTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            StoryMetaLine(story: story)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: Other topics: lead over the photo, a pair, then headlines

private struct MixedLayout: View {
    let stories: [Story]
    let link: TopicLink

    private let columns = [GridItem(.flexible(), spacing: AppSpacing.st), GridItem(.flexible(), spacing: AppSpacing.st)]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            if let lead = stories.first {
                link(lead, AnyView(StoryHeroCard(story: lead)))
            }
            let pair = Array(stories.dropFirst().prefix(2))
            if !pair.isEmpty {
                LazyVGrid(columns: columns, spacing: AppSpacing.st) {
                    ForEach(pair) { story in
                        link(story, AnyView(GridCard(story: story)))
                    }
                }
                .padding(.bottom, AppSpacing.s)
            }
            ForEach(Array(stories.dropFirst(3))) { story in
                Divider().overlay(AppColors.stroke)
                link(story, AnyView(LedgerRow(story: story)))
            }
        }
    }
}
