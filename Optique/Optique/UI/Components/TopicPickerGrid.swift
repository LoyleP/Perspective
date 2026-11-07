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
                        LucideIcon(topic.lucideIcon, size: 22)
                            .typeStyle(.ui)
                            .foregroundStyle(isOn ? AppColors.Brand.accent : AppColors.Adaptive.textTertiary)
                            .frame(width: 24)
                        Text(topic.rawValue)
                            .typeStyle(.ui)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Group {
                            if isOn {
                                ZStack {
                                    Circle().fill(AppColors.Brand.accent).frame(width: 22, height: 22)
                                    LucideIcon("check", bold: true, size: 13).foregroundStyle(.white)
                                }
                            } else {
                                Circle().stroke(AppColors.Adaptive.textMeta, lineWidth: 1.5).frame(width: 20, height: 20)
                            }
                        }
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
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Settings screen to change the preferred topics.
struct TopicPreferencesView: View {
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Vos thèmes apparaissent en premier dans Explorer.")
                    .typeStyle(.body)
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
        .appBackButton()
    }
}

#if DEBUG
#Preview("Topic picker") {
    @Previewable @State var selection: Set<StoryTopic> = [.politique, .sport]
    return ScrollView { TopicPickerGrid(selection: $selection).padding() }
        .background(AppColors.Adaptive.background)
}
#endif
