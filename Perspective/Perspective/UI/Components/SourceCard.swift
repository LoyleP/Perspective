import SwiftUI

struct SourceCard: View {

    let source: Source

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            SourceAvatarView(source: source, size: 44)

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
                LeanTagView(lean: lean, style: .rounded)
            }
        }
        .padding(AppSpacing.m)
        .cardSurface()
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
