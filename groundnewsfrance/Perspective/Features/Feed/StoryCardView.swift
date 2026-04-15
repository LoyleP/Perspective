import SwiftUI

enum StoryCardVariant {
    case big
    case small
    case extended
}

struct StoryCardView: View {

    let story: Story
    let variant: StoryCardVariant

    init(story: Story, variant: StoryCardVariant = .extended) {
        self.story = story
        self.variant = variant
    }

    var body: some View {
        switch variant {
        case .big:
            bigVariant
        case .small:
            smallVariant
        case .extended:
            extendedVariant
        }
    }

    // MARK: - Big Variant

    private var bigVariant: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area
            Color.clear
                .overlay {
                    if let url = firstImageURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AppColors.Adaptive.placeholder
                            }
                        }
                    } else {
                        AppColors.Adaptive.placeholder
                    }
                }
                .overlay { Color.black.opacity(0.3) }
                .clipped()
                .frame(maxWidth: .infinity)
                .frame(height: 250)

            // Context section
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    // Coverage tags
                    coverageTags

                    // Title
                    Text(story.title)
                        .font(.appTitle1)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.m)
            }

            // Footer
            footerSection
        }
        .frame(maxWidth: .infinity)
        .frame(height: 435)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
    }

    // MARK: - Small Variant

    private var smallVariant: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                VStack(alignment: .leading, spacing: 0) {
                    // Title only (no tags)
                    Text(story.title)
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.m)
            }
            .padding(.top, AppSpacing.m)

            // Footer
            footerSection
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            AppColors.Adaptive.divider
                .frame(height: 1)
        }
    }

    // MARK: - Extended Variant

    private var extendedVariant: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    // Coverage tags
                    coverageTags

                    // Title + Image row
                    HStack(alignment: .top, spacing: 10) {
                        Text(story.title)
                            .font(.appTitle2)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let url = firstImageURL {
                            Color.clear
                                .overlay {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            AppColors.Adaptive.placeholder
                                        }
                                    }
                                }
                                .clipped()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.m)
            }
            .padding(.top, AppSpacing.m)

            // Footer
            footerSection
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            AppColors.Adaptive.divider
                .frame(height: 1)
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var coverageTags: some View {
        if let coverage = story.coverage {
            CoverageTagsView(coverage: coverage)
        }
    }

    private var footerSection: some View {
        HStack(spacing: 0) {
            Text("\(story.articles.count) articles analysés")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .padding(.leading, AppSpacing.m)
                .padding(.vertical, AppSpacing.st)
        }
    }

    private var firstImageURL: URL? {
        story.articles.compactMap { $0.imageURL.flatMap(URL.init) }.first
    }
}

#if DEBUG
#Preview("Big Variant") {
    StoryCardView(story: PreviewData.story, variant: .big)
        .padding()
        .background(AppColors.Adaptive.feedBackground)
}

#Preview("Extended Variant") {
    StoryCardView(story: PreviewData.story, variant: .extended)
        .padding()
        .background(AppColors.Adaptive.feedBackground)
}

#Preview("Small Variant") {
    StoryCardView(story: PreviewData.story, variant: .small)
        .padding()
        .background(AppColors.Adaptive.feedBackground)
}
#endif
