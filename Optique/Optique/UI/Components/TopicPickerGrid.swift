import SwiftUI

/// Two-column grid of topic toggles, used in onboarding and settings.
struct TopicPickerGrid: View {
    @Binding var selection: Set<StoryTopic>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: AppSpacing.st),
                count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
            ),
            spacing: AppSpacing.st
        ) {
            ForEach(StoryTopic.selectable) { topic in
                let isOn = selection.contains(topic)
                Button {
                    if isOn { selection.remove(topic) } else { selection.insert(topic) }
                } label: {
                    HStack(spacing: AppSpacing.s) {
                        Image(systemName: topic.systemImage)
                            .font(.appHeadline)
                            .foregroundStyle(isOn ? AppColors.Brand.accent : AppColors.Adaptive.textTertiary)
                            .frame(width: 24)
                        Text(topic.rawValue)
                            .font(.appHeadline)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOn ? AppColors.Brand.accent : AppColors.Adaptive.textMeta)
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .frame(minHeight: 56)
                    .background(
                        isOn ? AppColors.Brand.accentSoft : AppColors.Adaptive.cardSurface,
                        in: RoundedRectangle(cornerRadius: AppRadius.l)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.l)
                            .stroke(isOn ? AppColors.Brand.accent : AppColors.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(CardPressStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Settings screen to change the preferred topics.
struct TopicPreferencesView: View {
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Vos thèmes apparaissent en premier dans Explorer.")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                TopicPickerGrid(selection: Binding(
                    get: { StoryTopic.preferred(from: preferredTopicsRaw) },
                    set: { preferredTopicsRaw = StoryTopic.storageValue($0) }
                ))
            }
            .padding(AppSpacing.m)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationTitle("Thèmes préférés")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Topic picker") {
    @Previewable @State var selection: Set<StoryTopic> = [.politique, .sport]
    return ScrollView { TopicPickerGrid(selection: $selection).padding() }
        .background(AppColors.Adaptive.background)
}
#endif
