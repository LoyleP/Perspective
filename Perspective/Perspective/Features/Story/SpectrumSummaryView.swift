import SwiftUI

struct SpectrumSummaryView: View {

    let spectrumSummary: SpectrumSummary?

    private static let displayOrder: [PoliticalLean] = [
        .extremeGauche, .gauche, .centreGauche, .centre, .centreDroite, .droite, .extremeDroite
    ]

    var body: some View {
        if let summary = spectrumSummary {
            let bullets = collectBullets(from: summary)
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: AppSpacing.s) {
                        Text("•")
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textTertiary)
                            .accessibilityHidden(true)
                        Text(bullet)
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.m)
        } else {
            skeletonView
        }
    }

    private func collectBullets(from summary: SpectrumSummary) -> [String] {
        let all = Self.displayOrder
            .compactMap { lean in summary.perspectives.first(where: { $0.lean == lean }) }
            .flatMap { perspective in
                perspective.summary
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { $0.hasPrefix("•") ? String($0.dropFirst()).trimmingCharacters(in: .whitespaces) : $0 }
            }
        return Array(all.prefix(5))
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(spacing: AppSpacing.st) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonBlock()
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
    }
}

#if DEBUG
#Preview("SpectrumSummaryView – with data") {
    SpectrumSummaryView(spectrumSummary: PreviewData.spectrumSummary)
        .padding()
        .background(AppColors.Adaptive.background)
}

#Preview("SpectrumSummaryView – skeleton") {
    SpectrumSummaryView(spectrumSummary: nil)
        .padding()
        .background(AppColors.Adaptive.background)
}
#endif

// MARK: - SkeletonBlock

private struct SkeletonBlock: View {
    @State private var opacity: Double = 0.4

    var body: some View {
        RoundedRectangle(cornerRadius: AppRadius.st)
            .fill(AppColors.Adaptive.placeholder)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .opacity(opacity)
            .accessibilityLabel("Chargement en cours")
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.9
                }
            }
    }
}
