import SwiftUI

struct SourceCard: View {

    let source: Source

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            logoView

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(source.name)
                    .font(.appTitle2)
                    .foregroundStyle(AppColors.Adaptive.textSecondary)
                    .lineLimit(1)

                if let owner = source.ownerName {
                    Text(owner)
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let lean = source.lean {
                leanTag(lean)
            }
        }
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }

    // MARK: - Logo

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
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private var fallbackLogo: some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }

    // MARK: - Lean tag

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
}

#if DEBUG
#Preview("SourceCard") {
    VStack(spacing: AppSpacing.st) {
        SourceCard(source: PreviewData.leMonde)
        SourceCard(source: PreviewData.leFigaro)
        SourceCard(source: PreviewData.liberation)
    }
    .padding()
    .background(AppColors.Adaptive.feedBackground)
}
#endif
