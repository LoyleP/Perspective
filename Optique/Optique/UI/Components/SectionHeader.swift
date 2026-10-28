import SwiftUI

/// Section title with an optional subtitle and trailing action.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appTitle2)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Brand.accent)
            }
        }
    }
}
